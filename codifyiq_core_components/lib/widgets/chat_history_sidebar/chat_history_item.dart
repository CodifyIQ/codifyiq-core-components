import 'package:flutter/foundation.dart';

/// A single chat thread shown in [ChatHistorySidebar].
///
/// Items are immutable. Update a conversation by producing a new instance via
/// [copyWith] and replacing the entry in the list passed to the sidebar.
@immutable
class ChatHistoryItem {
  /// Creates a [ChatHistoryItem].
  ///
  /// [id] must remain stable across updates — it is used as the widget key and
  /// for active-chat comparison. [updatedAt] drives the descending-date sort.
  const ChatHistoryItem({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  /// Stable identifier for this conversation.
  final String id;

  /// Display title shown in the sidebar row.
  ///
  /// Long titles are truncated with an ellipsis.
  final String title;

  /// Timestamp of the most recent activity.
  ///
  /// [ChatHistorySidebar] sorts chats by this value, newest first.
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced.
  ChatHistoryItem copyWith({
    String? title,
    DateTime? updatedAt,
  }) {
    return ChatHistoryItem(
      id: id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatHistoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, title, updatedAt);

  @override
  String toString() =>
      'ChatHistoryItem(id: $id, title: $title, updatedAt: $updatedAt)';
}
