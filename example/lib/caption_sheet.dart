import 'package:material_ui/material_ui.dart';

/// A bottom sheet that previews a photo before it is sent and lets the user
/// add a caption, which the chat puts in the image message's `text`.
class CaptionSheet extends StatefulWidget {
  /// Creates a [CaptionSheet] previewing [image].
  const CaptionSheet({super.key, required this.image});

  /// The photo about to be sent.
  final ImageProvider image;

  /// Shows a [CaptionSheet] for [image]. Completes with the caption, empty
  /// when none was typed, or `null` when the sheet was dismissed.
  static Future<String?> show(BuildContext context, ImageProvider image) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => CaptionSheet(image: image),
      );

  @override
  State<CaptionSheet> createState() => _CaptionSheetState();
}

class _CaptionSheetState extends State<CaptionSheet> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _send() => Navigator.pop(context, _caption.text.trim());

  @override
  Widget build(BuildContext context) => Padding(
    // Kept above the keyboard, or the home indicator when it is closed.
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      16 +
          MediaQuery.viewInsetsOf(context).bottom +
          MediaQuery.paddingOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Image(image: widget.image, fit: BoxFit.contain),
          ),
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: TextField(
                controller: _caption,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Add a caption',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton.filled(
              onPressed: _send,
              tooltip: 'Send',
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    ),
  );
}
