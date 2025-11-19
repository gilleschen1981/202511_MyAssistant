import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/features/splash/screens/splash_screen.dart';
import 'package:myassistant/presentation/features/auth/screens/login_screen.dart';
import 'package:myassistant/presentation/features/home/screens/home_screen.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';

/// App route paths
class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
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