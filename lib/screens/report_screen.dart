import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/money.dart';
import '../app_routes.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../constants/reporting_category_names.dart';
import '../providers/category_provider.dart';
import '../widgets/expense_action_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/report_spending_pie.dart';
import '../widgets/web_dashboard_shell.dart';

enum _CategorySortOrder { highToLow, lowToHigh }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final GlobalKey _reportKey = GlobalKey();

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  List<Expense> _filteredExpenses = [];
  Map<String, double> _categoryTotals = {};
  double _total = 0;
  bool _hasSearched = false;
  _CategorySortOrder _categorySortOrder = _CategorySortOrder.highToLow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final categoryProvider = context.read<CategoryProvider>();
      if (!categoryProvider.isLoaded) {
        await categoryProvider.loadCategories();
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        isFrom ? _fromDate = picked : _toDate = picked;
      });
    }
  }

  Future<void> _search() async {
    if (_fromDate.isAfter(_toDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('"From" must be before "To"')),
      );
      return;
    }

    final categoryProvider = context.read<CategoryProvider>();
    if (!categoryProvider.isLoaded) {
      await categoryProvider.loadCategories(notify: false);
      if (!mounted) return;
    }

    final provider = context.read<ExpenseProvider>();

    final from = DateFormat('yyyy-MM-dd').format(_fromDate);
    final to = DateFormat('yyyy-MM-dd').format(_toDate);

    final expenses = await provider.getExpensesByDateRange(from, to);

    final spendingExpenses = expenses
        .where(
            (e) => ReportingCategoryNames.countsAsSpendingInReports(e.category))
        .toList();

    final totals = provider.getCategoryTotals(spendingExpenses);

    final totalPaisa =
        spendingExpenses.fold<int>(0, (sum, e) => sum + e.amount);

    final total = rupeesFromPaisa(totalPaisa);

    setState(() {
      _filteredExpenses = spendingExpenses;
      _categoryTotals = totals;
      _total = total;
      _hasSearched = true;
    });
  }

  Future<void> _shareReportToWhatsApp() async {
    try {
      final boundary = _reportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/expense_report.png');
      await file.writeAsBytes(pngBytes);

      final from = DateFormat('dd MMM yyyy').format(_fromDate);
      final to = DateFormat('dd MMM yyyy').format(_toDate);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Expense Report ($from – $to)\nTotal Spending: ₹${formatRupeesTwoDecimalsFromDouble(_total)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share report')),
        );
      }
    }
  }

  Future<void> _openCategoryTransactions(String category) async {
    final matchingExpenses = _filteredExpenses
        .where((expense) => expense.category == category)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (matchingExpenses.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoryTransactionsSheet(
        category: category,
        expenses: matchingExpenses,
        total: _categoryTotals[category] ?? 0,
        onChanged: _search,
      ),
    );
  }

  List<Widget> _reportActions() {
    return _hasSearched && _categoryTotals.isNotEmpty
        ? [
            IconButton.filledTonal(
              onPressed: _shareReportToWhatsApp,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share report',
            ),
          ]
        : const <Widget>[];
  }

  List<MapEntry<String, double>> _sortedCategoryEntries() {
    final entries = _categoryTotals.entries.toList();

    entries.sort((a, b) {
      final amountComparison =
          _categorySortOrder == _CategorySortOrder.highToLow
              ? b.value.compareTo(a.value)
              : a.value.compareTo(b.value);

      if (amountComparison != 0) return amountComparison;
      return a.key.compareTo(b.key);
    });

    return entries;
  }

  String get _categorySortLabel {
    return switch (_categorySortOrder) {
      _CategorySortOrder.highToLow => 'Max % first',
      _CategorySortOrder.lowToHigh => 'Min % first',
    };
  }

  Widget _buildCategorySortMenu() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopupMenuButton<_CategorySortOrder>(
      tooltip: 'Sort by percentage',
      position: PopupMenuPosition.under,
      initialValue: _categorySortOrder,
      onSelected: (value) {
        setState(() => _categorySortOrder = value);
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: _CategorySortOrder.highToLow,
          checked: _categorySortOrder == _CategorySortOrder.highToLow,
          child: const Text('Max % first'),
        ),
        CheckedPopupMenuItem(
          value: _CategorySortOrder.lowToHigh,
          checked: _categorySortOrder == _CategorySortOrder.lowToHigh,
          child: const Text('Min % first'),
        ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                _categorySortLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebReportBody(CategoryProvider catProv) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWebReportFilters(),
          const SizedBox(height: 16),
          if (!_hasSearched)
            WebPanel(
              child: SizedBox(
                height: 360,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.query_stats_rounded,
                        size: 46,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Build a spending report',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a date range, then search to see totals and category trends.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            RepaintBoundary(
              key: _reportKey,
              child: Container(
                color: scheme.surface,
                child: _buildWebReportResults(catProv),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebReportFilters() {
    final theme = Theme.of(context);

    return WebPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          final fromField = Expanded(
            child: _buildWebDateField(
              'From',
              _fromDate,
              () => _pickDate(isFrom: true),
            ),
          );
          final toField = Expanded(
            child: _buildWebDateField(
              'To',
              _toDate,
              () => _pickDate(isFrom: false),
            ),
          );
          final searchButton = SizedBox(
            height: 48,
            width: stacked ? double.infinity : 158,
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text(
                'Search',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Date range',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [fromField, const SizedBox(width: 12), toField]),
                const SizedBox(height: 12),
                searchButton,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date range',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        fromField,
                        const SizedBox(width: 12),
                        toField,
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              searchButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildWebDateField(String label, DateTime date, VoidCallback onTap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy').format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded,
                size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildWebReportResults(CategoryProvider catProv) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final range =
        '${DateFormat('dd MMM yyyy').format(_fromDate)} - ${DateFormat('dd MMM yyyy').format(_toDate)}';

    if (_categoryTotals.isEmpty) {
      return WebPanel(
        child: SizedBox(
          height: 320,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 42,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  'No spending found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  range,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final overview = WebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.trending_down_rounded,
                      color: scheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spending overview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          range,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: WebMetricTile(
                      icon: Icons.payments_outlined,
                      label: 'Total spent',
                      value: '₹ ${formatRupeesTwoDecimalsFromDouble(_total)}',
                      accent: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WebMetricTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'Transactions',
                      value: '${_filteredExpenses.length}',
                      accent: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ReportSpendingPie(
                categoryTotals: _categoryTotals,
                resolveVisual: catProv.resolveVisual,
              ),
            ],
          ),
        );

        final categories = WebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category breakdown',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click a category to inspect transactions.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildCategorySortMenu(),
                ],
              ),
              const SizedBox(height: 16),
              ..._sortedCategoryEntries().map(
                (entry) => _buildWebCategoryRow(entry, catProv),
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            children: [
              overview,
              const SizedBox(height: 16),
              categories,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: overview),
            const SizedBox(width: 18),
            Expanded(flex: 4, child: categories),
          ],
        );
      },
    );
  }

  Widget _buildWebCategoryRow(
    MapEntry<String, double> entry,
    CategoryProvider catProv,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = catProv.resolveVisual(entry.key);
    final percentage = _total > 0 ? (entry.value / _total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _openCategoryTransactions(entry.key),
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(info.icon, color: info.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 6,
                          backgroundColor: theme.dividerColor,
                          color: info.color.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '₹ ${formatRupeesTwoDecimalsFromDouble(entry.value)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catProv = context.watch<CategoryProvider>();
    final shareButton = _reportActions();

    if (WebDashboardShell.useFor(context)) {
      return WebDashboardShell(
        selectedRoute: AppRoutes.reports,
        title: 'Reports',
        subtitle: 'Analyze spending by date range and category',
        actions: shareButton,
        child: _buildWebReportBody(catProv),
      );
    }

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// DATE PICKERS
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  'From',
                  _fromDate,
                  () => _pickDate(isFrom: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateButton(
                  'To',
                  _toDate,
                  () => _pickDate(isFrom: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          /// SEARCH BUTTON
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
          ),

          if (_hasSearched) ...[
            const SizedBox(height: 18),
            RepaintBoundary(
              key: _reportKey,
              child: Container(
                color: scheme.surface,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Date range header for the captured image
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${DateFormat('dd MMM yyyy').format(_fromDate)} – ${DateFormat('dd MMM yyyy').format(_toDate)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    /// ULTRA COMPACT BAR
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scheme.onPrimary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.trending_down,
                              color: scheme.onPrimary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Spending',
                            style: theme.textTheme.titleSmall!.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '₹ ${formatRupeesTwoDecimalsFromDouble(_total)}',
                            style: theme.textTheme.titleMedium!.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_filteredExpenses.length}',
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: scheme.onPrimary.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// PIE CHART
                    if (_categoryTotals.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                        child: ReportSpendingPie(
                          categoryTotals: _categoryTotals,
                          resolveVisual: catProv.resolveVisual,
                        ),
                      ),

                      const SizedBox(height: 18),

                      /// CATEGORY CARDS
                      ..._categoryTotals.entries.map((entry) {
                        final info = catProv.resolveVisual(entry.key);
                        final percentage =
                            _total > 0 ? (entry.value / _total * 100) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Material(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: () => _openCategoryTransactions(entry.key),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: theme.dividerColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color:
                                            info.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(info.icon,
                                          color: info.color, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tap to view transactions',
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: percentage / 100,
                                              minHeight: 6,
                                              backgroundColor:
                                                  theme.dividerColor,
                                              color: info.color
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹ ${formatRupeesTwoDecimalsFromDouble(entry.value)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],

                    if (_categoryTotals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: Text('No expenses found')),
                      ),
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
        actions: shareButton,
      ),
      body: body,
    );
  }

  Widget _buildDateButton(String label, DateTime date, VoidCallback onTap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _CategoryTransactionsSheet extends StatefulWidget {
  final String category;
  final List<Expense> expenses;
  final double total;
  final Future<void> Function() onChanged;

  const _CategoryTransactionsSheet({
    required this.category,
    required this.expenses,
    required this.total,
    required this.onChanged,
  });

  @override
  State<_CategoryTransactionsSheet> createState() =>
      _CategoryTransactionsSheetState();
}

class _CategoryTransactionsSheetState
    extends State<_CategoryTransactionsSheet> {
  int? _selectedExpenseId;

  Future<void> _onExpenseLongPress(Expense expense) async {
    if (expense.id == null) return;
    setState(() => _selectedExpenseId = expense.id);
    final changed = await showExpenseActionsBottomSheet(
      context: context,
      expense: expense,
      onRefresh: widget.onChanged,
      onClosed: () async {
        if (mounted) {
          setState(() => _selectedExpenseId = null);
        }
      },
    );
    if (changed) {
      await widget.onChanged();
    }
    if (changed && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.expenses.length} transactions · ₹ ${formatRupeesTwoDecimalsFromDouble(widget.total)}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Long press a transaction to modify or delete it.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.expenses.length,
                  itemBuilder: (context, index) {
                    final expense = widget.expenses[index];
                    return ExpenseTile(
                      expense: expense,
                      isSelected: _selectedExpenseId == expense.id,
                      onDeselect: () =>
                          setState(() => _selectedExpenseId = null),
                      onLongPress: expense.id == null
                          ? null
                          : () => _onExpenseLongPress(expense),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
