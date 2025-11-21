import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/presentation/providers/goal_state_provider.dart';
import 'package:myassistant/presentation/providers/plan_state_provider.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';

/// Profile screen - displays user profile and settings
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final authState = ref.watch(authStateProvider);

    // Get statistics
    final goalState = ref.watch(goalListProvider);
    final planState = ref.watch(planListProvider);
    final taskListAsync = ref.watch(taskListNotifierProvider);
    final taskState = taskListAsync.value;

    if (user == null) {
      return const Center(
        child: Text('No user logged in'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      (user.displayName != null && user.displayName!.isNotEmpty)
                          ? user.displayName![0].toUpperCase()
                          : user.username[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // User name
                  Text(
                    (user.displayName != null && user.displayName!.isNotEmpty)
                        ? user.displayName!
                        : user.username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Username
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Email
                  if (user.email.isNotEmpty)
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Statistics section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Progress',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Active Goals',
                        value: goalState.activeGoals.length.toString(),
                        icon: Icons.flag,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Active Plans',
                        value: planState.activePlans.length.toString(),
                        icon: Icons.calendar_today,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Today\'s Tasks',
                        value: (taskState?.todayTasks.length ?? 0).toString(),
                        icon: Icons.task_alt,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Completed',
                        value: (taskState?.completedTasks.length ?? 0).toString(),
                        icon: Icons.check_circle,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // Settings section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Profile settings
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit profile coming soon'),
                      ),
                    );
                  },
                ),

                // Notification settings
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Manage your notification preferences',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification settings coming soon'),
                      ),
                    );
                  },
                ),

                // Theme settings
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Customize app theme and colors',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Theme settings coming soon'),
                      ),
                    );
                  },
                ),

                // Privacy settings
                _SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Privacy & Security',
                  subtitle: 'Manage your privacy settings',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy settings coming soon'),
                      ),
                    );
                  },
                ),

                // About
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'App version and information',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'MyAssistant',
                      applicationVersion: '1.0.0',
                      applicationIcon: Icon(
                        Icons.task_alt,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      children: [
                        const Text(
                          'MyAssistant is your personal task management companion, helping you achieve your goals one task at a time.',
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Sign out button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Sign Out'),
                                content: const Text(
                                  'Are you sure you want to sign out?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await ref
                                  .read(authStateProvider.notifier)
                                  .signOut();
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Sign Out'),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Statistics card widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings tile widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}