import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/category_chip.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expenseToEdit;

  const AddExpenseScreen({super.key, this.expenseToEdit});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedCategory;
  late DateTime _selectedDateTime;

  bool get _isEditing => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expenseToEdit;
    if (e != null) {
      _amountController.text = (e.amount % 1 == 0)
          ? e.amount.toStringAsFixed(0)
          : e.amount.toString();
      _noteController.text = e.note;
      _selectedCategory = e.category;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cp = context.read<CategoryProvider>();
      if (cp.categories.isEmpty) cp.loadCategories();
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

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (_selectedCategory == null) {
      _showError('Please select a category');
      return;
    }

    var when = _selectedDateTime;
    final now = DateTime.now();
    if (when.isAfter(now)) when = now;

    final expense = Expense(
      id: widget.expenseToEdit?.id,
      amount: amount,
      category: _selectedCategory!,
      note: _noteController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(when),
      createdAt: when.toIso8601String(),
    );

    final provider = context.read<ExpenseProvider>();
    if (_isEditing) {
      await provider.updateExpense(expense);
    } else {
      await provider.addExpense(expense);
    }

    if (mounted) Navigator.pop(context);
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
            // Amount Field
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

            // Category Selector
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
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cat.categories.map((c) {
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

            // Date & time
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

            // Note Field
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
                hintText: 'e.g., Lunch with friends',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
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
                  _isEditing ? 'Save changes' : 'Save Expense',
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
