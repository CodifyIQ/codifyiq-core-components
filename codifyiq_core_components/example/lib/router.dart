// The GoRouter configuration for the application.
import 'package:codifyiq_core_components/widgets/brightness_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ai_chat_screen_example.dart';
import 'ai_progress_indicator_example.dart';
import 'error_retry_widget_example.dart';
import 'notification_center_example.dart';
import 'pdf_viewer_widget_example.dart';
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
          title: const Text('Material Design Widget Catalog'),
          centerTitle: true,
          actions: const [BrightnessButton()],
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
        path: "/notification-center",
        builder: (BuildContext context, GoRouterState state) {
          return NotificationCenterExample();
        },
      ),
      GoRoute(
        path: "/pdf-viewer",
        builder: (BuildContext context, GoRouterState state) {
          return PdfViewerWidgetExample();
        },
      ),
      GoRoute(
        path: "/ai-chat",
        builder: (BuildContext context, GoRouterState state) {
          return AiChatScreenExample();
        },
      ),
    ],
  );
}
