import 'package:flutter/material.dart';

/// Stand-in body for primary-nav destinations whose screens land in later
/// sprints. Keeps the S2 exit criterion "navigation reaches all primary
/// screens without crash" honest.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(detail),
        ],
      ),
    );
  }
}
