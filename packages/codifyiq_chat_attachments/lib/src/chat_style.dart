import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// The `ChatTheme` that `flutter_chat_ui`'s `Chat` provides, or one made from
/// the app's [Theme] outside a `Chat`.
ChatTheme chatThemeOf(BuildContext context) =>
    context.watch<ChatTheme?>() ?? ChatTheme.fromThemeData(Theme.of(context));

/// The time format that `Chat` provides, or `Chat`'s default outside one.
DateFormat timeFormatOf(BuildContext context) =>
    context.watch<DateFormat?>() ?? _defaultTimeFormat;

final _defaultTimeFormat = DateFormat('HH:mm');

/// A bubble's background and foreground colours from [theme].
(Color background, Color foreground) bubbleColors(
  ChatTheme theme, {
  required bool isSentByMe,
}) => isSentByMe
    ? (theme.colors.primary, theme.colors.onPrimary)
    : (theme.colors.surfaceContainer, theme.colors.onSurface);
