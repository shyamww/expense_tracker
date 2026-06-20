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

    return Column(
      children: [
        _buildWeekdayHeader(context),
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

  Widget _buildWeekdayHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 720;
        final labels = roomy
            ? const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

        return Container(
          height: roomy ? 38 : 30,
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: labels.asMap().entries.map((entry) {
              final weekend = entry.key == 0 || entry.key == 6;
              return Expanded(
                child: Center(
                  child: Text(
                    entry.value,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: weekend
                          ? Colors.red.shade400
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
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
    const rowCount = 6;

    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 720;
        final maxRow = roomy ? 94.0 : 76.0;
        const padBottom = 8.0;
        final innerH =
            (constraints.maxHeight - padBottom).clamp(0.0, double.infinity);
        final perRow = innerH / rowCount;
        final rowH = perRow > maxRow ? maxRow : perRow;
        final slack = (innerH - rowH * rowCount).clamp(0.0, double.infinity);

        return Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, padBottom + slack),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedFill = scheme.primaryContainer.withValues(alpha: 0.65);
    final selectedBorder = scheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 40.0;
        final roomy = constraints.maxWidth >= 720;
        final dayFont = roomy ? 15.0 : (h * 0.24).clamp(11.0, 13.0);
        final badgeFont = roomy ? 11.0 : (h * 0.16).clamp(7.0, 9.0);
        final cellMargin = roomy ? 3.0 : 1.5;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(7, (colIndex) {
            final cellIndex = rowIndex * 7 + colIndex;
            final dayNum = cellIndex - startWeekday + 1;
            final cellDate = DateTime(month.year, month.month, dayNum);
            final inCurrentMonth = dayNum >= 1 && dayNum <= daysInMonth;
            final dateStr = DateFormat('yyyy-MM-dd').format(
              cellDate,
            );
            final totals = inCurrentMonth ? dailyTotals[dateStr] : null;
            final hasTotals =
                totals != null && (totals.spent > 0 || totals.received > 0);
            final isToday = inCurrentMonth && dateStr == todayStr;
            final isWeekend = colIndex == 0 || colIndex == 6;
            final isSelected = inCurrentMonth && _selectedDateStr == dateStr;

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
            } else if (!inCurrentMonth) {
              cellBg = scheme.surfaceContainerLowest;
              borderColor = theme.dividerColor.withValues(alpha: 0.45);
              borderWidth = 0.5;
            } else if (hasTotals) {
              cellBg = scheme.surface;
              borderColor = theme.dividerColor.withValues(alpha: 0.9);
              borderWidth = 0.8;
            } else {
              cellBg = Theme.of(context).colorScheme.surface;
              borderColor =
                  Theme.of(context).dividerColor.withValues(alpha: 0.65);
              borderWidth = 0.5;
            }

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: !inCurrentMonth
                      ? null
                      : () {
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: EdgeInsets.all(cellMargin),
                    padding: EdgeInsets.all(roomy ? 10 : 6),
                    decoration: BoxDecoration(
                      color: cellBg,
                      border:
                          Border.all(color: borderColor, width: borderWidth),
                      borderRadius: BorderRadius.circular(8),
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
                    child: Opacity(
                      opacity: inCurrentMonth ? 1 : 0.42,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${cellDate.day}',
                                style: TextStyle(
                                  fontSize: dayFont,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.w900
                                      : FontWeight.w800,
                                  color: isSelected
                                      ? selectedBorder
                                      : isToday
                                          ? theme.colorScheme.primary
                                          : isWeekend
                                              ? Colors.red.shade400
                                              : scheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              if (isToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Today',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          if (hasTotals)
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (totals.spent > 0)
                                  _amountBadge(
                                    context,
                                    '-${_formatAmount(totals.spent)}',
                                    Colors.red.shade600,
                                    badgeFont,
                                  ),
                                if (totals.received > 0)
                                  _amountBadge(
                                    context,
                                    '+${_formatAmount(totals.received)}',
                                    Colors.green.shade700,
                                    badgeFont,
                                  ),
                              ],
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

  Widget _amountBadge(
    BuildContext context,
    String text,
    Color color,
    double fontSize,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
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
