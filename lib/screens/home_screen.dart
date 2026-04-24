import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../models/income_entry.dart';
import '../providers/income_provider.dart';
import '../constants/reporting_category_names.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/app_navigation_hub.dart';
import '../services/expense_reminder_service.dart';
import '../widgets/expense_tile.dart';
import '../widgets/income_history_tile.dart';
import '../widgets/calendar_view.dart';
import '../widgets/monthly_view.dart';
import '../widgets/install_countdown_bar.dart';
import '../widgets/expense_action_sheet.dart';
import 'add_expense_screen.dart';
import 'income_screen.dart';
import 'report_screen.dart';
import 'accounts_list_screen.dart';
import 'settings_screen.dart';

String _incomeEntryCalendarDateKey(IncomeEntry e) {
  final dt = DateTime.tryParse(e.createdAt);
  if (dt != null) return DateFormat('yyyy-MM-dd').format(dt);
  return '${e.month}-01';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedMonth;
  int _lastTappedTab = 0;
  DateTime _lastTapTime = DateTime.now();
  final Set<String> _collapsedDates = {};
  int? _selectedExpenseId;
  AppNavigationHub? _navHub;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  Future<void> _afterFirstFrame() async {
    if (!mounted) return;
    await _loadData();
    if (!mounted) return;
    if (!kIsWeb) {
      _navHub = context.read<AppNavigationHub>();
      _navHub!.addListener(_onHomeDashboardRequested);
      if (await ExpenseReminderService.instance
          .launchedFromReminderNotification()) {
        if (mounted) _goHome();
      }
    }
  }

  void _onHomeDashboardRequested() {
    if (!mounted) return;
    _goHome();
  }

  @override
  void dispose() {
    _navHub?.removeListener(_onHomeDashboardRequested);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _jumpToCurrentMonth() async {
    final now = DateTime.now();
    final clamped = DateTime(now.year, now.month);
    final monthKey = DateFormat('yyyy-MM').format(clamped);

    final incomeProvider = context.read<IncomeProvider>();
    await incomeProvider.loadIncomeForMonth(monthKey, notify: false);

    if (!mounted) return;
    setState(() {
      _selectedMonth = clamped;
    });
    incomeProvider.forceNotify();
  }

  void _onTabDoubleTap(int index) {
    final now = DateTime.now();
    if (_lastTappedTab == index &&
        now.difference(_lastTapTime).inMilliseconds < 400) {
      _jumpToCurrentMonth();
    }
    _lastTappedTab = index;
    _lastTapTime = now;
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    _jumpToCurrentMonth();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final expenseProvider = context.read<ExpenseProvider>();
    final incomeProvider = context.read<IncomeProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();

    await Future.wait([
      expenseProvider.loadExpenses(notify: false),
      incomeProvider.loadIncomeForCurrentMonth(notify: false),
      categoryProvider.loadCategories(notify: false),
      accountProvider.refresh(notify: false),
    ]);

    if (!mounted) return;

    // Trigger UI updates only once all data is fully loaded
    expenseProvider.forceNotify();
    incomeProvider.forceNotify();
    categoryProvider.forceNotify();
    accountProvider.forceNotify();

    if (!_isInitialized) {
      setState(() {
        _isInitialized = true;
      });
    }
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
    if (_selectedMonth.year == clamped.year &&
        _selectedMonth.month == clamped.month) {
      return;
    }

    final monthKey = DateFormat('yyyy-MM').format(clamped);
    final incomeProvider = context.read<IncomeProvider>();

    await incomeProvider.loadIncomeForMonth(monthKey, notify: false);

    if (!mounted) return;
    setState(() => _selectedMonth = clamped);
    incomeProvider.forceNotify();
  }

  Future<void> _changeMonth(int delta) async {
    await _selectMonth(
        DateTime(_selectedMonth.year, _selectedMonth.month + delta));
  }

  String get _monthPrefix => DateFormat('yyyy-MM').format(_selectedMonth);

  Future<void> _onExpenseLongPress(
      BuildContext context, Expense expense) async {
    if (expense.id == null) return;
    setState(() => _selectedExpenseId = expense.id);
    await showExpenseActionsBottomSheet(
      context: context,
      expense: expense,
      onRefresh: _loadData,
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
    final accountProvider = context.watch<AccountProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final spent = expenseProvider.totalSpentForMonth(_monthPrefix);
    final received = expenseProvider.totalReceivedForMonth(_monthPrefix);
    final carryForward = incomeProvider.carryForward;
    final income = incomeProvider.monthlyIncome + received;

    final accountsTotal = accountProvider.cumulativeBalance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUnifiedSummaryCard(
            carryForward: carryForward,
            income: income,
            spent: spent,
          ),

          const SizedBox(height: 6),

          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: SizedBox(
              height: 44,
              child: TabBar(
                controller: _tabController,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelColor: theme.colorScheme.primary,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 2.5,
                onTap: _onTabDoubleTap,
                tabs: const [
                  Tab(text: 'Daily'),
                  Tab(text: 'Calendar'),
                  Tab(text: 'Monthly'),
                ],
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Daily Tab
                _buildDailyTab(expenseProvider, incomeProvider),
                // Calendar Tab
                CalendarView(
                  selectedMonth: _selectedMonth,
                  expenses: expenseProvider.expenses,
                  incomeHistory: incomeProvider.allIncomeHistory,
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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
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
      // Color/elevation must live on [BottomAppBar], not an outer [Container], or the top edge stays a straight line and hides the notch.
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 72,
        padding: EdgeInsets.zero,
        elevation: 10,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: InstallCountdownBar(),
              ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBottomBarItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    onTap: _goHome,
                  ),
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
                  const SizedBox(width: 48),
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
                  _buildBottomBarItem(
                    icon: Icons.account_balance_outlined,
                    label: 'Accounts',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AccountsListScreen()),
                      );
                      if (mounted) _loadData();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthNavButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: disabled
                ? theme.colorScheme.surfaceContainerLow
                : theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor,
            ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: disabled
                ? theme.colorScheme.outlineVariant
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  /// Slim month strip (all tabs) — less vertical padding under the app bar.
  Widget _buildMonthNavigator(ThemeData theme) {
    final isCurrent = _isCurrentMonth;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // LEFT BUTTON
            _monthNavButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => _changeMonth(-1),
            ),

            // MONTH TEXT (CENTER FOCUS)
            Expanded(
              child: Column(
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCurrent ? 'Current month' : 'Tap arrows to change',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // RIGHT BUTTON
            _monthNavButton(
              icon: Icons.chevron_right_rounded,
              onTap: isCurrent ? null : () => _changeMonth(1),
              disabled: isCurrent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedSummaryCard({
    required double carryForward,
    required double income,
    required double spent,
  }) {
    final theme = Theme.of(context);
    final currentBalance = ((carryForward + income - spent).isFinite
            ? carryForward + income - spent
            : 0.0)
        .toDouble();
    final isCurrent = _isCurrentMonth;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.shade400.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 MONTH NAVIGATION INSIDE CARD
            Row(
              children: [
                _monthNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _changeMonth(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                _monthNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: isCurrent ? null : () => _changeMonth(1),
                  disabled: isCurrent,
                ),
              ],
            ),

            const SizedBox(height: 8),

            /// 🔹 BALANCE
            Text(
              'Current balance',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₹ ${formatRupeesTwoDecimalsFromDouble(currentBalance)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: currentBalance >= 0
                    ? Colors.green.shade800
                    : Colors.red.shade700,
                height: 1.05,
              ),
            ),

            /// 🔹 CARRY FORWARD
            if (carryForward != 0) ...[
              const SizedBox(height: 4),
              Text(
                'Includes carry forward ₹ ${formatRupeesTwoDecimalsFromDouble(carryForward)}',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            Divider(
              color: Colors.green.shade400.withValues(alpha: 0.28),
              height: 18,
            ),

            /// 🔹 INCOME
            _summaryRow(
              label: 'Total income',
              amount: income,
              icon: Icons.south_west_rounded,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 6),

            /// 🔹 EXPENSE
            _summaryRow(
              label: 'Total expense',
              amount: spent,
              icon: Icons.north_east_rounded,
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        Text(
          '₹ ${formatRupeesTwoDecimalsFromDouble(amount)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards({
    required double carryForward,
    required double income,
    required double spent,
    required double accountsTotal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _FintechSummaryCard(
              label: 'Income',
              value: income,
              accent: const Color(0xFF2563EB),
              icon: Icons.south_west_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FintechSummaryCard(
              label: 'Expense',
              value: spent,
              accent: const Color(0xFFDC2626),
              icon: Icons.north_east_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BalanceSummaryCard(
              carryForward: carryForward,
              balance: accountsTotal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTab(
      ExpenseProvider expenseProvider, IncomeProvider incomeProvider) {
    final theme = Theme.of(context);
    final grouped = expenseProvider.getExpensesGroupedByDay(_monthPrefix);
    final incomeByDay = <String, List<IncomeEntry>>{};
    for (final inc in incomeProvider.allIncomeHistory) {
      final dk = _incomeEntryCalendarDateKey(inc);
      if (!dk.startsWith(_monthPrefix)) continue;
      incomeByDay.putIfAbsent(dk, () => []).add(inc);
    }
    for (final list in incomeByDay.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final allDates = {...grouped.keys, ...incomeByDay.keys};
    if (allDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 60, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              'No activity yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + for expenses or use Income for salary',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateStr = sortedDates[index];
        final dayExpenses = grouped[dateStr] ?? [];
        final dayIncome = incomeByDay[dateStr] ?? [];
        final isCollapsed = _collapsedDates.contains(dateStr);
        final dayTotalPaisa = dayExpenses
            .where((e) =>
                ReportingCategoryNames.countsAsSpendingInReports(e.category))
            .fold<int>(0, (sum, e) => sum + e.amount);
        final dayReceivedPaisa = dayExpenses
                .where((e) =>
                    ReportingCategoryNames.countsAsExternalReceived(e.category))
                .fold<int>(0, (sum, e) => sum + e.amount) +
            dayIncome.fold<int>(0, (sum, e) => sum + e.amount);
        final dayTotal = rupeesFromPaisa(dayTotalPaisa);
        final dayReceived = rupeesFromPaisa(dayReceivedPaisa);

        final date = DateTime.tryParse(dateStr);
        final displayDate =
            date != null ? DateFormat('dd MMM, EEEE').format(date) : dateStr;

        final itemCount = dayExpenses.length + dayIncome.length;

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
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isCollapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      displayDate,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (dayTotal > 0)
                      Text(
                        '₹${formatRupeesTwoDecimalsFromDouble(dayTotal)}',
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
                        '+₹${formatRupeesTwoDecimalsFromDouble(dayReceived)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade600,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      '($itemCount)',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expense tiles (hidden when collapsed)
            if (!isCollapsed) ...[
              ...dayExpenses.map((expense) => ExpenseTile(
                    expense: expense,
                    isSelected: _selectedExpenseId == expense.id,
                    onDeselect: () => setState(() => _selectedExpenseId = null),
                    onLongPress: expense.id == null
                        ? null
                        : () => _onExpenseLongPress(context, expense),
                  )),
              ...dayIncome.map((entry) {
                final created = DateTime.tryParse(entry.createdAt);
                final dateStrIncome = created != null
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(created)
                    : '';
                return IncomeHistoryTile(
                  entry: entry,
                  dateStr: dateStrIncome,
                  isSelected: false,
                  onLongPress: null,
                  onDeselect: null,
                );
              }),
            ],
            if (!isCollapsed) Divider(height: 1, color: theme.dividerColor),
          ],
        );
      },
    );
  }
}

/// Reserved under the main amount so Income / Expense / Balance cards stay one height.
const double _kSummaryFooterSlotHeight = 30;

class _BalanceSummaryCard extends StatelessWidget {
  final double carryForward;
  final double balance;

  const _BalanceSummaryCard({
    required this.carryForward,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        balance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final hasCarry = carryForward != 0;
    final carryColor =
        carryForward >= 0 ? const Color(0xFF0D9488) : const Color(0xFFEA580C);
    final carryBg = carryForward >= 0
        ? const Color(0xFFCCFBF1).withValues(alpha: 0.65)
        : const Color(0xFFFFEDD5).withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                size: 16, color: accent),
          ),
          const SizedBox(height: 5),
          Text(
            'ACCOUNTS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${formatRupeesTwoDecimalsFromDouble(balance)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: _kSummaryFooterSlotHeight,
            width: double.infinity,
            child: hasCarry
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: carryBg,
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: carryColor.withValues(alpha: 0.22)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded,
                            size: 11, color: carryColor),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'Carry forward',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                              height: 1.05,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${formatRupeesTwoDecimalsFromDouble(carryForward)}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: carryColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${formatRupeesTwoDecimalsFromDouble(value)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: _kSummaryFooterSlotHeight),
        ],
      ),
    );
  }
}
