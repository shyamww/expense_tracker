import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../constants/feedback_config.dart';

enum FeedbackSendResult {
  success,
  notConfigured,
  networkError,
  rejected,
}

/// Outcome of a feedback submission (for SnackBars and debugging).
class FeedbackSendOutcome {
  final FeedbackSendResult result;

  /// Extra detail from the API or a hint for the user.
  final String? detail;

  const FeedbackSendOutcome(this.result, [this.detail]);
}

/// Submits to [Web3Forms](https://api.web3forms.com/submit).
class FeedbackSubmitter {
  static final Uri _endpoint = Uri.parse('https://api.web3forms.com/submit');

  static bool get isConfigured {
    final k = kWeb3FormsAccessKey.trim();
    return k.isNotEmpty && !k.contains('YOUR_ACCESS_KEY') && k.length >= 32;
  }

  static Future<FeedbackSendOutcome> send({
    required String message,
    String? replyEmail,
  }) async {
    if (!isConfigured) {
      debugPrint(
          '[Feedback] isConfigured=false (check key length & placeholder)');
      return const FeedbackSendOutcome(FeedbackSendResult.notConfigured);
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      debugPrint('[Feedback] Empty message');
      return const FeedbackSendOutcome(
        FeedbackSendResult.rejected,
        'Please enter a message.',
      );
    }

    debugPrint('[Feedback] POST $_endpoint (message len=${trimmed.length})');

    final body = <String, dynamic>{
      'access_key': kWeb3FormsAccessKey.trim(),
      'subject': kFeedbackEmailSubject,
      'message': trimmed,
      'from_name': 'Expense Tracker app',
    };
    final reply = replyEmail?.trim();
    if (reply != null && reply.isNotEmpty) {
      body['email'] = reply;
    }

    try {
      final res = await http
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      debugPrint(
          '[Feedback] HTTP ${res.statusCode} body=${_truncate(res.body)}');

      if (res.statusCode == 200) {
        try {
          final map = jsonDecode(res.body) as Map<String, dynamic>;
          if (map['success'] == true) {
            debugPrint('[Feedback] Web3Forms success');
            return const FeedbackSendOutcome(FeedbackSendResult.success);
          }
          final msg = _parseWeb3FormsMessage(map);
          debugPrint('[Feedback] Web3Forms success=false: $msg');
          return FeedbackSendOutcome(FeedbackSendResult.rejected, msg);
        } catch (e) {
          debugPrint('[Feedback] JSON parse error: $e');
          return const FeedbackSendOutcome(
            FeedbackSendResult.rejected,
            'Unexpected response from server.',
          );
        }
      }

      debugPrint('[Feedback] Non-200 status');
      return FeedbackSendOutcome(
        FeedbackSendResult.rejected,
        'Server returned ${res.statusCode}. ${_truncate(res.body)}',
      );
    } catch (e, st) {
      debugPrint('[Feedback] Exception: $e');
      debugPrint('[Feedback] Stack: $st');
      final es = e.toString();
      final blocked = es.contains('Failed host lookup') ||
          es.contains('SocketException') ||
          es.contains('ClientException') ||
          es.contains('XMLHttpRequest');
      final handshake =
          es.contains('HandshakeException') || es.contains('Handshake error');
      return FeedbackSendOutcome(
        FeedbackSendResult.networkError,
        blocked
            ? 'Network or browser blocked the request. On Flutter web, APIs are often blocked by CORS — try an iOS/Android build, or check the browser console (F12 → Network).'
            : handshake
                ? 'Secure connection failed (TLS handshake). Often fixed by: turning off VPN/proxy, cold-booting the emulator, using a system image with Google Play, or testing on a real device. Full error in console: $es'
                : 'Could not reach Web3Forms. $es',
      );
    }
  }

  static String? _parseWeb3FormsMessage(Map<String, dynamic> map) {
    final body = map['body'];
    if (body is Map<String, dynamic>) {
      final m = body['message'];
      if (m is String && m.isNotEmpty) return m;
    }
    final m = map['message'];
    if (m is String && m.isNotEmpty) return m;
    return 'Submission was not accepted.';
  }

  static String _truncate(String s) {
    if (s.length <= 120) return s;
    return '${s.substring(0, 120)}…';
  }
}
