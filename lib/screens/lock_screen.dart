import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_lock_provider.dart';
import '../services/app_lock_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final svc = AppLockService.instance;
    if (!svc.isBiometricEnabled) return;
    if (!await svc.deviceCanCheckBiometrics()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await svc.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      context.read<AppLockProvider>().unlock();
    }
  }

  Future<void> _submitPin() async {
    if (_pin.length != 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AppLockService.instance.verifyPin(_pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      HapticFeedback.lightImpact();
      context.read<AppLockProvider>().unlock();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _error = 'Incorrect PIN';
      });
    }
  }

  void _onKey(String digit) {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _error = null;
      _pin += digit;
    });
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bioOn = AppLockService.instance.isBiometricEnabled;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.lock_rounded,
                size: 56,
                color: scheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Expense Tracker',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your 4-digit PIN',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? scheme.primary : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: (_pin.length == 4 && !_busy) ? _submitPin : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Unlock'),
                ),
              ),
              const Spacer(flex: 2),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                _Keypad(
                  onDigit: _onKey,
                  onBackspace: _onBackspace,
                  onBiometric: bioOn ? _tryBiometric : null,
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final Future<void> Function()? onBiometric;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row
                  .map(
                    (d) => _KeyButton(
                      label: d,
                      onTap: () => onDigit(d),
                    ),
                  )
                  .toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              onBiometric != null
                  ? _KeyButton(
                      icon: Icons.fingerprint_rounded,
                      onTap: () => onBiometric!(),
                    )
                  : const SizedBox(width: 72, height: 72),
              _KeyButton(label: '0', onTap: () => onDigit('0')),
              _KeyButton(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({this.label, this.icon, required this.onTap})
      : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Icon(icon, size: 28, color: Colors.grey.shade800),
          ),
        ),
      ),
    );
  }
}
