/// Pairs two expense rows for account-to-account transfers; used for paired delete.
String makeTransferNotePrefix() =>
    '__XFER_${DateTime.now().microsecondsSinceEpoch}__';

/// Returns the `__XFER_<id>__` prefix if [note] starts with one.
String? parseTransferNotePrefix(String note) {
  final m = RegExp(r'^(__XFER_\d+__)').firstMatch(note.trim());
  return m?.group(1);
}

bool expenseNoteHasTransferPrefix(String note) =>
    parseTransferNotePrefix(note) != null;

/// Hide `__XFER_…__` in lists and sheets; keeps `→ Account` / `← Account` text.
String displayExpenseNote(String note) {
  return note.replaceFirst(RegExp(r'^__XFER_\d+__\s*'), '');
}
