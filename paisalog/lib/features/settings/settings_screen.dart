/// Settings screen — accounts, categories, privacy, import/export.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader(title: 'ACCOUNTS & CATEGORIES'),
          _SettingsTile(
            icon: Icons.account_balance_outlined,
            title: 'Accounts',
            subtitle: 'Manage bank accounts, cards, cash',
            onTap: () => context.push('/settings/accounts'),
          ),
          _SettingsTile(
            icon: Icons.label_outline,
            title: 'Categories',
            subtitle: 'Manage spending categories',
            onTap: () => context.push('/settings/categories'),
          ),

          _SectionHeader(title: 'PRIVACY & SECURITY'),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'App Lock',
            subtitle: 'Use Face ID / Touch ID / Passcode',
            onTap: () => context.push('/settings/privacy'),
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Privacy Info',
            subtitle: 'No backend, no cloud sync, no analytics',
            onTap: () => _showPrivacyInfo(context),
          ),

          _SectionHeader(title: 'DATA'),
          _SettingsTile(
            icon: Icons.upload_file_outlined,
            title: 'Import CSV',
            subtitle: 'Import transactions from a CSV file',
            onTap: () => context.push('/settings/import-export'),
          ),
          _SettingsTile(
            icon: Icons.download_outlined,
            title: 'Export CSV',
            subtitle: 'Export your transactions — file may be unencrypted',
            onTap: () => _showExportWarning(context),
          ),

          _SectionHeader(title: 'SMS CAPTURE & TESTING'),
          _SettingsTile(
            icon: Icons.psychology_outlined,
            title: 'SMS Simulator (Sandbox)',
            subtitle: 'Paste SMS or try presets to test parsing & ledger',
            trailing: _StatusBadge(
              label: 'Interactive',
              color: PaisaColors.income,
            ),
            onTap: () => context.push('/settings/simulator'),
          ),
          _SettingsTile(
            icon: Icons.sms_outlined,
            title: 'iOS Shortcuts Setup',
            subtitle: 'How to configure Shortcuts + App Intents capture',
            trailing: _StatusBadge(
              label: 'Unverified',
              color: PaisaColors.review,
            ),
            onTap: () => _showShortcutsInfo(context),
          ),

          _SectionHeader(title: 'ABOUT'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'PaisaLog',
            subtitle: 'v0.1.0 — Personal, local-first expense tracker',
            onTap: () {},
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showPrivacyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy'),
        content: const Text(
          'PaisaLog is local-first:\n\n'
          '• No account or login required\n'
          '• No backend server\n'
          '• No cloud sync or analytics\n'
          '• No SMS sent to external services\n'
          '• Data stays on your device\n\n'
          'Exports are explicit user actions and the file may be unencrypted — '
          'handle exported files with care.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showExportWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export Warning'),
        content: const Text(
          'Exported CSV files contain your transaction history.\n\n'
          'The file will NOT be encrypted unless you choose an encrypted '
          'destination (e.g. password-protected ZIP or encrypted cloud folder).\n\n'
          'Only export to trusted locations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: trigger ImportExportService.exportCsv()
            },
            child: const Text('Export anyway'),
          ),
        ],
      ),
    );
  }

  void _showShortcutsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('iOS Shortcuts Capture'),
        content: const Text(
          'Status: UNVERIFIED\n\n'
          'The iOS Shortcuts + App Intents capture path has not been tested '
          'on a real device yet.\n\n'
          'Until verified, use:\n'
          '• Manual entry (Add Transaction)\n'
          '• CSV import (Import CSV)\n\n'
          'See BUILD_STATUS.md for the POC plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PaisaSpacing.md,
        PaisaSpacing.lg,
        PaisaSpacing.md,
        PaisaSpacing.xs,
      ),
      child: Text(
        title,
        style: PaisaTextStyles.sectionHeader.copyWith(
          color: PaisaColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: PaisaColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: PaisaColors.primary, size: 20),
      ),
      title: Text(title, style: PaisaTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: PaisaTextStyles.bodySmall.copyWith(color: PaisaColors.textSecondary),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: PaisaColors.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PaisaSpacing.md,
        vertical: PaisaSpacing.xs,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: PaisaTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

