import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A widget for displaying and accepting terms and conditions with a scrollable
/// Markdown view and a checkbox for acceptance.
///
/// The checkbox is enabled only when the content is non-scrollable or the user
/// has scrolled to the end of the terms. Once enabled, it remains clickable.
class TermsAndConditionsWidget extends StatefulWidget {
  /// The Markdown content for the terms and conditions. If null, default text is used.
  final String? termsContent;

  /// Callback invoked when the terms are accepted.
  final VoidCallback? onAccepted;

  const TermsAndConditionsWidget({
    super.key,
    this.termsContent,
    this.onAccepted,
  });

  @override
  TermsAndConditionsWidgetState createState() =>
      TermsAndConditionsWidgetState();
}

/// The state for [TermsAndConditionsWidget], managing scroll position and acceptance state.
class TermsAndConditionsWidgetState extends State<TermsAndConditionsWidget> {
  bool _isAccepted = false;
  bool _canAccept = false;
  final ScrollController _scrollController = ScrollController();

  /// Default Markdown formatted Lorem Ipsum text for terms if none provided.
  static const String _defaultTerms = '''
# Terms and Conditions

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

## Section 1
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

## Section 2
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

### Subsection 2.1
Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

### Subsection 2.2
At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident, similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga. Et harum quidem rerum facilis est et expedita distinctio. Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil impedit quo minus id quod maxime placeat facere possimus, omnis voluptas assumenda est, omnis dolor repellendus. Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet ut et voluptates repudiandae sint et molestiae non recusandae. Itaque earum rerum hic tenetur a sapiente delectus, ut aut reiciendis voluptatibus maiores alias consequatur aut perferendis doloribus asperiores repellat.

---

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.
''';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Check scrollability after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollability());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  /// Checks if the content is scrollable and updates [_canAccept] if necessary.
  ///
  /// If the content fits within the viewport or the user has scrolled to the end,
  /// [_canAccept] is set to true and remains true.
  void _checkScrollability() {
    if (!_scrollController.hasClients || !mounted || _canAccept) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final currentPosition = _scrollController.position.pixels;

    // Enable acceptance if content is non-scrollable or scrolled to the end
    // Added a small buffer (e.g., 1.0) for floating point precision with maxScrollExtent
    if (maxScrollExtent <= 0 || currentPosition >= maxScrollExtent - 1.0) {
      if (mounted) {
        setState(() {
          _canAccept = true;
        });
      }
    }
  }

  /// Listens for scroll updates and checks scrollability.
  void _scrollListener() {
    _checkScrollability();
  }

  /// Handles checkbox state changes and triggers the acceptance callback.
  void _handleAcceptanceChanged(bool? newValue) {
    if (newValue == null || !_canAccept) return;
    setState(() {
      _isAccepted = newValue;
    });
    if (newValue) {
      widget.onAccepted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 0, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildTermsContainer(context)),
          const SizedBox(height: 16),
          _buildAcceptanceRow(context),
          _canAccept
              ? const SizedBox(height: 32.0)
              : _buildScrollPrompt(context),
        ],
      ),
    );
  }

  /// Builds the scrollable container for the terms content.
  Widget _buildTermsContainer(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: GptMarkdown(widget.termsContent ?? _defaultTerms),
        ),
      ),
    );
  }

  /// Builds the row containing the checkbox and acceptance text.
  Widget _buildAcceptanceRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _isAccepted,
          onChanged: _canAccept ? _handleAcceptanceChanged : null,
          semanticLabel: 'Accept terms and conditions',
        ),
        Expanded(
          child: Text(
            'I have read and agree to the Terms and Conditions.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// Builds the prompt to scroll to the end, shown only when [_canAccept] is false.
  Widget _buildScrollPrompt(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24.0, left: 16, right: 16),
      child: Text(
        'Please scroll to the end of the terms to enable acceptance.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
        textAlign: TextAlign.center,
      ),
    );
  }
}
