import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../constants/reporting_category_names.dart';
import '../providers/category_provider.dart';
import '../widgets/expense_action_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/report_spending_pie.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  List<Expense> _filteredExpenses = [];
  Map<String, double> _categoryTotals = {};
  double _total = 0;
  bool _hasSearched = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catProv = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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

              /// 🔥 ULTRA COMPACT BAR
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

                /// 🔥 CATEGORY CARDS (FINAL DESIGN)
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
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: theme.dividerColor,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: info.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(info.icon,
                                    color: info.color, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: percentage / 100,
                                        minHeight: 6,
                                        backgroundColor: theme.dividerColor,
                                        color:
                                            info.color.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
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
            ]
          ],
        ),
      ),
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
