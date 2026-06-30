// The GoRouter configuration for the application.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ai_progress_indicator_example.dart';
import 'audio_message_example.dart';
import 'group_manager_example.dart';
import 'notification_center_example.dart';
import 'pdf_viewer_widget_example.dart';
import 'image_viewer_widget_example.dart';
import 'social_sign_in_screen_example.dart';
import 'terms_and_conditions_widget_example.dart';
import 'widget_catalog.dart';

/// Path for the home page.
const String homePath = '/home';

///
/// This router handles navigation and authentication checks.
///
/// Each screen owns its own [Scaffold] and [AppBar] — the catalog home
/// supplies the app bar for the grid, and every example supplies its own
/// (with a back button and any per-screen actions). There is no shared
/// shell chrome, so drilling into an example never stacks two app bars.
final GoRouter router = GoRouter(
  initialLocation: homePath,
  routes: <RouteBase>[
    GoRoute(
      path: homePath,
      builder: (BuildContext context, GoRouterState state) {
        return const WidgetCatalog();
      },
    ),
    GoRoute(
      path: "/terms-and-conditions",
      builder: (BuildContext context, GoRouterState state) {
        return TermsAndConditionsWidgetExample();
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
      path: "/image-viewer",
      builder: (BuildContext context, GoRouterState state) {
        return ImageViewerWidgetExample();
      },
    ),
    GoRoute(
      path: "/audio-message",
      builder: (BuildContext context, GoRouterState state) {
        return const AudioMessageExample();
      },
    ),
    GoRoute(
      path: "/group-manager",
      builder: (BuildContext context, GoRouterState state) {
        return const GroupManagerExample();
      },
    ),
  ],
);
