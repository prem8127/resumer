import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'screens/applications_screen.dart';
import 'screens/career_profile_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/launch_flow.dart';
import 'screens/profile_screen.dart';
import 'screens/resumes_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/prism_dock.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          return MaterialApp(
            title: 'Resumer',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const LaunchFlow(home: HomeShell()),
          );
        },
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final aiAppliedCount =
        state.applications.where((a) => a.appliedByAi).length;
    final items = [
      const DockItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.search_rounded,
        label: 'Explore',
      ),
      const DockItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description_rounded,
        label: 'Resumes',
      ),
      const DockItem(
        icon: Icons.auto_awesome_mosaic_outlined,
        activeIcon: Icons.auto_awesome_mosaic_rounded,
        label: 'Career',
      ),
      DockItem(
        icon: Icons.bookmark_border_rounded,
        activeIcon: Icons.bookmark_rounded,
        label: 'Tracker',
        badgeCount: aiAppliedCount,
      ),
      const DockItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
      ),
      const DockItem(
        icon: Icons.school_outlined,
        activeIcon: Icons.school_rounded,
        label: 'Learn',
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
              onNavigate: (index) => setState(() => _index = index)),
          const ResumesScreen(),
          const CareerProfileScreen(),
          const ApplicationsScreen(),
          const ProfileScreen(),
          const CoursesScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: PrismDock(
          items: items,
          currentIndex: _index,
          onSelect: (index) => setState(() => _index = index),
        ),
      ),
    );
  }
}
