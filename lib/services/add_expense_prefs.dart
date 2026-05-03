import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last category/account (or transfer accounts) used on the add-expense form
/// so reopening the screen — including after an app restart — restores selections.
class AddExpensePrefs {
  AddExpensePrefs._();

  static const _kCategory = 'add_expense_last_category';
  static const _kAccount = 'add_expense_last_account';
  static const _kTransferMode = 'add_expense_last_transfer_mode';
  static const _kTransferFrom = 'add_expense_last_transfer_from';
  static const _kTransferTo = 'add_expense_last_transfer_to';

  static Future<RememberedAddExpenseForm> load() async {
    final p = await SharedPreferences.getInstance();
    return RememberedAddExpenseForm(
      transferMode: p.getBool(_kTransferMode) ?? false,
      category: p.getString(_kCategory),
      account: p.getString(_kAccount),
      transferFrom: p.getString(_kTransferFrom),
      transferTo: p.getString(_kTransferTo),
    );
  }

  static Future<void> saveExpenseSelection({
    required String category,
    required String account,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTransferMode, false);
    await p.setString(_kCategory, category);
    await p.setString(_kAccount, account);
  }

  static Future<void> saveTransferSelection({
    required String fromAccount,
    required String toAccount,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTransferMode, true);
    await p.setString(_kTransferFrom, fromAccount);
    await p.setString(_kTransferTo, toAccount);
  }
}

class RememberedAddExpenseForm {
  const RememberedAddExpenseForm({
    required this.transferMode,
    this.category,
    this.account,
    this.transferFrom,
    this.transferTo,
  });

  final bool transferMode;
  final String? category;
  final String? account;
  final String? transferFrom;
  final String? transferTo;
}
