import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../widgets/category_chip.dart';
import '../widgets/account_chip.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expenseToEdit;

  /// When set, the expense stays on this account (no account picker). Used when editing from an account ledger.
  final String? lockAccountTo;

  const AddExpenseScreen({super.key, this.expenseToEdit, this.lockAccountTo});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedCategory;
  String? _selectedAccount;
  late DateTime _selectedDateTime;
  bool _transferMode = false;
  String? _transferFrom;
  String? _transferTo;

  bool get _isEditing => widget.expenseToEdit != null;

  bool get _accountLocked {
    final a = widget.lockAccountTo?.trim();
    return a != null && a.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.expenseToEdit;
    if (e != null) {
      _amountController.text = amountFieldTextFromPaisa(e.amount);
      _noteController.text = e.note;
      _selectedCategory = e.category;
      if (_accountLocked) {
        _selectedAccount = widget.lockAccountTo!.trim();
      } else {
        _selectedAccount = e.account.isNotEmpty ? e.account : null;
      }
      final fromCreated = DateTime.tryParse(e.createdAt);
      if (fromCreated != null &&
          DateFormat('yyyy-MM-dd').format(fromCreated) == e.date) {
        _selectedDateTime = fromCreated;
      } else {
        final d = DateTime.tryParse(e.date);
        _selectedDateTime = d != null
            ? DateTime(d.year, d.month, d.day, 12, 0)
            : DateTime.now();
      }
    } else {
      _selectedDateTime = DateTime.now();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cp = context.read<CategoryProvider>();
      if (cp.categories.isEmpty) await cp.loadCategories();
      if (!mounted) return;
      final ap = context.read<AccountProvider>();
      await ap.refresh();
      if (!mounted) return;
      if (!_accountLocked && _selectedAccount == null && ap.accounts.isNotEmpty) {
        setState(() => _selectedAccount = ap.accounts.first.name);
      }
    });
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
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amountPaisa = paisaFromRupeeString(amountText);
    if (amountPaisa <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    var when = _selectedDateTime;
    final now = DateTime.now();
    if (when.isAfter(now)) when = now;

    final provider = context.read<ExpenseProvider>();
    final accountProvider = context.read<AccountProvider>();

    if (!_isEditing && _transferMode && !_accountLocked) {
      final from = _transferFrom;
      final to = _transferTo;
      if (from == null ||
          to == null ||
          from.isEmpty ||
          to.isEmpty ||
          from == to) {
        _showError('Choose two different accounts');
        return;
      }
      await provider.addInternalTransfer(
        amountPaisa: amountPaisa,
        fromAccount: from,
        toAccount: to,
        dateYmd: DateFormat('yyyy-MM-dd').format(when),
        createdAtIso: when.toIso8601String(),
        userNote: _noteController.text.trim(),
      );
      if (!mounted) return;
      await accountProvider.refresh();
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    if (_selectedCategory == null) {
      _showError('Please select a category');
      return;
    }

    final accountName = _accountLocked
        ? widget.lockAccountTo!.trim()
        : _selectedAccount;
    if (accountName == null || accountName.isEmpty) {
      _showError('Please select an account');
      return;
    }

    final expense = Expense(
      id: widget.expenseToEdit?.id,
      amount: amountPaisa,
      category: _selectedCategory!,
      account: accountName,
      note: _noteController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(when),
      createdAt: when.toIso8601String(),
    );

    if (_isEditing) {
      await provider.updateExpense(expense);
    } else {
      await provider.addExpense(expense);
    }

    if (!mounted) return;
    await accountProvider.refresh();
    if (!mounted) return;
    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    if (_isEditing &&
        widget.expenseToEdit != null &&
        CategoryProvider.isTransferCategory(widget.expenseToEdit!.category)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Transfer'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Transfers cannot be edited. Delete the entry from your list — '
                'both the sending and receiving sides are removed together.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit expense' : 'Add Expense'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),

            const SizedBox(height: 24),

            if (!_transferMode) ...[
              Text(
                'Category',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Consumer<CategoryProvider>(
                builder: (context, cat, _) {
                  if (cat.categories.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Loading categories…',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }
                  final visible = cat.categories
                      .where((c) => !CategoryProvider.isTransferCategory(c.name))
                      .toList();
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: visible.map((c) {
                      final info = c.toCategoryInfo();
                      return CategoryChip(
                        category: info,
                        selected: _selectedCategory == c.name,
                        onTap: () => setState(() => _selectedCategory = c.name),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Text(
                  'Moving money between your own accounts. '
                  'This does not count as income or expense in reports.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_accountLocked) ...[
              Text(
                'Account',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.lockAccountTo!.trim(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              Text(
                'Account',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Consumer<AccountProvider>(
                builder: (context, ap, _) {
                  if (ap.accounts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Add an account in Settings → Accounts.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    );
                  }
                  if (ap.accounts.length < 2) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add at least two accounts to use To Self transfers.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: ap.accounts.map((a) {
                            return AccountChip(
                              name: a.name,
                              selected: _selectedAccount == a.name,
                              onTap: () => setState(() {
                                _transferMode = false;
                                _selectedAccount = a.name;
                              }),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          AccountChip(
                            name: 'To Self',
                            selected: _transferMode,
                            onTap: () {
                              setState(() {
                                _transferMode = true;
                                _selectedAccount = null;
                                _transferFrom = ap.accounts[0].name;
                                _transferTo = ap.accounts[1].name;
                              });
                            },
                          ),
                          ...ap.accounts.map((a) {
                            return AccountChip(
                              name: a.name,
                              selected: !_transferMode && _selectedAccount == a.name,
                              onTap: () => setState(() {
                                _transferMode = false;
                                _selectedAccount = a.name;
                              }),
                            );
                          }),
                        ],
                      ),
                      if (_transferMode) ...[
                        const SizedBox(height: 18),
                        Text(
                          'From account',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: ap.accounts.map((a) {
                            return AccountChip(
                              name: a.name,
                              selected: _transferFrom == a.name,
                              onTap: () => setState(() {
                                _transferFrom = a.name;
                                if (_transferTo == a.name) {
                                  _transferTo = ap.accounts
                                      .firstWhere((x) => x.name != a.name)
                                      .name;
                                }
                              }),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'To account',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: ap.accounts.map((a) {
                            final disabled = a.name == _transferFrom;
                            return Opacity(
                              opacity: disabled ? 0.4 : 1,
                              child: AccountChip(
                                name: a.name,
                                selected: _transferTo == a.name,
                                onTap: disabled
                                    ? () {}
                                    : () => setState(() => _transferTo = a.name),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            Text(
              'Date & time',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('dd MMMM yyyy').format(_selectedDateTime),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('hh:mm a').format(_selectedDateTime),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Note (optional)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _transferMode
                    ? 'e.g., Move to savings'
                    : 'e.g., Lunch with friends',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _isEditing
                      ? 'Save changes'
                      : _transferMode
                          ? 'Save transfer'
                          : 'Save Expense',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
