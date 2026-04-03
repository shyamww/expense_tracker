import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../widgets/expense_tile.dart';
import '../widgets/expense_action_sheet.dart';

class DayDetailScreen extends StatefulWidget {
  final String date;

  const DayDetailScreen({super.key, required this.date});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  int? _selectedExpenseId;

  Future<void> _onExpenseLongPress(BuildContext context, Expense expense) async {
    if (expense.id == null) return;
    setState(() => _selectedExpenseId = expense.id);
    await showExpenseActionsBottomSheet(
      context: context,
      expense: expense,
      onClosed: () {
        if (mounted) setState(() => _selectedExpenseId = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final parsed = DateTime.tryParse(widget.date);
    final displayDate = parsed != null
        ? DateFormat('dd MMMM yyyy, EEEE').format(parsed)
        : widget.date;

    final dayExpenses = expenseProvider.expenses
        .where((e) => e.date == widget.date)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalSpent = dayExpenses
        .where((e) => e.category != 'Received')
        .fold(0.0, (sum, e) => sum + e.amount);
    final totalReceived = dayExpenses
        .where((e) => e.category == 'Received')
        .fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          parsed != null ? DateFormat('dd MMM yyyy').format(parsed) : widget.date,
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
                    _buildStat('Received', totalReceived, Colors.green.shade600),
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
            child: dayExpenses.isEmpty
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
                    itemCount: dayExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = dayExpenses[index];
                      return ExpenseTile(
                        expense: expense,
                        isSelected: _selectedExpenseId == expense.id,
                        onDeselect: () => setState(() => _selectedExpenseId = null),
                        onLongPress: expense.id == null
                            ? null
                            : () => _onExpenseLongPress(context, expense),
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
            '₹${amount.toStringAsFixed(0)}',
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
