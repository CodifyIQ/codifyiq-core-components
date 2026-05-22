import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter/material.dart';

const _demoVideoSource = VideoSource.asset('assets/videos/test.mp4');
final _demoNetworkSource = VideoSource.network(
  Uri.parse('https://archive.org/download/NatureStockVideo/IMG_9486.mp4'),
);

/// Demo screen for [VideoMessageWidget].
class VideoMessageExample extends StatelessWidget {
  const VideoMessageExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Message')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: const [
          // ── Chat layout ───────────────────────────────────────────────────
          _Section('Sent / received — bubble grouping'),
          _ChatBubbleGroup(),
          // ── Source types ──────────────────────────────────────────────────
          _Section('Local asset — probeDuration: true (auto badge)'),
          _LocalAsset(),
          _Section('Network URL — duration passed explicitly'),
          _NetworkUrl(),
          // ── Widget feature demos ──────────────────────────────────────────
          _Section('Custom play overlay — tap to play'),
          _CustomOverlay(),
          _Section('Custom thumbnail builder — tap to play'),
          _CustomThumbnailBuilder(),
          _Section('Loading state (UI demo)'),
          _LoadingState(),
          _Section('Error state (UI demo)'),
          _ErrorState(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

// ── Chat layout demo ──────────────────────────────────────────────────────────

class _BubbleRow extends StatelessWidget {
  const _BubbleRow({required this.isSentByMe, required this.child});
  final bool isSentByMe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Align(
        alignment:
            isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: child,
        ),
      ),
    );
  }
}

/// Three consecutive messages demonstrating sent/received alignment and
/// bubble grouping corner radii.
class _ChatBubbleGroup extends StatelessWidget {
  const _ChatBubbleGroup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Received — first in group (all corners round)
        _BubbleRow(
          isSentByMe: false,
          child: VideoMessageWidget(
            source: _demoNetworkSource,
            thumbnailUrl: 'https://picsum.photos/id/1043/640/360',
            isSentByMe: false,
            isLastInGroup: false,
          ),
        ),
        // Received — last in group (bottom-left tail)
        _BubbleRow(
          isSentByMe: false,
          child: VideoMessageWidget(
            source: _demoNetworkSource,
            thumbnailUrl: 'https://picsum.photos/id/1035/640/360',
            isSentByMe: false,
            isLastInGroup: true,
          ),
        ),
        const SizedBox(height: 8),
        // Sent — last in group (bottom-right tail)
        _BubbleRow(
          isSentByMe: true,
          child: VideoMessageWidget(
            source: _demoVideoSource,
            thumbnailUrl: 'https://picsum.photos/id/1015/640/360',
            isSentByMe: true,
            isLastInGroup: true,
          ),
        ),
      ],
    );
  }
}

// ── Demo card ─────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    );
  }
}

// ── Source type demos ─────────────────────────────────────────────────────────

class _LocalAsset extends StatelessWidget {
  const _LocalAsset();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: VideoMessageWidget(
        source: _demoVideoSource,
        thumbnailUrl: 'https://picsum.photos/id/1015/640/360',
        probeDuration: true,
      ),
    );
  }
}

class _NetworkUrl extends StatelessWidget {
  const _NetworkUrl();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: VideoMessageWidget(
        source: _demoNetworkSource,
        thumbnailUrl: 'https://picsum.photos/id/1035/640/360',
        duration: '0:30',
      ),
    );
  }
}

// ── Feature demos ─────────────────────────────────────────────────────────────

class _CustomOverlay extends StatelessWidget {
  const _CustomOverlay();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: VideoMessageWidget(
        source: _demoVideoSource,
        thumbnailUrl: 'https://picsum.photos/id/1043/640/360',
        duration: '3:01',
        overlay: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_filled,
              color: cs.onPrimary,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomThumbnailBuilder extends StatelessWidget {
  const _CustomThumbnailBuilder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: VideoMessageWidget(
        source: _demoVideoSource,
        duration: '0:12',
        thumbnailBuilder: (_) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primaryContainer, cs.secondaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.movie_outlined,
              size: 48,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

// ── UI-only state demos ───────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: VideoMessageWidget(
        source: VideoSource.network(Uri.parse('https://example.com/not-yet-ready.mp4')),
        thumbnailUrl: 'https://via.placeholder.com/640x360',
        loadingBuilder: (_) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: VideoMessageWidget(
        source: VideoSource.network(Uri.parse('https://example.com/missing.mp4')),
        errorBuilder: (_) => ColoredBox(
          color: cs.errorContainer,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_outlined, color: cs.onErrorContainer),
                const SizedBox(height: 4),
                Text(
                  'Video unavailable',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
