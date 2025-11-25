import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/features/splash/screens/splash_screen.dart';
import 'package:myassistant/presentation/features/auth/screens/login_screen.dart';
import 'package:myassistant/presentation/features/home/screens/home_screen.dart';
import 'package:myassistant/presentation/features/planning/screens/goal_detail_screen.dart';
import 'package:myassistant/presentation/features/review/screens/plan_detail_review_screen.dart';
import 'package:myassistant/presentation/features/tasks/screens/timer_screen.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/data/models/task_model.dart';

/// App route paths
class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const goalDetail = '/goal/:goalId';
  static const planReview = '/review/plan/:planId';
  static const timer = '/timer';

  /// Helper methods to build route paths with parameters
  static String goalDetailPath(String goalId) => '/goal/$goalId';
  static String planReviewPath(String planId) => '/review/plan/$planId';
}

/// GoRouter provider
final routerProvider = Provider<GoRouter>((ref) {
  // DEMO MODE: Skip all auth checks and go directly to home
  // final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,  // DEMO MODE: Go directly to home page
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // DEMO MODE: No redirects needed, always stay on current page
      return null;

      // Original code commented out
      // final isLoggedIn = authState.user != null;
      // final isSplash = state.matchedLocation == AppRoutes.splash;
      // final isLogin = state.matchedLocation == AppRoutes.login;

      // // If we're on splash, let it handle navigation
      // if (isSplash) {
      //   return null;
      // }

      // // If not logged in and not on login page, redirect to login
      // if (!isLoggedIn && !isLogin) {
      //   return AppRoutes.login;
      // }

      // // If logged in and on login page, redirect to home
      // if (isLoggedIn && isLogin) {
      //   return AppRoutes.home;
      // }

      // // No redirect needed
      // return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      // Goal detail route
      GoRoute(
        path: AppRoutes.goalDetail,
        builder: (context, state) {
          final goalId = state.pathParameters['goalId']!;
          return GoalDetailScreenWrapper(goalId: goalId);
        },
      ),
      // Plan review detail route
      GoRoute(
        path: AppRoutes.planReview,
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return PlanDetailReviewScreen(planId: planId);
        },
      ),
      // Timer screen route
      GoRoute(
        path: AppRoutes.timer,
        builder: (context, state) {
          final task = state.extra as TaskModel;
          return TimerScreen(task: task);
        },
      ),
    ],
  );
});

/// Router notifier for reactive navigation
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(
      authStateProvider.select((value) => value.user),
      (previous, next) {
        notifyListeners();
      },
    );
  }
}

/// Wrapper widget to load goal data by ID and display goal detail screen
class GoalDetailScreenWrapper extends ConsumerStatefulWidget {
  final String goalId;

  const GoalDetailScreenWrapper({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreenWrapper> createState() => _GoalDetailScreenWrapperState();
}

class _GoalDetailScreenWrapperState extends ConsumerState<GoalDetailScreenWrapper> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref.read(goalRepositoryProvider).getGoalById(widget.goalId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('目标详情')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('目标详情')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.hasError ? '加载失败' : '目标不存在',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        return GoalDetailScreen(goal: snapshot.data!);
      },
    );
  }
}