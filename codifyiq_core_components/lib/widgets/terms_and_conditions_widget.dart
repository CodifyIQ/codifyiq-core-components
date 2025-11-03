import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A widget for displaying and accepting terms and conditions with a scrollable
/// Markdown view and a button for acceptance.
///
/// The button displays a prompt to read the terms until the user has scrolled to
/// the end. Once scrolled, the button text changes to indicate acceptance.
class TermsAndConditionsWidget extends StatefulWidget {
  /// The optional header text to be displayed above the terms.
  /// Defaults to 'Terms and Conditions'.
  final String headerText;

  /// The Markdown content for the terms and conditions. If null, default text is used.
  final String? termsContent;

  /// Callback invoked when the terms are accepted.
  final VoidCallback? onAccepted;

  const TermsAndConditionsWidget({
    super.key,
    this.headerText = 'Terms and Conditions',
    this.termsContent,
    this.onAccepted,
  });

  @override
  TermsAndConditionsWidgetState createState() =>
      TermsAndConditionsWidgetState();
}

/// The state for [TermsAndConditionsWidget], managing scroll position and acceptance state.
class TermsAndConditionsWidgetState extends State<TermsAndConditionsWidget> {
  bool _hasScrolledToEnd = false;
  final ScrollController _scrollController = ScrollController();

  /// Default Markdown formatted Lorem Ipsum text for terms if none provided.
  static const String _defaultTerms = '''
# Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

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

  /// Checks if the content is scrollable and updates [_hasScrolledToEnd] if necessary.
  ///
  /// If the content fits within the viewport or the user has scrolled to the end,
  /// [_hasScrolledToEnd] is set to true and remains true.
  void _checkScrollability() {
    if (!_scrollController.hasClients || !mounted || _hasScrolledToEnd) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final currentPosition = _scrollController.position.pixels;

    // Enable acceptance if content is non-scrollable or scrolled to the end
    // Added a small buffer (e.g., 1.0) for floating point precision with maxScrollExtent
    if (maxScrollExtent <= 0 || currentPosition >= maxScrollExtent - 1.0) {
      if (mounted) {
        setState(() {
          _hasScrolledToEnd = true;
        });
      }
    }
  }

  /// Listens for scroll updates and checks scrollability.
  void _scrollListener() {
    _checkScrollability();
  }

  /// Handles button press and triggers the acceptance callback.
  void _handleAcceptance() {
    if (!_hasScrolledToEnd) return;
      widget.onAccepted?.call();
    }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 0, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.headerText,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          Expanded(child: _buildTermsContainer(context)),
          const SizedBox(height: 24),
          _buildAcceptanceButton(context),
          const SizedBox(height: 32.0),
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

  /// Builds the acceptance button.
  ///
  /// The button text changes based on whether the user has scrolled to the end.
  Widget _buildAcceptanceButton(BuildContext context) {
    final buttonText = _hasScrolledToEnd
        ? 'I have read and agree to the Terms and Conditions'
        : 'Please read the entire Terms and Conditions before accepting';
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _hasScrolledToEnd ? _handleAcceptance : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            buttonText,
        textAlign: TextAlign.center,
      ),
        ),
      ),
    );
  }
}
