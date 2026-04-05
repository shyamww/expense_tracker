import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/money.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../providers/category_provider.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _fromDate =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
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

    // 🔥 Remove "Received"
    final spendingExpenses = expenses
        .where((e) => e.category != CategoryProvider.kReceivedCategoryName)
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catProv = context.watch<CategoryProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7), // 👈 important
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
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.trending_down,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Spending',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    Text(
                      '₹ ${formatRupeesTwoDecimalsFromDouble(_total)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_filteredExpenses.length}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),

              /// PIE CHART
              if (_categoryTotals.isNotEmpty) ...[
                const SizedBox(height: 22),
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 45,
                      sections: _buildPieChartSections(),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                /// 🔥 CATEGORY CARDS (FINAL DESIGN)
                ..._categoryTotals.entries.map((entry) {
                  final info = catProv.resolveVisual(entry.key);
                  final percentage =
                      _total > 0 ? (entry.value / _total * 100) : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        /// ICON
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: info.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child:
                              Icon(info.icon, color: info.color, size: 24),
                        ),

                        const SizedBox(width: 14),

                        /// TEXT + BAR
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
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  minHeight: 6,
                                  backgroundColor:
                                      Colors.grey.shade200,
                                  color:
                                      info.color.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 14),

                        /// AMOUNT
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
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildDateButton(
      String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(DateFormat('dd MMM yyyy').format(date)),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final catProv = context.read<CategoryProvider>();

    return _categoryTotals.entries.map((entry) {
      final info = catProv.resolveVisual(entry.key);
      final percentage =
          _total > 0 ? (entry.value / _total * 100) : 0.0;

      return PieChartSectionData(
        value: entry.value,
        color: info.color,
        radius: 55,
        title: '${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }
}