import 'package:flutter/material.dart';

import 'ai_progress_indicator_example.dart';
import 'error_retry_widget_example.dart';
import 'social_sign_in_screen_example.dart';
import 'terms_and_conditions_widget_example.dart';

class WidgetCatalog extends StatelessWidget {
  const WidgetCatalog({super.key});

  // List of widget metadata for the catalog
  static const List<Map<String, dynamic>> widgetList = [
    {
      'name': 'Social Sign-In Screen',
      'description':
          'Generic social sign-in screen layout with customizable branding',
      'route': SocialSignInScreenExample(),
    },
    {
      'name': 'Terms and Conditions',
      'description': 'A general purpose terms and conditions widget',
      'route': TermsAndConditionsWidgetExample(),
    },
    {
      'name': 'AI Progress Indicator',
      'description': 'Progress indicator with shimmer effect for AI actions',
      'route': AiProgressIndicatorExample(),
    },
    {
      'name': 'Error Retry',
      'description': 'Generic retry widget',
      'route': ErrorRetryWidgetExample(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 3.0 : 5.0,
            ),
            itemCount: widgetList.length,
            itemBuilder: (context, index) {
              return WidgetCard(
                name: widgetList[index]['name'],
                description: widgetList[index]['description'],
                route: widgetList[index]['route'],
              );
            },
          ),
        );
      },
    );
  }
}

// Widget card for each catalog item
class WidgetCard extends StatelessWidget {
  final String name;
  final String description;
  final Widget route;

  const WidgetCard({
    super.key,
    required this.name,
    required this.description,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => route),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => route),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onInverseSurface,
                ),
                child: const Text('View Example'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
