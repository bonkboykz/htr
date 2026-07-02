import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Temporary screen scaffold. Screen agents replace these with the real
/// data/cubit/presentation, building against design-exports/[ref].
class FeaturePlaceholder extends StatelessWidget {
  final String title;
  final String designRef;
  final bool showSettings;
  const FeaturePlaceholder({
    super.key,
    required this.title,
    required this.designRef,
    this.showSettings = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showSettings)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dashboard_customize_outlined, size: 40),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Экран в разработке · дизайн: $designRef',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
