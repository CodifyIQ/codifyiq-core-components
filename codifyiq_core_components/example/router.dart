// The GoRouter configuration for the application.
import 'package:codifyiq_core_components/widgets/brightness_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ai_progress_indicator_example.dart';
import 'chat_widget_example.dart';
import 'error_retry_widget_example.dart';
import 'social_sign_in_screen_example.dart';
import 'terms_and_conditions_widget_example.dart';
import 'widget_catalog.dart';

/// Path for the home page.
const String homePath = '/home';

///
/// This router handles navigation and authentication checks.
final GoRouter router = GoRouter(
  initialLocation: homePath,
  routes: <RouteBase>[_getMainApplicationShellRoute()],
);

ShellRoute _getMainApplicationShellRoute() {
  return ShellRoute(
    builder: (BuildContext context, GoRouterState state, Widget child) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Material Design Widget Catalog',
            style: TextStyle(
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.primary,
          actions: [BrightnessButton()],
        ),
        body: child,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: homePath,
        builder: (BuildContext context, GoRouterState state) {
          return WidgetCatalog();
        },
      ),
      GoRoute(
        path: "/terms-and-conditions",
        builder: (BuildContext context, GoRouterState state) {
          return TermsAndConditionsWidgetExample();
        },
      ),
      GoRoute(
        path: "/error-retry",
        builder: (BuildContext context, GoRouterState state) {
          return ErrorRetryWidgetExample();
        },
      ),
      GoRoute(
        path: "/ai-progress-indicator",
        builder: (BuildContext context, GoRouterState state) {
          return AiProgressIndicatorExample();
        },
      ),
      GoRoute(
        path: "/social-sign-in",
        builder: (BuildContext context, GoRouterState state) {
          return SocialSignInScreenExample();
        },
      ),
      GoRoute(
        path: "/chat-super-widget",
        builder: (BuildContext context, GoRouterState state) {
          return ChatWidgetExample();
        },
      ),
    ],
  );
}
