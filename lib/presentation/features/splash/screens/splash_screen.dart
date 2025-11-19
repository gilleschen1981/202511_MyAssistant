import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Splash screen shown during app initialization
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.task_alt,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 300.ms),

              const SizedBox(height: 30),

              // App name
              const Text(
                'MyAssistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 10),

              // Tagline
              const Text(
                'Your Personal Task Manager',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 400.ms),

              const SizedBox(height: 60),

              // Loading indicator
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 600.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 300.ms,
                    delay: 600.ms,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}