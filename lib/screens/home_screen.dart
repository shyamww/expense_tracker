import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../providers/income_provider.dart';
import '../widgets/expense_tile.dart';
import '../widgets/calendar_view.dart';
import '../widgets/monthly_view.dart';
import '../widgets/install_countdown_bar.dart';
import '../widgets/expense_action_sheet.dart';
import 'add_expense_screen.dart';
import 'income_screen.dart';
import 'report_screen.dart';
import 'backup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedMonth;
  int _lastTappedTab = 0;
  DateTime _lastTapTime = DateTime.now();
  final Set<String> _collapsedDates = {};
  int? _selectedExpenseId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabDoubleTap(int index) {
    final now = DateTime.now();
    if (_lastTappedTab == index &&
        now.difference(_lastTapTime).inMilliseconds < 400) {
      setState(() {
        _selectedMonth = DateTime(now.year, now.month);
      });
      context.read<IncomeProvider>().loadIncomeForMonth(
        DateFormat('yyyy-MM').format(_selectedMonth),
      );
    }
    _lastTappedTab = index;
    _lastTapTime = now;
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final expenseProvider = context.read<ExpenseProvider>();
    final incomeProvider = context.read<IncomeProvider>();
    await expenseProvider.loadExpenses();
    await incomeProvider.loadIncomeForCurrentMonth();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  Future<void> _selectMonth(DateTime m) async {
    final clamped = DateTime(m.year, m.month);
    final now = DateTime.now();
    if (clamped.year > now.year ||
        (clamped.year == now.year && clamped.month > now.month)) {
      return;
    }
    if (_selectedMonth.year == clamped.year && _selectedMonth.month == clamped.month) {
      return;
    }
    setState(() => _selectedMonth = clamped);
    await context.read<IncomeProvider>().loadIncomeForMonth(
      DateFormat('yyyy-MM').format(_selectedMonth),
    );
  }

  Future<void> _changeMonth(int delta) async {
    await _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month + delta));
  }

  String get _monthPrefix => DateFormat('yyyy-MM').format(_selectedMonth);

  Future<void> _onExpenseLongPress(BuildContext context, Expense expense) async {
    if (expense.id == null) return;
    setState(() => _selectedExpenseId = expense.id);
    await showExpenseActionsBottomSheet(
      context: context,
      expense: expense,
      onClosed: () {
        if (!mounted) return;
        setState(() => _selectedExpenseId = null);
        _loadData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final incomeProvider = context.watch<IncomeProvider>();
    final theme = Theme.of(context);

    final spent = expenseProvider.totalSpentForMonth(_monthPrefix);
    final received = expenseProvider.totalReceivedForMonth(_monthPrefix);
    final carryForward = incomeProvider.carryForward;
    final income = incomeProvider.monthlyIncome + received;
    final total = carryForward + income - spent;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: _isCurrentMonth ? Colors.grey.shade300 : null,
                    ),
                    onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                  ),
                ],
              ),
            ),
          ),

          _buildSummaryCards(
            carryForward: carryForward,
            income: income,
            spent: spent,
            total: total,
          ),

          const SizedBox(height: 6),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelColor: Colors.grey.shade500,
              labelColor: theme.colorScheme.primary,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
              onTap: _onTabDoubleTap,
              tabs: const [
                Tab(text: 'Daily'),
                Tab(text: 'Calendar'),
                Tab(text: 'Monthly'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Daily Tab
                _buildDailyTab(expenseProvider),
                // Calendar Tab
                CalendarView(
                  selectedMonth: _selectedMonth,
                  expenses: expenseProvider.expenses,
                  onMonthSelected: _selectMonth,
                ),
                // Monthly Tab
                MonthlyView(selectedMonth: _selectedMonth),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          if (mounted) _loadData();
        },
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          height: 72,
          padding: EdgeInsets.zero,
          elevation: 0,
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: InstallCountdownBar(),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomBarItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Income',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const IncomeScreen()),
                        );
                        if (mounted) _loadData();
                      },
                    ),
                    _buildBottomBarItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Report',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 48),
                    _buildBottomBarItem(
                      icon: Icons.cloud_sync_outlined,
                      label: 'Backup',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BackupScreen()),
                        );
                        if (mounted) _loadData();
                      },
                    ),
                    _buildBottomBarItem(
                      icon: Icons.settings_outlined,
                      label: 'More',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards({
    required double carryForward,
    required double income,
    required double spent,
    required double total,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _FintechSummaryCard(
                label: 'Income',
                value: income,
                accent: const Color(0xFF2563EB),
                icon: Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _FintechSummaryCard(
                label: 'Expense',
                value: spent,
                accent: const Color(0xFFDC2626),
                icon: Icons.north_east_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: _BalanceSummaryCard(
                carryForward: carryForward,
                balance: total,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Colors.deepPurple.shade400),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTab(ExpenseProvider expenseProvider) {
    final grouped = expenseProvider.getExpensesGroupedByDay(_monthPrefix);

    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text(
              'No expenses yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to add your first expense',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateStr = sortedDates[index];
        final dayExpenses = grouped[dateStr]!;
        final isCollapsed = _collapsedDates.contains(dateStr);
        final dayTotal = dayExpenses
            .where((e) => e.category != 'Received')
            .fold(0.0, (sum, e) => sum + e.amount);
        final dayReceived = dayExpenses
            .where((e) => e.category == 'Received')
            .fold(0.0, (sum, e) => sum + e.amount);

        final date = DateTime.tryParse(dateStr);
        final displayDate = date != null
            ? DateFormat('dd MMM, EEEE').format(date)
            : dateStr;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header (tappable to collapse/expand)
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedDates.remove(dateStr);
                  } else {
                    _collapsedDates.add(dateStr);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isCollapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      displayDate,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    if (dayTotal > 0)
                      Text(
                        '₹${dayTotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade500,
                        ),
                      ),
                    if (dayTotal > 0 && dayReceived > 0)
                      const SizedBox(width: 8),
                    if (dayReceived > 0)
                      Text(
                        '+₹${dayReceived.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade600,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      '(${dayExpenses.length})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expense tiles (hidden when collapsed)
            if (!isCollapsed)
              ...dayExpenses.map((expense) => ExpenseTile(
                    expense: expense,
                    isSelected: _selectedExpenseId == expense.id,
                    onDeselect: () => setState(() => _selectedExpenseId = null),
                    onLongPress: expense.id == null
                        ? null
                        : () => _onExpenseLongPress(context, expense),
                  )),
            if (!isCollapsed)
              Divider(height: 1, color: Colors.grey.shade200),
          ],
        );
      },
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  final double carryForward;
  final double balance;

  const _BalanceSummaryCard({
    required this.carryForward,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final accent = balance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final hasCarry = carryForward != 0;
    final carryColor = carryForward >= 0 ? const Color(0xFF0D9488) : const Color(0xFFEA580C);
    final carryBg = carryForward >= 0
        ? const Color(0xFFCCFBF1).withValues(alpha: 0.65)
        : const Color(0xFFFFEDD5).withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.account_balance_wallet_rounded, size: 18, color: accent),
          ),
          const SizedBox(height: 6),
          Text(
            'BALANCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${balance.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.05,
            ),
          ),
          if (hasCarry) ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: carryBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: carryColor.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 12, color: carryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Carry forward',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        height: 1.05,
                      ),
                    ),
                  ),
                  Text(
                    '₹${carryForward.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: carryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FintechSummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color accent;
  final IconData icon;

  const _FintechSummaryCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}
