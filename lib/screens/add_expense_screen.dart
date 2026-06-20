import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../services/add_expense_prefs.dart';

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

      if (_isEditing) return;

      final remembered = await AddExpensePrefs.load();
      if (!mounted) return;

      final accountNames = ap.accounts.map((a) => a.name).toSet();
      final categoryNames = cp.categories
          .where((c) => !CategoryProvider.isTransferCategory(c.name))
          .map((c) => c.name)
          .toSet();

      setState(() {
        if (remembered.transferMode &&
            accountNames.length >= 2 &&
            remembered.transferFrom != null &&
            remembered.transferTo != null &&
            accountNames.contains(remembered.transferFrom) &&
            accountNames.contains(remembered.transferTo) &&
            remembered.transferFrom != remembered.transferTo) {
          _transferMode = true;
          _transferFrom = remembered.transferFrom;
          _transferTo = remembered.transferTo;
          _selectedAccount = null;
        } else {
          final cat = remembered.category;
          if (cat != null && categoryNames.contains(cat)) {
            _selectedCategory = cat;
          }
          if (!_accountLocked) {
            final acc = remembered.account;
            if (acc != null && accountNames.contains(acc)) {
              _selectedAccount = acc;
            }
          }
        }
      });
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
      if (!_isEditing) {
        await AddExpensePrefs.saveTransferSelection(
          fromAccount: from,
          toAccount: to,
        );
      }
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

    final accountName =
        _accountLocked ? widget.lockAccountTo!.trim() : _selectedAccount;
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
      await AddExpensePrefs.saveExpenseSelection(
        category: _selectedCategory!,
        account: accountName,
      );
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

  bool get _useWebLayout {
    if (!kIsWeb) return false;
    final size = MediaQuery.maybeSizeOf(context);
    return size != null && size.width >= 720;
  }

  String get _saveLabel {
    if (_isEditing) return 'Save changes';
    return _transferMode ? 'Save transfer' : 'Save Expense';
  }

  String get _amountPreview {
    final paisa = paisaFromRupeeString(_amountController.text);
    if (paisa <= 0) return '0.00';
    return formatRupeesFixed2FromPaisa(paisa);
  }

  Widget _buildWebExpenseScaffold() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Edit Expense' : 'Add Expense',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _transferMode
                                  ? 'Move money between your own accounts'
                                  : 'Record spending with category, account, date, and note',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(_saveLabel),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final twoColumn = constraints.maxWidth >= 980;
                          final form = _buildWebFormPanel();
                          final summary = _buildWebSummaryPanel();
                          if (!twoColumn) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                form,
                                const SizedBox(height: 16),
                                summary,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: form),
                              const SizedBox(width: 18),
                              SizedBox(width: 340, child: summary),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebFormPanel() {
    return _buildWebPanel(
      icon: Icons.receipt_long_rounded,
      title: 'Expense details',
      subtitle: 'Keep the fields compact and review everything before saving.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final inline = constraints.maxWidth >= 680;
              final amount = _buildWebTextField(
                label: 'Amount',
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    hintText: '0.00',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              );
              final note = _buildWebTextField(
                label: 'Note',
                child: TextField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _transferMode
                        ? 'e.g., Move to savings'
                        : 'e.g., Lunch with friends',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              );
              if (!inline) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    amount,
                    const SizedBox(height: 14),
                    note,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 250, child: amount),
                  const SizedBox(width: 14),
                  Expanded(child: note),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _buildWebDateTimeSection(),
          const SizedBox(height: 18),
          if (!_transferMode) ...[
            _buildWebCategorySection(),
            const SizedBox(height: 18),
          ] else ...[
            _buildWebTransferNotice(),
            const SizedBox(height: 18),
          ],
          _buildWebAccountSection(),
        ],
      ),
    );
  }

  Widget _buildWebPanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildWebTextField({
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildWebDateTimeSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date & time',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final inline = constraints.maxWidth >= 560;
            final date = _buildWebDateTimeTile(
              icon: Icons.calendar_month_rounded,
              label: 'Date',
              value: DateFormat('EEE, dd MMM yyyy').format(_selectedDateTime),
              onTap: _pickDate,
            );
            final time = _buildWebDateTimeTile(
              icon: Icons.schedule_rounded,
              label: 'Time',
              value: DateFormat('hh:mm a').format(_selectedDateTime),
              onTap: _pickTime,
            );
            if (!inline) {
              return Column(
                children: [
                  date,
                  const SizedBox(height: 10),
                  time,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: date),
                const SizedBox(width: 12),
                Expanded(child: time),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWebDateTimeTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebCategorySection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Consumer<CategoryProvider>(
          builder: (context, cat, _) {
            if (cat.categories.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Loading categories...',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            }
            final visible = cat.categories
                .where((c) => !CategoryProvider.isTransferCategory(c.name))
                .toList();
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visible.map((c) {
                final info = c.toCategoryInfo();
                return CategoryChip(
                  category: info,
                  compact: true,
                  selected: _selectedCategory == c.name,
                  onTap: () => setState(() => _selectedCategory = c.name),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWebTransferNotice() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Moving money between your own accounts. This does not count as income or expense in reports.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebAccountSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (_accountLocked)
          _buildLockedAccountTile()
        else
          Consumer<AccountProvider>(
            builder: (context, ap, _) {
              if (ap.accounts.isEmpty) {
                return Text(
                  'Add an account in Settings > Accounts.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                );
              }
              if (ap.accounts.length < 2) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add at least two accounts to use To Self transfers.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ap.accounts.map((a) {
                        return AccountChip(
                          name: a.name,
                          compact: true,
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
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AccountChip(
                        name: 'To Self',
                        compact: true,
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
                          compact: true,
                          selected:
                              !_transferMode && _selectedAccount == a.name,
                          onTap: () => setState(() {
                            _transferMode = false;
                            _selectedAccount = a.name;
                          }),
                        );
                      }),
                    ],
                  ),
                  if (_transferMode) ...[
                    const SizedBox(height: 16),
                    _buildTransferAccountChoices(ap),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildLockedAccountTile() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: scheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.lockAccountTo!.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferAccountChoices(AccountProvider ap) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'From account',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ap.accounts.map((a) {
            return AccountChip(
              name: a.name,
              compact: true,
              selected: _transferFrom == a.name,
              onTap: () => setState(() {
                _transferFrom = a.name;
                if (_transferTo == a.name) {
                  _transferTo =
                      ap.accounts.firstWhere((x) => x.name != a.name).name;
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text(
          'To account',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ap.accounts.map((a) {
            final disabled = a.name == _transferFrom;
            return Opacity(
              opacity: disabled ? 0.42 : 1,
              child: AccountChip(
                name: a.name,
                compact: true,
                selected: _transferTo == a.name,
                onTap: disabled
                    ? () {}
                    : () => setState(() => _transferTo = a.name),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWebSummaryPanel() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = _transferMode
        ? 'To Self transfer'
        : (_selectedCategory ?? 'Not selected');
    final account = _accountLocked
        ? widget.lockAccountTo!.trim()
        : _transferMode
            ? '${_transferFrom ?? '-'} -> ${_transferTo ?? '-'}'
            : (_selectedAccount ?? 'Not selected');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isEditing
                  ? 'Changes will update this entry.'
                  : 'Confirm the details before saving.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: scheme.primary.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹ $_amountPreview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildWebSummaryRow(Icons.category_rounded, 'Category', category),
            _buildWebSummaryRow(
                Icons.account_balance_rounded, 'Account', account),
            _buildWebSummaryRow(
              Icons.calendar_today_rounded,
              'Date',
              DateFormat('dd MMM yyyy').format(_selectedDateTime),
            ),
            _buildWebSummaryRow(
              Icons.schedule_rounded,
              'Time',
              DateFormat('hh:mm a').format(_selectedDateTime),
            ),
            if (_noteController.text.trim().isNotEmpty)
              _buildWebSummaryRow(
                Icons.notes_rounded,
                'Note',
                _noteController.text.trim(),
              ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_saveLabel),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSummaryRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    if (_useWebLayout) {
      return _buildWebExpenseScaffold();
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Note (optional)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Date & time',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // DATE
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy')
                                  .format(_selectedDateTime),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // TIME
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('hh:mm a').format(_selectedDateTime),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_transferMode) ...[
              Text(
                'Category',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
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
                      .where(
                          (c) => !CategoryProvider.isTransferCategory(c.name))
                      .toList();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: visible.map((c) {
                      final info = c.toCategoryInfo();
                      return CategoryChip(
                        category: info,
                        compact: true,
                        selected: _selectedCategory == c.name,
                        onTap: () => setState(() => _selectedCategory = c.name),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
            ] else ...[
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Add an account in Settings → Accounts.',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14),
                      ),
                    );
                  }
                  if (ap.accounts.length < 2) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add at least two accounts to use To Self transfers.',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ap.accounts.map((a) {
                            return AccountChip(
                              name: a.name,
                              compact: true,
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
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AccountChip(
                            name: 'To Self',
                            compact: true,
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
                              compact: true,
                              selected:
                                  !_transferMode && _selectedAccount == a.name,
                              onTap: () => setState(() {
                                _transferMode = false;
                                _selectedAccount = a.name;
                              }),
                            );
                          }),
                        ],
                      ),
                      if (_transferMode) ...[
                        const SizedBox(height: 12),
                        Text(
                          'From account',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ap.accounts.map((a) {
                            return AccountChip(
                              name: a.name,
                              compact: true,
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
                        const SizedBox(height: 10),
                        Text(
                          'To account',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ap.accounts.map((a) {
                            final disabled = a.name == _transferFrom;
                            return Opacity(
                              opacity: disabled ? 0.4 : 1,
                              child: AccountChip(
                                name: a.name,
                                compact: true,
                                selected: _transferTo == a.name,
                                onTap: disabled
                                    ? () {}
                                    : () =>
                                        setState(() => _transferTo = a.name),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 20),
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
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
