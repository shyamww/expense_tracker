import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/reporting_category_names.dart';
import '../core/money.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../models/expense.dart';
import '../models/income_entry.dart';
import '../widgets/expense_tile.dart';
import '../widgets/income_history_tile.dart';
import '../widgets/expense_action_sheet.dart';

String _dayDetailIncomeDateKey(IncomeEntry e) {
  final dt = DateTime.tryParse(e.createdAt);
  if (dt != null) return DateFormat('yyyy-MM-dd').format(dt);
  return '${e.month}-01';
}

class DayDetailScreen extends StatefulWidget {
  final String date;

  const DayDetailScreen({super.key, required this.date});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  int? _selectedExpenseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final monthKey =
          widget.date.length >= 7 ? widget.date.substring(0, 7) : '';
      if (monthKey.isNotEmpty) {
        context.read<IncomeProvider>().loadIncomeForMonth(monthKey);
      }
    });
  }

  Future<void> _onExpenseLongPress(
      BuildContext context, Expense expense) async {
    if (expense.id == null) return;
    setState(() => _selectedExpenseId = expense.id);
    await showExpenseActionsBottomSheet(
      context: context,
      expense: expense,
      onRefresh: () async {
        final monthKey =
            widget.date.length >= 7 ? widget.date.substring(0, 7) : '';
        final expenseProvider = context.read<ExpenseProvider>();
        final incomeProvider = context.read<IncomeProvider>();
        await expenseProvider.loadExpenses();
        if (monthKey.isNotEmpty && mounted) {
          await incomeProvider.loadIncomeForMonth(monthKey);
        }
      },
      onClosed: () {
        if (mounted) setState(() => _selectedExpenseId = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final incomeProvider = context.watch<IncomeProvider>();
    final parsed = DateTime.tryParse(widget.date);
    final displayDate = parsed != null
        ? DateFormat('dd MMMM yyyy, EEEE').format(parsed)
        : widget.date;

    final dayExpenses = expenseProvider.expenses
        .where((e) => e.date == widget.date)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final dayIncome = incomeProvider.allIncomeHistory
        .where((e) => _dayDetailIncomeDateKey(e) == widget.date)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final spentPaisa = dayExpenses
        .where(
            (e) => ReportingCategoryNames.countsAsSpendingInReports(e.category))
        .fold<int>(0, (sum, e) => sum + e.amount);
    final receivedFromExpPaisa = dayExpenses
        .where(
            (e) => ReportingCategoryNames.countsAsExternalReceived(e.category))
        .fold<int>(0, (sum, e) => sum + e.amount);
    final incomeEntriesPaisa =
        dayIncome.fold<int>(0, (sum, e) => sum + e.amount);
    final totalSpent = rupeesFromPaisa(spentPaisa);
    final totalReceived =
        rupeesFromPaisa(receivedFromExpPaisa + incomeEntriesPaisa);

    final merged = <({String createdAt, Object item})>[];
    for (final e in dayExpenses) {
      merged.add((createdAt: e.createdAt, item: e));
    }
    for (final i in dayIncome) {
      merged.add((createdAt: i.createdAt, item: i));
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          parsed != null
              ? DateFormat('dd MMM yyyy').format(parsed)
              : widget.date,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  displayDate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildStat('Spent', totalSpent, Colors.red.shade500),
                    _buildStat(
                        'Received', totalReceived, Colors.green.shade600),
                    _buildStat(
                      'Net',
                      totalReceived - totalSpent,
                      (totalReceived - totalSpent) >= 0
                          ? Colors.green.shade600
                          : Colors.red.shade500,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: merged.isEmpty
                ? Center(
                    child: Text(
                      'No transactions on this day',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: merged.length,
                    itemBuilder: (context, index) {
                      final row = merged[index];
                      final item = row.item;
                      if (item is Expense) {
                        final expense = item;
                        return ExpenseTile(
                          expense: expense,
                          isSelected: _selectedExpenseId == expense.id,
                          onDeselect: () =>
                              setState(() => _selectedExpenseId = null),
                          onLongPress: expense.id == null
                              ? null
                              : () => _onExpenseLongPress(context, expense),
                        );
                      }
                      final entry = item as IncomeEntry;
                      final dt = DateTime.tryParse(entry.createdAt);
                      final dateStr = dt != null
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(dt)
                          : '';
                      return IncomeHistoryTile(
                        entry: entry,
                        dateStr: dateStr,
                        isSelected: false,
                        onLongPress: null,
                        onDeselect: null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${formatRupeesTwoDecimalsFromDouble(amount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
