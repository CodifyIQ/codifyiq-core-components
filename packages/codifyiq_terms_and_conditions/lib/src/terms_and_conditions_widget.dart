import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A widget for displaying and accepting terms and conditions with a scrollable
/// Markdown view and a button for acceptance.
///
/// The button displays a prompt to read the terms until the user has scrolled to
/// the end. Once scrolled, the button text changes to indicate acceptance.
///
/// ## Button Labels
///
/// The two button labels are deliberately short so they stay on a single line
/// on small screens and at large accessibility text scales. Override
/// [readPromptLabel] and [acceptLabel] to localize them or to match a host's
/// tone or required assent wording.
///
/// ## Processing State
///
/// Recording an acceptance is often a network call. Set [isProcessing] to
/// `true` while that request is in flight to disable the button and replace
/// its label with a progress indicator, preventing duplicate taps.
///
/// ## Usage
///
/// ```dart
/// TermsAndConditionsWidget(
///   termsContent: myMarkdownTerms,
///   isProcessing: _isRecordingAcceptance,
///   onAccepted: _recordAcceptance,
/// )
/// ```
class TermsAndConditionsWidget extends StatefulWidget {
  /// The optional header text to be displayed above the terms.
  /// Defaults to 'Terms and Conditions'.
  final String headerText;

  /// The Markdown content for the terms and conditions. If null, default text is used.
  final String? termsContent;

  /// Callback invoked when the terms are accepted.
  ///
  /// When null the acceptance button is disabled, matching the behaviour of
  /// Flutter's own buttons.
  final VoidCallback? onAccepted;

  /// Label shown on the acceptance button before the user has scrolled to the
  /// end of the terms, while the button is still gated.
  ///
  /// Defaults to `'Read to accept'`.
  final String readPromptLabel;

  /// Label shown on the acceptance button once the user has scrolled to the
  /// end of the terms.
  ///
  /// Defaults to `'Accept'`.
  final String acceptLabel;

  /// Whether an acceptance is currently being processed.
  ///
  /// When `true`, the button is disabled and its label is replaced with a
  /// [CircularProgressIndicator].
  final bool isProcessing;

  /// Creates a [TermsAndConditionsWidget].
  const TermsAndConditionsWidget({
    super.key,
    this.headerText = 'Terms and Conditions',
    this.termsContent,
    this.onAccepted,
    this.readPromptLabel = 'Read to accept',
    this.acceptLabel = 'Accept',
    this.isProcessing = false,
  });

  @override
  TermsAndConditionsWidgetState createState() =>
      TermsAndConditionsWidgetState();
}

/// The state for [TermsAndConditionsWidget], managing scroll position and acceptance state.
class TermsAndConditionsWidgetState extends State<TermsAndConditionsWidget> {
  bool _hasScrolledToEnd = false;
  final ScrollController _scrollController = ScrollController();

  /// The text colour the markdown was last rendered against.
  Color? _renderedTextColor;

  /// Bumped to re-key the markdown once a theme change has settled.
  int _themeEpoch = 0;

  /// Debounces [_themeEpoch] bumps until the theme stops animating.
  Timer? _themeSettleTimer;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final targetTextColor = Theme.of(context).colorScheme.onSurface;
    if (_renderedTextColor == null) {
      _renderedTextColor = targetTextColor;
      return;
    }
    if (_renderedTextColor == targetTextColor) return;

    // `gpt_markdown` bakes a resolved colour into its heading spans, so the
    // markdown has to be rebuilt to pick up a new theme. A theme change
    // animates, which would mean re-parsing the whole document on every frame
    // of the transition, so debounce: this fires once the colour stops
    // changing, and the rebuild then resolves the settled theme.
    _themeSettleTimer?.cancel();
    _themeSettleTimer = Timer(kThemeAnimationDuration, () {
      if (!mounted) return;
      setState(() {
        _renderedTextColor = Theme.of(context).colorScheme.onSurface;
        _themeEpoch++;
      });
    });
  }

  @override
  void didUpdateWidget(covariant TermsAndConditionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.termsContent == widget.termsContent) return;

    // New terms have not been read. Close the gate and return to the top so
    // the user cannot accept a document they were never shown.
    setState(() {
      _hasScrolledToEnd = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _checkScrollability();
    });
  }

  @override
  void dispose() {
    _themeSettleTimer?.cancel();
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

    final position = _scrollController.position;

    // A viewport that has not been measured yet also reports a zero scroll
    // extent, which is indistinguishable from terms that genuinely fit. Wait
    // for real dimensions rather than latching the gate open on a transient
    // layout — the flag is one-way, so a wrong answer here is permanent.
    if (!position.haveDimensions || position.viewportDimension <= 0) return;

    final maxScrollExtent = position.maxScrollExtent;
    final currentPosition = position.pixels;

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

  /// Whether the acceptance button should be tappable.
  ///
  /// Acceptance requires the user to have reached the end of the terms, a
  /// callback to deliver the acceptance to, and no acceptance already in
  /// flight.
  bool get _canAccept =>
      _hasScrolledToEnd && widget.onAccepted != null && !widget.isProcessing;

  /// Handles button press and triggers the acceptance callback.
  void _handleAcceptance() {
    if (!_canAccept) return;
    widget.onAccepted!.call();
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
          // Re-keyed by [didChangeDependencies] once a theme change settles,
          // which is what forces `gpt_markdown` to re-resolve the colour it
          // bakes into heading spans. Keying on the live colour instead would
          // re-parse the document on every frame of the transition.
          child: GptMarkdown(
            key: ValueKey(_themeEpoch),
            widget.termsContent ?? _defaultTerms,
          ),
        ),
      ),
    );
  }

  /// Builds the acceptance button.
  ///
  /// The button text changes based on whether the user has scrolled to the end,
  /// and is replaced by a progress indicator while [TermsAndConditionsWidget.isProcessing]
  /// is `true`.
  Widget _buildAcceptanceButton(BuildContext context) {
    final buttonText = _hasScrolledToEnd
        ? widget.acceptLabel
        : widget.readPromptLabel;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _canAccept ? _handleAcceptance : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          // Built through a Builder so the indicator resolves the button's own
          // DefaultTextStyle rather than the page's.
          child: widget.isProcessing
              ? Builder(builder: _buildProcessingIndicator)
              : Text(buttonText, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  /// Builds the in-flight indicator shown in place of the button label.
  ///
  /// Sized from the text scale so the button keeps the height it has when it
  /// shows a label, and tinted with the button's own foreground colour so it
  /// matches the label it replaces, including any `filledButtonTheme` a host
  /// has applied. [context] must therefore come from inside the button.
  Widget _buildProcessingIndicator(BuildContext context) {
    final size = MediaQuery.textScalerOf(context).scale(20);
    return SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: DefaultTextStyle.of(context).style.color,
      ),
    );
  }
}
