import 'package:flutter/material.dart';

import 'ai_progress_indicator_example.dart';
import 'error_retry_widget_example.dart';
import 'notification_center_example.dart';
import 'pdf_viewer_widget_example.dart';
import 'social_sign_in_screen_example.dart';
import 'terms_and_conditions_widget_example.dart';
import 'image_viewer_widget_example.dart';

class WidgetCatalog extends StatelessWidget {
  const WidgetCatalog({super.key});

  // List of widget metadata for the catalog
  static final List<Map<String, dynamic>> widgetList = [
    {
      'name': 'Social Sign-In Screen',
      'description':
          'Generic social sign-in screen layout with customizable branding',
      'route': SocialSignInScreenExample(),
    },
    {
      'name': 'Image Viewer',
      'description':
          'Full-screen image viewer with swipe, pinch-zoom, and actions',
      'route': ImageViewerWidgetExample(),
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
    {
      'name': 'Notification Center',
      'description':
          'Play Store-style bell with progress tracking for long-running tasks',
      'route': NotificationCenterExample(),
    },
    {
      'name': 'PDF Viewer',
      'description':
          'PDF viewer with zoom, page indicator, and optional text search',
      'route': PdfViewerWidgetExample(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 480,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 80,
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
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
