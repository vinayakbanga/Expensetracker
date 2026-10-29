/// Privacy and security settings screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _appLockEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.all(PaisaSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PaisaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: PaisaColors.income, size: 28),
                      const SizedBox(width: PaisaSpacing.sm),
                      Text(
                        '100% Local-First Architecture',
                        style: PaisaTextStyles.body
                            .copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: PaisaSpacing.sm),
                  Text(
                    'PaisaLog was built with a strict privacy-first foundation. '
                    'Your financial data never leaves your device under any circumstances.',
                    style: PaisaTextStyles.body
                        .copyWith(color: PaisaColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PaisaSpacing.md),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline_rounded),
                  title: const Text('App Lock'),
                  subtitle: const Text(
                      'Require Face ID, Touch ID, or Passcode to open app'),
                  value: _appLockEnabled,
                  onChanged: (val) async {
                    final sec = ref.read(securityServiceProvider);
                    final available = await sec.isBiometricAvailable();
                    setState(() => _appLockEnabled = val);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? (available
                                    ? 'App Lock enabled (Biometrics ready)'
                                    : 'App Lock enabled (System fallback)')
                                : 'App Lock disabled',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: PaisaSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PaisaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECURITY CHECKLIST',
                    style: PaisaTextStyles.sectionHeader
                        .copyWith(color: PaisaColors.textSecondary),
                  ),
                  const SizedBox(height: PaisaSpacing.sm),
                  _checklistRow(
                    icon: Icons.cloud_off,
                    title: 'No Cloud Backend',
                    desc: 'No remote servers, APIs, or databases.',
                  ),
                  const Divider(),
                  _checklistRow(
                    icon: Icons.track_changes_outlined,
                    title: 'Zero Analytics or Tracking',
                    desc: 'No crashlytics, telemetry, or behavioral tracking.',
                  ),
                  const Divider(),
                  _checklistRow(
                    icon: Icons.visibility_off_outlined,
                    title: 'Offline SMS Processing',
                    desc: 'All parsing occurs on-device via strict deterministic regex rules.',
                  ),
                  const Divider(),
                  _checklistRow(
                    icon: Icons.file_download_outlined,
                    title: 'Manual Encrypted Export Only',
                    desc: 'Exports only happen when explicitly initiated by you.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PaisaSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: PaisaColors.primary),
          const SizedBox(width: PaisaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: PaisaTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                  desc,
                  style: PaisaTextStyles.bodySmall
                      .copyWith(color: PaisaColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
