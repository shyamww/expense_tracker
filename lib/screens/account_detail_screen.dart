import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/reporting_category_names.dart';
import '../core/money.dart';
import '../db/database_helper.dart';
import '../models/account_ledger_day.dart';
import '../models/expense.dart';
import '../models/income_entry.dart';
import '../providers/account_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../widgets/expense_tile.dart';
import '../widgets/income_history_tile.dart';
import '../widgets/expense_action_sheet.dart';
import '../widgets/income_action_sheet.dart';

/// Per-account monthly ledger: day-wise income + expenses, carry forward, totals.
class AccountDetailScreen extends StatefulWidget {
  final String accountName;

  const AccountDetailScreen({super.key, required this.accountName});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late DateTime _selectedMonth;
  AccountMonthLedger? _ledger;
  bool _loading = true;
  final Set<String> _collapsedDates = {};
  int? _selectedExpenseId;
  int? _selectedIncomeEntryId;

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _loading = true);
    final ledger = await DatabaseHelper()
        .getAccountMonthLedger(widget.accountName, _monthKey);
    if (mounted) {
      setState(() {
        _ledger = ledger;
        _loading = false;
      });
    }
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
    setState(() => _selectedMonth = clamped);
    await _loadLedger();
  }

  Future<void> _changeMonth(int delta) => _selectMonth(
        DateTime(_selectedMonth.year, _selectedMonth.month + delta),
      );

  Future<void> _afterIncomeMutation() async {
    if (!mounted) return;
    final incomeProv = context.read<IncomeProvider>();
    final accountProv = context.read<AccountProvider>();
    await incomeProv.loadIncomeForMonth(_monthKey);
    await accountProv.refresh();
    await _loadLedger();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  Future<void> _onIncomeHistoryLongPress(
      BuildContext context, IncomeEntry entry) async {
    if (entry.id == null) return;
    setState(() {
      _selectedIncomeEntryId = entry.id;
      _selectedExpenseId = null;
    });
    await showIncomeHistoryActionsSheet(
      context: context,
      entry: entry,
      onModify: _showEditIncomeEntry,
      onRefresh: _afterIncomeMutation,
      onClosed: () {
        if (mounted) setState(() => _selectedIncomeEntryId = null);
      },
    );
  }

  Future<void> _showEditIncomeEntry(IncomeEntry entry) async {
    if (entry.id == null) return;
    final incomeProv = context.read<IncomeProvider>();
    final accountProv = context.read<AccountProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final fixedAccount = widget.accountName;
    final amountCtrl = TextEditingController(
      text: amountFieldTextFromPaisa(entry.amount),
    );
    final noteCtrl = TextEditingController(text: entry.note);
    var pickedDate = DateTime.tryParse(entry.createdAt) ?? DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit income',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Account',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fixedAccount,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_today,
                          color: scheme.onSurfaceVariant),
                      title:
                          Text(DateFormat('dd MMMM yyyy').format(pickedDate)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: pickedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setModalState(() => pickedDate = d);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final paisa =
                            paisaFromRupeeString(amountCtrl.text.trim());
                        if (paisa <= 0) {
                          _showError('Please enter a valid amount');
                          return;
                        }
                        final month = DateFormat('yyyy-MM').format(pickedDate);
                        final updated = IncomeEntry(
                          id: entry.id,
                          amount: paisa,
                          month: month,
                          account: fixedAccount,
                          note: noteCtrl.text.trim(),
                          createdAt: pickedDate.toIso8601String(),
                        );
                        await DatabaseHelper()
                            .updateIncomeHistoryEntry(updated);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (!mounted) return;
                        await incomeProv.loadIncomeForMonth(_monthKey);
                        await accountProv.refresh();
                        await _loadLedger();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Income updated'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('Save changes'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _onExpenseLongPress(
      BuildContext context, Expense expense) async {
    if (expense.id == null) return;
    setState(() {
      _selectedExpenseId = expense.id;
      _selectedIncomeEntryId = null;
    });
    await showExpenseActionsBottomSheet(
      context: context,
      expense: expense,
      lockAccountTo: widget.accountName,
      onClosed: () async {
        if (!mounted) return;
        final expenseProv = context.read<ExpenseProvider>();
        final accountProv = context.read<AccountProvider>();
        setState(() => _selectedExpenseId = null);
        await expenseProv.loadExpenses();
        await accountProv.refresh();
        await _loadLedger();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ledger = _ledger;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountName),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _MonthStrip(
              selectedMonth: _selectedMonth,
              isCurrentMonth: _isCurrentMonth,
              onPrev: () => _changeMonth(-1),
              onNext: _isCurrentMonth ? null : () => _changeMonth(1),
              theme: theme,
            ),
          ),
          if (ledger != null && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _AccountSummaryStrip(ledger: ledger),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ledger == null || ledger.days.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 52, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 10),
                            Text(
                              'No activity this month',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Income or expenses on this account will show here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: ledger.days.length,
                        itemBuilder: (context, index) {
                          final day = ledger.days[index];
                          return _AccountDaySection(
                            day: day,
                            collapsed: _collapsedDates.contains(day.date),
                            selectedExpenseId: _selectedExpenseId,
                            selectedIncomeEntryId: _selectedIncomeEntryId,
                            onToggleCollapse: () {
                              setState(() {
                                if (_collapsedDates.contains(day.date)) {
                                  _collapsedDates.remove(day.date);
                                } else {
                                  _collapsedDates.add(day.date);
                                }
                              });
                            },
                            onExpenseLongPress: (e) =>
                                _onExpenseLongPress(context, e),
                            onDeselect: () =>
                                setState(() => _selectedExpenseId = null),
                            onIncomeLongPress: (e) =>
                                _onIncomeHistoryLongPress(context, e),
                            onIncomeDeselect: () =>
                                setState(() => _selectedIncomeEntryId = null),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MonthStrip extends StatelessWidget {
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final ThemeData theme;

  const _MonthStrip({
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final monthStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      letterSpacing: -0.3,
    );
    final btnStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(36, 34),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            style: btnStyle,
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: onPrev,
          ),
          Text(
            DateFormat('MMMM yyyy').format(selectedMonth),
            style: monthStyle,
          ),
          IconButton(
            style: btnStyle,
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: isCurrentMonth ? scheme.outlineVariant : null,
            ),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _AccountSummaryStrip extends StatelessWidget {
  final AccountMonthLedger ledger;

  const _AccountSummaryStrip({required this.ledger});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bal = ledger.balance;
    final balColor =
        bal >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  context,
                  'Carry forward',
                  ledger.carryForward,
                  const Color(0xFF0D9488),
                ),
              ),
              Expanded(
                child: _miniStat(
                  context,
                  'Income',
                  ledger.monthIncome,
                  const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  context,
                  'Expense',
                  ledger.monthSpent,
                  const Color(0xFFDC2626),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${formatRupeesTwoDecimalsFromDouble(bal)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: balColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    String label,
    double value,
    Color accent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '₹${formatRupeesTwoDecimalsFromDouble(value)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _AccountDaySection extends StatelessWidget {
  final AccountLedgerDay day;
  final bool collapsed;
  final int? selectedExpenseId;
  final int? selectedIncomeEntryId;
  final VoidCallback onToggleCollapse;
  final void Function(Expense) onExpenseLongPress;
  final VoidCallback onDeselect;
  final void Function(IncomeEntry) onIncomeLongPress;
  final VoidCallback onIncomeDeselect;

  const _AccountDaySection({
    required this.day,
    required this.collapsed,
    required this.selectedExpenseId,
    required this.selectedIncomeEntryId,
    required this.onToggleCollapse,
    required this.onExpenseLongPress,
    required this.onDeselect,
    required this.onIncomeLongPress,
    required this.onIncomeDeselect,
  });

  bool isSpending(String category) {
    return ReportingCategoryNames.countsAsSpendingInReports(category) ||
        category == ReportingCategoryNames.transferOut;
  }

  bool isReceived(String category) {
    return ReportingCategoryNames.countsAsExternalReceived(category) ||
        category == ReportingCategoryNames.transferIn;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = DateTime.tryParse(day.date);
    final displayDate =
        date != null ? DateFormat('dd MMM, EEEE').format(date) : day.date;

    bool isAccountExpense(String c) {
      return ReportingCategoryNames.countsAsSpendingInReports(c) ||
          c == ReportingCategoryNames.transferOut;
    }

    bool isAccountIncome(String c) {
      return ReportingCategoryNames.countsAsExternalReceived(c) ||
          c == ReportingCategoryNames.transferIn;
    }

    final spentPaisa = day.expenses
        .where((e) => isAccountExpense(e.category))
        .fold<int>(0, (s, e) => s + e.amount);

    final receivedPaisa = day.expenses
            .where((e) => isAccountIncome(e.category))
            .fold<int>(0, (s, e) => s + e.amount) +
        day.incomeEntries.fold<int>(0, (s, e) => s + e.amount);

    final daySpent = rupeesFromPaisa(spentPaisa);
    final dayReceived = rupeesFromPaisa(receivedPaisa);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggleCollapse,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  displayDate,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (daySpent > 0)
                  Text(
                    '₹${formatRupeesTwoDecimalsFromDouble(daySpent)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade500,
                    ),
                  ),
                if (daySpent > 0 && dayReceived > 0) const SizedBox(width: 8),
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
                  '(${day.itemCount})',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...[
          ...day.expenses.map(
            (expense) => ExpenseTile(
              expense: expense,
              isSelected: selectedExpenseId == expense.id,
              onDeselect: onDeselect,
              onLongPress:
                  expense.id == null ? null : () => onExpenseLongPress(expense),
            ),
          ),
          ...day.incomeEntries.map((entry) {
            final dt = DateTime.tryParse(entry.createdAt);
            final dateStr =
                dt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : '';
            return IncomeHistoryTile(
              entry: entry,
              dateStr: dateStr,
              isSelected: selectedIncomeEntryId == entry.id,
              onDeselect: onIncomeDeselect,
              onLongPress:
                  entry.id == null ? null : () => onIncomeLongPress(entry),
            );
          }),
          Divider(height: 1, color: theme.dividerColor),
        ],
      ],
    );
  }
}
