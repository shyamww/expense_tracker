import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/reporting_category_names.dart';
import '../core/money.dart';
import '../models/expense.dart';
import '../models/income_entry.dart';
import '../screens/day_detail_screen.dart';

/// First month users can open (page 0).
DateTime _calendarEpoch() => DateTime(2020, 1);

int _pageIndexForMonth(DateTime m) {
  final e = _calendarEpoch();
  return (m.year - e.year) * 12 + (m.month - e.month);
}

DateTime _monthFromPageIndex(int page) => DateTime(2020, 1 + page);

int _maxPageIndex() {
  final n = DateTime.now();
  return _pageIndexForMonth(DateTime(n.year, n.month));
}

class CalendarView extends StatefulWidget {
  final DateTime selectedMonth;
  final List<Expense> expenses;
  final List<IncomeEntry> incomeHistory;
  final ValueChanged<DateTime> onMonthSelected;

  const CalendarView({
    super.key,
    required this.selectedMonth,
    required this.expenses,
    required this.incomeHistory,
    required this.onMonthSelected,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  String? _selectedDateStr;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initial =
        _pageIndexForMonth(widget.selectedMonth).clamp(0, _maxPageIndex());
    _pageController = PageController(initialPage: initial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth.year != widget.selectedMonth.year ||
        oldWidget.selectedMonth.month != widget.selectedMonth.month) {
      _selectedDateStr = null;
      final target =
          _pageIndexForMonth(widget.selectedMonth).clamp(0, _maxPageIndex());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final current =
            _pageController.page?.round() ?? _pageController.initialPage;
        if (current != target) {
          _pageController.animateToPage(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxPage = _maxPageIndex();
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
          child: Row(
            children:
                ['S', 'M', 'T', 'W', 'T', 'F', 'S'].asMap().entries.map((e) {
              final i = e.key;
              final d = e.value;
              final weekend = i == 0 || i == 6;
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: weekend
                          ? Colors.red.shade400
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Divider(height: 1, thickness: 1, color: theme.dividerColor),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: maxPage + 1,
            onPageChanged: (page) {
              setState(() => _selectedDateStr = null);
              widget.onMonthSelected(_monthFromPageIndex(page));
            },
            itemBuilder: (context, page) {
              final month = _monthFromPageIndex(page);
              return RepaintBoundary(
                child: _buildMonthGrid(context, month),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(BuildContext context, DateTime month) {
    final monthPrefix = DateFormat('yyyy-MM').format(month);
    final dailyTotals = _computeDailyTotals(monthPrefix);
    final datesWithActivity = <String>{};
    for (final e in widget.expenses) {
      if (e.date.startsWith(monthPrefix)) datesWithActivity.add(e.date);
    }
    for (final inc in widget.incomeHistory) {
      final dk = _incomeEntryDateKey(inc);
      if (dk.startsWith(monthPrefix)) datesWithActivity.add(dk);
    }

    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final totalCells = startWeekday + daysInMonth;
    final rowCount = ((totalCells) / 7).ceil();

    // Cap row height so day cells stay compact; extra space sits below the grid (same summary on all tabs).
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxRow = 75.0;
        const padBottom = 4.0;
        final innerH =
            (constraints.maxHeight - padBottom).clamp(0.0, double.infinity);
        final perRow = rowCount > 0 ? innerH / rowCount : 0.0;
        final rowH = perRow > maxRow ? maxRow : perRow;
        final slack = (innerH - rowH * rowCount).clamp(0.0, double.infinity);

        return Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, padBottom + slack),
          child: Column(
            children: [
              for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
                SizedBox(
                  height: rowH,
                  child: _buildWeekRow(
                    context,
                    rowIndex,
                    startWeekday,
                    daysInMonth,
                    dailyTotals,
                    month,
                    datesWithActivity,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Map<String, ({double spent, double received})> _computeDailyTotals(
      String monthPrefix) {
    final Map<String, ({int spent, int received})> raw = {};
    for (final e in widget.expenses) {
      if (!e.date.startsWith(monthPrefix)) continue;
      final current = raw[e.date] ?? (spent: 0, received: 0);
      if (ReportingCategoryNames.countsAsExternalReceived(e.category)) {
        raw[e.date] =
            (spent: current.spent, received: current.received + e.amount);
      } else if (ReportingCategoryNames.countsAsSpendingInReports(e.category)) {
        raw[e.date] =
            (spent: current.spent + e.amount, received: current.received);
      }
    }
    for (final inc in widget.incomeHistory) {
      final dk = _incomeEntryDateKey(inc);
      if (!dk.startsWith(monthPrefix)) continue;
      final current = raw[dk] ?? (spent: 0, received: 0);
      raw[dk] = (spent: current.spent, received: current.received + inc.amount);
    }
    return {
      for (final e in raw.entries)
        e.key: (
          spent: rupeesFromPaisa(e.value.spent),
          received: rupeesFromPaisa(e.value.received),
        ),
    };
  }

  String _incomeEntryDateKey(IncomeEntry e) {
    final dt = DateTime.tryParse(e.createdAt);
    if (dt != null) return DateFormat('yyyy-MM-dd').format(dt);
    return '${e.month}-01';
  }

  Widget _buildWeekRow(
    BuildContext context,
    int rowIndex,
    int startWeekday,
    int daysInMonth,
    Map<String, ({double spent, double received})> dailyTotals,
    DateTime month,
    Set<String> datesWithActivity,
  ) {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final scheme = Theme.of(context).colorScheme;
    final selectedFill = scheme.primaryContainer.withValues(alpha: 0.65);
    final selectedBorder = scheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 40.0;
        final dayFont = (h * 0.30).clamp(10.0, 13.0);
        final amtFont = (h * 0.17).clamp(6.5, 8.0);
        const cellMargin = 1.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(7, (colIndex) {
            final cellIndex = rowIndex * 7 + colIndex;
            final dayNum = cellIndex - startWeekday + 1;

            if (dayNum < 1 || dayNum > daysInMonth) {
              return Expanded(child: Container());
            }

            final dateStr = DateFormat('yyyy-MM-dd').format(
              DateTime(month.year, month.month, dayNum),
            );
            final totals = dailyTotals[dateStr];
            final isToday = dateStr == todayStr;
            final isWeekend = colIndex == 0 || colIndex == 6;
            final isSelected = _selectedDateStr == dateStr;

            Color? cellBg;
            Color borderColor;
            double borderWidth;
            if (isSelected) {
              cellBg = selectedFill;
              borderColor = selectedBorder;
              borderWidth = 2;
            } else if (isToday) {
              cellBg =
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
              borderColor = Theme.of(context).colorScheme.primary;
              borderWidth = 1.5;
            } else {
              cellBg = Theme.of(context).colorScheme.surface;
              borderColor = Theme.of(context).dividerColor;
              borderWidth = 0.5;
            }

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedDateStr = dateStr);
                    final hasEntry = datesWithActivity.contains(dateStr);
                    if (!hasEntry) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No entry for this day'),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.fromLTRB(16, 0, 16, 88),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DayDetailScreen(date: dateStr),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.all(cellMargin),
                    padding: EdgeInsets.symmetric(
                      vertical: h >= 34 ? 2 : 1,
                      horizontal: 0,
                    ),
                    decoration: BoxDecoration(
                      color: cellBg,
                      border:
                          Border.all(color: borderColor, width: borderWidth),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isSelected || isToday
                          ? [
                              BoxShadow(
                                color: (isSelected
                                        ? selectedBorder
                                        : Theme.of(context).colorScheme.primary)
                                    .withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: dayFont,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? selectedBorder
                                  : isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : isWeekend
                                          ? Colors.red.shade400
                                          : scheme.onSurface,
                            ),
                          ),
                          if (totals != null &&
                              (totals.spent > 0 || totals.received > 0))
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (totals.spent > 0)
                                      Text(
                                        _formatAmount(totals.spent),
                                        style: TextStyle(
                                          fontSize: amtFont,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.red.shade600,
                                          height: 1,
                                        ),
                                      ),
                                    if (totals.spent > 0 && totals.received > 0)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        child: Text(
                                          '·',
                                          style: TextStyle(
                                            fontSize: amtFont,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onSurfaceVariant,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    if (totals.received > 0)
                                      Text(
                                        _formatAmount(totals.received),
                                        style: TextStyle(
                                          fontSize: amtFont,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green.shade700,
                                          height: 1,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// Compact labels in day cells: `1.2k` when ≥ 1000, else whole rupees.
  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }
}
