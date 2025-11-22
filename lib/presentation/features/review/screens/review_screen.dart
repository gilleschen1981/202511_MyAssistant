import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/features/review/screens/plan_review_list_screen.dart';

/// Review screen - main entry point for review module
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlanReviewListScreen();
  }
}
