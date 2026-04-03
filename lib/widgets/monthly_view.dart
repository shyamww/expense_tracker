import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../db/database_helper.dart';

class MonthlyView extends StatefulWidget {
  final DateTime selectedMonth;

  const MonthlyView({
    super.key,
    required this.selectedMonth,
  });

  @override
  State<MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends State<MonthlyView> {
  late int _selectedYear;
  Map<String, ({double spent, double received})> _monthlyTotals = {};
  Map<String, double> _monthlyIncome = {};
  Map<String, double> _monthlyCarryForward = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.selectedMonth.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didUpdateWidget(MonthlyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMonth.year != _selectedYear) {
      _selectedYear = widget.selectedMonth.year;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final expenseProvider = context.read<ExpenseProvider>();
    final totals = await expenseProvider.getMonthlyTotalsForYear(_selectedYear);

    final dbHelper = DatabaseHelper();
    final incomeRecords = await dbHelper.getIncomeForYear(_selectedYear);
    final Map<String, double> incomeMap = {};
    for (final inc in incomeRecords) {
      incomeMap[inc.month] = inc.amount;
    }

    final Map<String, double> carryMap = {};
    for (int m = 1; m <= 12; m++) {
      final monthKey = '$_selectedYear-${m.toString().padLeft(2, '0')}';
      carryMap[monthKey] = await dbHelper.getCarryForwardForMonth(monthKey);
    }

    if (mounted) {
      setState(() {
        _monthlyTotals = totals;
        _monthlyIncome = incomeMap;
        _monthlyCarryForward = carryMap;
        _isLoading = false;
      });
    }
  }

  bool get _isCurrentYear => _selectedYear == DateTime.now().year;

  void _changeYear(int delta) {
    final target = _selectedYear + delta;
    if (delta > 0 && target > DateTime.now().year) return;
    setState(() {
      _selectedYear = target;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _changeYear(-1),
                ),
                Text(
                  '$_selectedYear',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _isCurrentYear ? Colors.grey.shade300 : null,
                  ),
                  onPressed: _isCurrentYear ? null : () => _changeYear(1),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 60),
            itemCount: _isCurrentYear ? DateTime.now().month : 12,
            itemBuilder: (context, index) {
              final maxMonth = _isCurrentYear ? DateTime.now().month : 12;
              final monthNum = maxMonth - index;
              final monthKey = '$_selectedYear-${monthNum.toString().padLeft(2, '0')}';
              final monthDate = DateTime(_selectedYear, monthNum);
              final monthTitle = DateFormat('MMMM').format(monthDate);
              final startStr = DateFormat('dd MMM').format(DateTime(_selectedYear, monthNum, 1));
              final endStr = DateFormat('dd MMM').format(
                DateTime(_selectedYear, monthNum + 1, 0),
              );

              final totals = _monthlyTotals[monthKey] ?? (spent: 0.0, received: 0.0);
              final income = _monthlyIncome[monthKey] ?? 0.0;
              final carryFwd = _monthlyCarryForward[monthKey] ?? 0.0;
              final totalIncome = income + totals.received;
              final balance = carryFwd + totalIncome - totals.spent;
              final hasData = totals.spent > 0 || totalIncome > 0 || carryFwd != 0;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: hasData ? Colors.grey.shade900 : Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$startStr – $endStr',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${totalIncome.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: totalIncome > 0
                                ? const Color(0xFF059669)
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totals.spent.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: totals.spent > 0
                                ? const Color(0xFFDC2626)
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          balance >= 0
                              ? 'Bal ₹${balance.toStringAsFixed(0)}'
                              : 'Bal -₹${balance.abs().toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: !hasData
                                ? Colors.grey.shade400
                                : balance >= 0
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
