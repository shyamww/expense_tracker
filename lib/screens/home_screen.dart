import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_routes.dart';
import '../core/money.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../models/income_entry.dart';
import '../providers/income_provider.dart';
import '../constants/reporting_category_names.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/app_navigation_hub.dart';
import '../services/browser_route.dart';
import '../services/expense_reminder_service.dart';
import '../widgets/expense_tile.dart';
import '../widgets/income_history_tile.dart';
import '../widgets/calendar_view.dart';
import '../widgets/monthly_view.dart';
import '../widgets/install_countdown_bar.dart';
import '../widgets/expense_action_sheet.dart';
import '../widgets/web_dashboard_shell.dart';
import 'add_expense_screen.dart';

String _incomeEntryCalendarDateKey(IncomeEntry e) {
  final dt = DateTime.tryParse(e.createdAt);
  if (dt != null) return DateFormat('yyyy-MM-dd').format(dt);
  return '${e.month}-01';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

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
    final initialTab = widget.initialTabIndex.clamp(0, 2);
    _lastTappedTab = initialTab;
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: initialTab);
    _tabController.addListener(_handleTabControllerChange);
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  void _handleTabControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTab = widget.initialTabIndex.clamp(0, 2);
    if (nextTab != _tabController.index) {
      _tabController.index = nextTab;
      _lastTappedTab = nextTab;
    }
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
    _tabController.removeListener(_handleTabControllerChange);
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

  void _onTabTapped(int index) {
    _onTabDoubleTap(index);
    if (!kIsWeb) return;
    final target = AppRoutes.homeRouteForTab(index);
    final current = ModalRoute.of(context)?.settings.name;
    if (current == target) return;
    _openWebRoute(target);
  }

  Set<String> _dailyActivityDateKeys(
    ExpenseProvider expenseProvider,
    IncomeProvider incomeProvider,
  ) {
    final monthExpenseDates = expenseProvider.expenses
        .where((e) => e.date.startsWith(_monthPrefix))
        .map((e) => e.date);
    final monthIncomeDates = incomeProvider.allIncomeHistory
        .map(_incomeEntryCalendarDateKey)
        .where((date) => date.startsWith(_monthPrefix));
    return {...monthExpenseDates, ...monthIncomeDates};
  }

  void _toggleAllDailySections(Set<String> dateKeys) {
    if (dateKeys.isEmpty) return;
    final allCollapsed = dateKeys.every(_collapsedDates.contains);
    setState(() {
      if (allCollapsed) {
        _collapsedDates.removeAll(dateKeys);
      } else {
        _collapsedDates.addAll(dateKeys);
      }
    });
  }

  void _goHome() {
    if (kIsWeb) {
      final current = ModalRoute.of(context)?.settings.name;
      if (current != AppRoutes.homeDaily) {
        _openWebRoute(AppRoutes.homeDaily);
        return;
      }
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    _jumpToCurrentMonth();
  }

  void _openWebRoute(String route) {
    pushBrowserRoute(route);
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  Future<void> _openAddExpense() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
    if (mounted) _loadData();
  }

  Future<void> _openIncome() async {
    if (kIsWeb) {
      _openWebRoute(AppRoutes.income);
      return;
    }
    await Navigator.pushNamed(context, AppRoutes.income);
    if (mounted) _loadData();
  }

  void _openReport() {
    if (kIsWeb) {
      _openWebRoute(AppRoutes.reports);
      return;
    }
    Navigator.pushNamed(context, AppRoutes.reports);
  }

  Future<void> _openAccounts() async {
    if (kIsWeb) {
      _openWebRoute(AppRoutes.accounts);
      return;
    }
    await Navigator.pushNamed(context, AppRoutes.accounts);
    if (mounted) _loadData();
  }

  void _openSettings() {
    if (kIsWeb) {
      _openWebRoute(AppRoutes.settings);
      return;
    }
    Navigator.pushNamed(context, AppRoutes.settings);
  }

  void _handleDesktopDestination(int index) {
    switch (index) {
      case 0:
        _goHome();
        break;
      case 1:
        _openIncome();
        break;
      case 2:
        _openReport();
        break;
      case 3:
        _openAccounts();
        break;
      case 4:
        _openSettings();
        break;
    }
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useWebShell = kIsWeb && screenWidth >= 560;
    final isWide = !useWebShell && screenWidth >= 900;

    if (useWebShell) {
      return _buildWebDashboardShell(
        expenseProvider: expenseProvider,
        incomeProvider: incomeProvider,
        carryForward: carryForward,
        income: income,
        spent: spent,
        accountsTotal: accountsTotal,
      );
    }

    final dashboardBody = Column(
      children: [
        if (isWide) ...[
          _buildMonthNavigator(theme),
          _buildSummaryCards(
            carryForward: carryForward,
            income: income,
            spent: spent,
            accountsTotal: accountsTotal,
          ),
        ] else
          _buildUnifiedSummaryCard(
            carryForward: carryForward,
            income: income,
            spent: spent,
          ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius:
                isWide ? BorderRadius.circular(14) : BorderRadius.zero,
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
              onTap: _onTabTapped,
              tabs: const [
                Tab(text: 'Daily'),
                Tab(text: 'Calendar'),
                Tab(text: 'Monthly'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildDailyTab(expenseProvider, incomeProvider),
              CalendarView(
                selectedMonth: _selectedMonth,
                expenses: expenseProvider.expenses,
                incomeHistory: incomeProvider.allIncomeHistory,
                onMonthSelected: _selectMonth,
              ),
              MonthlyView(selectedMonth: _selectedMonth),
            ],
          ),
        ),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !kIsWeb,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_rounded),
              SizedBox(width: 10),
              Text('Expense Tracker'),
            ],
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: _openSettings,
            ),
          ],
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: 0,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: _handleDesktopDestination,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: Text('Income'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: Text('Report'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  selectedIcon: Icon(Icons.account_balance_rounded),
                  label: Text('Accounts'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Settings'),
                ),
              ],
            ),
            VerticalDivider(width: 1, color: theme.dividerColor),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = constraints.maxWidth > 1120
                      ? 1120.0
                      : constraints.maxWidth;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      height: constraints.maxHeight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: dashboardBody,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          onPressed: _openAddExpense,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add expense'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !kIsWeb,
        title: const Text('Expense Tracker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: dashboardBody,
      floatingActionButton: FloatingActionButton(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: _openAddExpense,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
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
                    onTap: _openIncome,
                  ),
                  const SizedBox(width: 48),
                  _buildBottomBarItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Report',
                    onTap: _openReport,
                  ),
                  _buildBottomBarItem(
                    icon: Icons.account_balance_outlined,
                    label: 'Accounts',
                    onTap: _openAccounts,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDashboardShell({
    required ExpenseProvider expenseProvider,
    required IncomeProvider incomeProvider,
    required double carryForward,
    required double income,
    required double spent,
    required double accountsTotal,
  }) {
    final theme = Theme.of(context);
    final currentBalance = carryForward + income - spent;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return WebDashboardShell(
      selectedRoute: AppRoutes.homeRouteForTab(_tabController.index),
      title: 'Dashboard',
      subtitle: 'Expense Tracker · $monthLabel',
      maxContentWidth: 1280,
      actions: [
        FilledButton.icon(
          onPressed: _openAddExpense,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add expense'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWebMonthBar(theme, currentBalance),
          const SizedBox(height: 14),
          _buildWebMetricsGrid(
            carryForward: carryForward,
            income: income,
            spent: spent,
            accountsTotal: accountsTotal,
          ),
          const SizedBox(height: 14),
          _buildWebActivityPanel(
            expenseProvider: expenseProvider,
            incomeProvider: incomeProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildWebMonthBar(ThemeData theme, double currentBalance) {
    final scheme = theme.colorScheme;
    final balanceColor =
        currentBalance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _monthNavButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => _changeMonth(-1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isCurrentMonth ? 'Current month' : 'Historical month',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Current balance',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹ ${formatRupeesTwoDecimalsFromDouble(currentBalance)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: balanceColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _monthNavButton(
            icon: Icons.chevron_right_rounded,
            onTap: _isCurrentMonth ? null : () => _changeMonth(1),
            disabled: _isCurrentMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildWebMetricsGrid({
    required double carryForward,
    required double income,
    required double spent,
    required double accountsTotal,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isRoomy = constraints.maxWidth >= 760;
        final cardWidth = isRoomy
            ? (constraints.maxWidth - 30) / 4
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: cardWidth,
              child: _DashboardMetricCard(
                label: 'Income',
                value: income,
                icon: Icons.south_west_rounded,
                accent: const Color(0xFF2563EB),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _DashboardMetricCard(
                label: 'Expense',
                value: spent,
                icon: Icons.north_east_rounded,
                accent: const Color(0xFFDC2626),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _DashboardMetricCard(
                label: 'Accounts',
                value: accountsTotal,
                icon: Icons.account_balance_wallet_rounded,
                accent: accountsTotal >= 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _DashboardMetricCard(
                label: 'Carry forward',
                value: carryForward,
                icon: Icons.swap_horiz_rounded,
                accent: carryForward >= 0
                    ? const Color(0xFF0D9488)
                    : const Color(0xFFEA580C),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWebActivityPanel({
    required ExpenseProvider expenseProvider,
    required IncomeProvider incomeProvider,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final monthExpenses =
        expenseProvider.expenses.where((e) => e.date.startsWith(_monthPrefix));
    final monthIncome = incomeProvider.allIncomeHistory
        .where((e) => _incomeEntryCalendarDateKey(e).startsWith(_monthPrefix));
    final activityCount = monthExpenses.length + monthIncome.length;
    final dailyDateKeys =
        _dailyActivityDateKeys(expenseProvider, incomeProvider);
    final allDailyCollapsed = dailyDateKeys.isNotEmpty &&
        dailyDateKeys.every(_collapsedDates.contains);
    final isCalendarTab = _tabController.index == 1;
    final showBulkCollapse =
        _tabController.index == 0 && dailyDateKeys.isNotEmpty;

    final panel = Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$activityCount entries this month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showBulkCollapse) ...[
                  Tooltip(
                    message: allDailyCollapsed
                        ? 'Expand all dates'
                        : 'Collapse all dates',
                    child: IconButton.filledTonal(
                      onPressed: () => _toggleAllDailySections(dailyDateKeys),
                      icon: Icon(
                        allDailyCollapsed
                            ? Icons.unfold_more_rounded
                            : Icons.unfold_less_rounded,
                      ),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(40, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 268,
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    onTap: _onTabTapped,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: scheme.onPrimary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    indicator: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tabs: const [
                      Tab(text: 'Daily'),
                      Tab(text: 'Calendar'),
                      Tab(text: 'Monthly'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.6)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildDailyTab(
                  expenseProvider,
                  incomeProvider,
                  webMode: true,
                ),
                CalendarView(
                  selectedMonth: _selectedMonth,
                  expenses: expenseProvider.expenses,
                  incomeHistory: incomeProvider.allIncomeHistory,
                  onMonthSelected: _selectMonth,
                ),
                MonthlyView(selectedMonth: _selectedMonth),
              ],
            ),
          ),
        ],
      ),
    );

    if (!isCalendarTab) {
      return Expanded(child: panel);
    }

    return Flexible(
      fit: FlexFit.loose,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.clamp(0.0, 720.0);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: height,
              child: panel,
            ),
          );
        },
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
    ExpenseProvider expenseProvider,
    IncomeProvider incomeProvider, {
    bool webMode = false,
  }) {
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
      if (webMode) {
        return Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 30,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No activity yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add your first expense or record income for this month.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _openAddExpense,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add expense'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openIncome,
                      icon: const Icon(Icons.account_balance_wallet_outlined,
                          size: 18),
                      label: const Text('Add income'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }

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
      padding: webMode
          ? const EdgeInsets.fromLTRB(20, 10, 20, 88)
          : const EdgeInsets.fromLTRB(16, 8, 16, 24),
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

class _DashboardMetricCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color accent;

  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '₹${formatRupeesTwoDecimalsFromDouble(value)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
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
              color: theme.colorScheme.onSurfaceVariant,
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
                              color: theme.colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
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
              color: theme.colorScheme.onSurfaceVariant,
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
