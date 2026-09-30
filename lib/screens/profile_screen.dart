import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/catalog.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/cloud_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/route_utils.dart';
import 'auto_apply_screen.dart';
import 'admin_dashboard_screen.dart';
import 'creator_studio_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 134),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Your account and preferences.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Edit profile',
                onPressed: () => _showEditProfile(context, state),
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProfileIdentity(state: state),
          if (state.isAuthenticated) const _RoleEntry(),
          const SizedBox(height: 14),
          _PlanSummary(
              state: state, onChange: () => _showPlans(context, state)),
          const SizedBox(height: 26),
          Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 11),
          GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 18,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark mode',
                  subtitle: 'A lower-light neutral theme',
                  trailing: Switch(
                    value: state.darkMode,
                    onChanged: (_) => state.toggleDarkMode(),
                  ),
                ),
                const _Line(),
                _SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  subtitle: 'Application and resume alerts',
                  trailing: Switch(
                    value: state.notificationsEnabled,
                    onChanged: (_) => state.toggleNotifications(),
                  ),
                ),
                const _Line(),
                _SettingsRow(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI auto-apply',
                  subtitle: state.autoApplyEnabled
                      ? 'Tailors your resume and applies to matching open roles'
                      : 'Let AI apply to open internships and jobs for you',
                  trailing: Switch(
                    value: state.autoApplyEnabled,
                    onChanged: (enabled) {
                      state.setAutoApplyEnabled(enabled);
                      if (enabled) {
                        pushRouteOnce(
                          context,
                          (_) => const AutoApplyScreen(),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (state.autoApplyEnabled) ...[
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              borderRadius: 18,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: AppColors.sageSoft,
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 19, color: AppColors.sage),
                ),
                title: Text('Run auto-apply now',
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                  'Tailor the master resume and apply to every open role',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                onTap: () =>
                    pushRouteOnce(context, (_) => const AutoApplyScreen()),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 11),
          GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 18,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  label: 'Privacy & AI',
                  subtitle: 'How your evidence is used',
                  onTap: () => _showInfo(
                    context,
                    'Privacy & AI',
                    'Job descriptions and career evidence are sent only when you request tailoring. The AI is instructed to use your Career profile as the factual boundary and every generated rewrite remains reviewable before it is saved.',
                  ),
                ),
                const _Line(),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  label: 'About Resumer',
                  subtitle: 'Version 1.0.0',
                  onTap: () => _showInfo(
                    context,
                    'About Resumer',
                    'A focused workspace for evidence-backed resumes, relevant jobs, and a clearer application process.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, state),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side:
                    BorderSide(color: AppColors.danger.withValues(alpha: .45)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(state: state),
    );
  }

  void _showPlans(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a plan',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              for (final plan in plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    borderRadius: 16,
                    color: plan.id == state.planId ? AppColors.sageSoft : null,
                    onTap: () {
                      state.setPlan(plan.id);
                      Navigator.of(sheetContext).pop();
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plan.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 3),
                              Text(plan.priceLabel,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (plan.id == state.planId)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.sage),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 2, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You will return to the sign-in screen. Your profile and resumes stay saved on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              state.logout();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _RoleEntry extends StatefulWidget {
  const _RoleEntry();

  @override
  State<_RoleEntry> createState() => _RoleEntryState();
}

class _RoleEntryState extends State<_RoleEntry> {
  final CloudDataService _cloud = CloudDataService();
  late Future<AppRole> _role;

  @override
  void initState() {
    super.initState();
    _role = _cloud.currentRole();
  }

  void _refresh() => setState(() => _role = _cloud.currentRole());

  @override
  Widget build(BuildContext context) => FutureBuilder<AppRole>(
        future: _role,
        builder: (context, snapshot) {
          final role = snapshot.data;
          if (role == AppRole.influencer) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.edit_note_outlined),
                  title: const Text('Creator Studio'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => pushRouteOnce(
                    context,
                    (_) => const CreatorStudioScreen(),
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  role == AppRole.admin || role == AppRole.superAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.lock_outline_rounded,
                ),
                title: Text(
                  role == AppRole.admin || role == AppRole.superAdmin
                      ? 'Admin Dashboard'
                      : 'Admin access',
                ),
                subtitle: Text(
                  snapshot.hasError
                      ? 'Could not read your Supabase role. Tap to retry.'
                      : role == null
                          ? 'Checking account access…'
                          : role == AppRole.admin || role == AppRole.superAdmin
                              ? 'Signed in as ${AuthService.instance.currentUser?.email ?? 'Google account'} · ${role.name}'
                              : 'Current role: ${role.name}. Admin access is assigned separately.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Refresh account role',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                onTap: () => pushRouteOnce(
                  context,
                  (_) => const AdminDashboardScreen(),
                ),
              ),
            ),
          );
        },
      );
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.sageSoft, shape: BoxShape.circle),
            child: Text(
              user.initials,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sage),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                        child: Text(user.name,
                            style: Theme.of(context).textTheme.titleLarge)),
                    if (state.planId == PlanId.pro) ...[
                      const SizedBox(width: 7),
                      const SignalKicker('PRO'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  user.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.sage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.state, required this.onChange});

  final AppState state;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final plan = plans.firstWhere((item) => item.id == state.planId);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
          color: AppColors.darkBlue, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_outlined,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.name} plan',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(plan.priceLabel,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11.5)),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: AppColors.sageSoft, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 18, color: AppColors.sage),
      ),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 19),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.state});

  final AppState state;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  late final TextEditingController _headline;

  @override
  void initState() {
    super.initState();
    final user = widget.state.user;
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
    _phone = TextEditingController(text: user.phone);
    _location = TextEditingController(text: user.location);
    _headline = TextEditingController(text: user.headline);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _headline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 4, 22, bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit profile',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          _field(_name, 'Full name'),
          _field(_headline, 'Headline', maxLines: 2),
          _field(_email, 'Email'),
          _field(_phone, 'Phone'),
          _field(_location, 'Location'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.state.updateUser(
                  name: _name.text.trim(),
                  email: _email.text.trim(),
                  phone: _phone.text.trim(),
                  location: _location.text.trim(),
                  headline: _headline.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 66, endIndent: 12);
  }
}
