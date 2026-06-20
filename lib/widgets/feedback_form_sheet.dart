import 'package:flutter/material.dart';

import '../services/feedback_submitter.dart';

/// Bottom sheet: user writes feedback; sent via HTTPS (email stays on form provider only).
class FeedbackFormSheet extends StatefulWidget {
  const FeedbackFormSheet({
    super.key,
    required this.scaffoldMessenger,
  });

  /// Messenger from the screen that opened the sheet (not the overlay context).
  final ScaffoldMessengerState scaffoldMessenger;

  @override
  State<FeedbackFormSheet> createState() => _FeedbackFormSheetState();
}

class _FeedbackFormSheetState extends State<FeedbackFormSheet> {
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint(
        '[Feedback] Send tapped. configured=${FeedbackSubmitter.isConfigured}');

    if (!FeedbackSubmitter.isConfigured) {
      debugPrint('[Feedback] Aborted: access key not configured');
      if (mounted) {
        widget.scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Build with --dart-define=WEB3FORMS_ACCESS_KEY=your-key, then try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _sending = true);
    FeedbackSendOutcome outcome;
    try {
      outcome = await FeedbackSubmitter.send(
        message: _messageController.text,
        replyEmail: _emailController.text,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    debugPrint('[Feedback] Result: ${outcome.result} detail=${outcome.detail}');

    if (!mounted) {
      debugPrint('[Feedback] Widget unmounted after send; skipping UI');
      return;
    }

    final messenger = widget.scaffoldMessenger;

    if (outcome.result == FeedbackSendResult.success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks — your feedback was sent.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }
    if (outcome.result == FeedbackSendResult.notConfigured) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Feedback form is not configured yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (outcome.result == FeedbackSendResult.networkError) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(outcome.detail ?? 'Check your connection and try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(outcome.detail ?? 'Could not send feedback.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding:
          EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Send feedback',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Feedback is sent with Web3Forms. Your personal inbox is not embedded in the app.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade600, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'What would you like to share?',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Your email (optional)',
              hintText: 'So we can reply',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _sending
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send'),
          ),
          TextButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
