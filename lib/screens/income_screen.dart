import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/income_provider.dart';
import '../providers/account_provider.dart';
import '../db/database_helper.dart';
import '../models/income_entry.dart';
import '../widgets/income_history_tile.dart';
import '../widgets/income_action_sheet.dart';
import '../widgets/account_chip.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late String _currentMonth;
  late DateTime _selectedDate;
  double _currentTotal = 0;
  double _carryForward = 0;
  List<IncomeEntry> _history = [];
  int? _selectedIncomeEntryId;
  String? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      if (!mounted) return;
      final ap = context.read<AccountProvider>();
      await ap.refresh();
      if (!mounted) return;
      if (_selectedAccount == null && ap.accounts.isNotEmpty) {
        setState(() => _selectedAccount = ap.accounts.first.name);
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final provider = context.read<IncomeProvider>();
    await provider.loadIncomeForMonth(_currentMonth);
    final history = await DatabaseHelper().getIncomeHistoryForMonth(_currentMonth);
    final carry = await DatabaseHelper().getCarryForwardForMonth(_currentMonth);
    if (!mounted) return;
    await context.read<AccountProvider>().refresh();
    if (mounted) {
      setState(() {
        _currentTotal = provider.monthlyIncome;
        _carryForward = carry;
        _history = history;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool get _canGoIncomeHistoryPrev {
    final cur = DateTime.tryParse('$_currentMonth-01');
    if (cur == null) return false;
    final prev = DateTime(cur.year, cur.month - 1);
    return !prev.isBefore(DateTime(2020, 1));
  }

  bool get _canGoIncomeHistoryNext {
    final cur = DateTime.tryParse('$_currentMonth-01');
    if (cur == null) return false;
    final latest = DateTime(DateTime.now().year, DateTime.now().month);
    return cur.isBefore(latest);
  }

  Future<void> _changeIncomeHistoryMonth(int delta) async {
    final cur = DateTime.tryParse('$_currentMonth-01');
    if (cur == null) return;
    final next = DateTime(cur.year, cur.month + delta);
    final latest = DateTime(DateTime.now().year, DateTime.now().month);
    if (next.isAfter(latest)) return;
    if (next.isBefore(DateTime(2020, 1))) return;
    setState(() => _currentMonth = DateFormat('yyyy-MM').format(next));
    await _loadData();
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter an amount to add');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (_selectedAccount == null || _selectedAccount!.isEmpty) {
      _showError('Please select an account');
      return;
    }

    final note = _noteController.text.trim();
    final month = DateFormat('yyyy-MM').format(_selectedDate);
    await context.read<IncomeProvider>().setIncome(
      amount,
      month,
      note: note,
      date: _selectedDate,
      account: _selectedAccount!,
    );

    _amountController.clear();
    _noteController.clear();
    setState(() {
      _currentMonth = month;
      _selectedDate = DateTime.now();
    });
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('₹ ${amount.toStringAsFixed(2)} added to $month income!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade400,
        ),
      );
    }
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

  Future<void> _onIncomeHistoryLongPress(BuildContext context, IncomeEntry entry) async {
    if (entry.id == null) return;
    setState(() => _selectedIncomeEntryId = entry.id);
    await showIncomeHistoryActionsSheet(
      context: context,
      entry: entry,
      onModify: (e) => _showEditIncomeEntry(e),
      onRefresh: _loadData,
      onClosed: () {
        if (mounted) setState(() => _selectedIncomeEntryId = null);
      },
    );
  }

  Future<void> _showEditIncomeEntry(IncomeEntry entry) async {
    if (entry.id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final amountCtrl = TextEditingController(
      text: (entry.amount % 1 == 0)
          ? entry.amount.toStringAsFixed(0)
          : entry.amount.toString(),
    );
    final noteCtrl = TextEditingController(text: entry.note);
    var pickedDate = DateTime.tryParse(entry.createdAt) ?? DateTime.now();
    var editAccount = entry.account.isNotEmpty
        ? entry.account
        : (context.read<AccountProvider>().accounts.isNotEmpty
            ? context.read<AccountProvider>().accounts.first.name
            : '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Consumer<AccountProvider>(
                builder: (context, ap, _) {
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        if (ap.accounts.isNotEmpty) ...[
                          Text(
                            'Account',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ap.accounts.map((a) {
                              return AccountChip(
                                name: a.name,
                                selected: editAccount == a.name,
                                onTap: () => setModalState(() => editAccount = a.name),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.calendar_today, color: Colors.grey.shade700),
                          title: Text(DateFormat('dd MMMM yyyy').format(pickedDate)),
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
                            final amount = double.tryParse(amountCtrl.text.trim());
                            if (amount == null || amount <= 0) {
                              _showError('Please enter a valid amount');
                              return;
                            }
                            if (editAccount.isEmpty) {
                              _showError('Please select an account');
                              return;
                            }
                            final month = DateFormat('yyyy-MM').format(pickedDate);
                            final updated = IncomeEntry(
                              id: entry.id,
                              amount: amount,
                              month: month,
                              account: editAccount,
                              note: noteCtrl.text.trim(),
                              createdAt: pickedDate.toIso8601String(),
                            );
                            await DatabaseHelper().updateIncomeHistoryEntry(updated);
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                            if (!mounted) return;
                            setState(() => _currentMonth = month);
                            await _loadData();
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
              );
            },
          ),
        );
      },
    );

    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthAnchor =
        DateTime.tryParse('$_currentMonth-01') ?? DateTime.now();
    final displayMonth = DateFormat('MMMM yyyy').format(monthAnchor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
        centerTitle: true,
      ),
      resizeToAvoidBottomInset: true,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet,
                                color: Colors.green.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayMonth,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    '₹ ${_currentTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Added',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (_carryForward != 0) ...[
                          Divider(color: Colors.green.shade200, height: 20),
                          Row(
                            children: [
                              Icon(
                                _carryForward >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: _carryForward >= 0
                                    ? Colors.teal.shade600
                                    : Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Carry forward from previous month',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              Text(
                                '₹ ${_carryForward.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _carryForward >= 0
                                      ? Colors.teal.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      hintText: '0.00',
                      labelText: 'Amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<AccountProvider>(
                    builder: (context, ap, _) {
                      if (ap.accounts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Add an account in Settings → Accounts.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ap.accounts.map((a) {
                          return AccountChip(
                            name: a.name,
                            selected: _selectedAccount == a.name,
                            onTap: () => setState(() => _selectedAccount = a.name),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'e.g., Salary, Freelance, Bonus',
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 15),
                          ),
                          const Spacer(),
                          Icon(Icons.edit_calendar, size: 18, color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Add Income',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _canGoIncomeHistoryPrev
                              ? () => _changeIncomeHistoryMonth(-1)
                              : null,
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            size: 22,
                            color: _canGoIncomeHistoryPrev
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                          tooltip: 'Earlier month',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            DateFormat('MMM yyyy').format(
                              DateTime.tryParse('$_currentMonth-01') ??
                                  DateTime.now(),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _canGoIncomeHistoryNext
                              ? () => _changeIncomeHistoryMonth(1)
                              : null,
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                            color: _canGoIncomeHistoryNext
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                          tooltip: 'Later month',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    'History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_history.length} entries)',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (_history.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No income added yet',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = _history[index];
                    final date = DateTime.tryParse(entry.createdAt);
                    final dateStr = date != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(date)
                        : '';
                    return IncomeHistoryTile(
                      entry: entry,
                      dateStr: dateStr,
                      isSelected: _selectedIncomeEntryId == entry.id,
                      onDeselect: () => setState(() => _selectedIncomeEntryId = null),
                      onLongPress: entry.id == null
                          ? null
                          : () => _onIncomeHistoryLongPress(context, entry),
                    );
                  },
                  childCount: _history.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
