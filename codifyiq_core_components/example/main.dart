import 'package:codifyiq_core_components/widgets/error_retry_widget.dart';
import 'package:codifyiq_core_components/widgets/terms_and_conditions_widget.dart';
import 'package:flutter/material.dart';

import 'error_retry_widget_example.dart';
import 'terms_and_conditions_widget_example.dart';

// Main catalog page widget
class WidgetCatalog extends StatelessWidget {
  const WidgetCatalog({super.key});

  // List of widget metadata for the catalog
  static const List<Map<String, dynamic>> widgetList = [
    {
      'name': 'Terms and Conditions',
      'description': 'A general purpose terms and conditions widget',
      'route': TermsAndConditionsWidgetExample(),
    },
    {
      'name': 'Error Retry',
      'description': 'Generic retry widget',
      'route': ErrorRetryWidgetExample(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Design Widget Catalog'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Adjust based on screen size if needed
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
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
                  color: Theme.of(context).primaryColor,
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
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => route),
                  );
                },
                child: const Text('View Example'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Main application entry point
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodifyIQ Core Components Catalog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF18D777)),
        useMaterial3: true,
      ),
      home: WidgetCatalog(),
    );
  }
}
