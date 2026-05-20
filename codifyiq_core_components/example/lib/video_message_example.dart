import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_video_message/flyer_chat_video_message.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'video_controller_helper_native.dart'
    if (dart.library.js_interop) 'video_controller_helper_web.dart';

// Local Flutter asset (works on all platforms).
const _demoVideoAsset = 'assets/videos/test.mp4';

// Publicly hosted nature video with audio (archive.org, CC BY-SA 4.0).
const _demoNetworkUrl =
    'https://archive.org/download/NatureStockVideo/IMG_9486.mp4';


const _selfId = 'demo-user';
const _otherId = 'demo-other';

/// Demo screen for [FlyerChatVideoMessage].
///
/// Shows the widget playing from two different source types — local asset and
/// network URL — plus common UI configurations.
class VideoMessageExample extends StatelessWidget {
  const VideoMessageExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Message')),
      body: _ProvidersWrapper(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: const [
            // ── Source types ────────────────────────────────────────────────
            _Section('Local asset — tap to play'),
            _LocalAssetSent(),
            _LocalAssetReceived(),
            _Section('Network URL — tap to play'),
            _NetworkSent(),
            _NetworkReceived(),
            // ── Widget feature demos ────────────────────────────────────────
            _Section('Custom play overlay — tap to play'),
            _CustomOverlay(),
            _Section('Timestamps hidden — tap to play'),
            _NoTimestamps(),
            _Section('Custom thumbnail builder — tap to play'),
            _CustomThumbnailBuilder(),
            _Section('Loading state (UI demo)'),
            _LoadingState(),
            _Section('Error state (UI demo)'),
            _ErrorState(),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Provider wrapper ──────────────────────────────────────────────────────────

class _ProvidersWrapper extends StatefulWidget {
  const _ProvidersWrapper({required this.child});
  final Widget child;

  @override
  State<_ProvidersWrapper> createState() => _ProvidersWrapperState();
}

class _ProvidersWrapperState extends State<_ProvidersWrapper> {
  late final InMemoryChatController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController(messages: []);
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ChatController>.value(value: _chatController),
        Provider<UserID>.value(value: _selfId),
        Provider<ChatTheme>.value(
          value: ChatTheme.fromThemeData(Theme.of(context)),
        ),
        Provider<DateFormat>.value(value: DateFormat.jm()),
      ],
      child: widget.child,
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

// ── Bubble row ────────────────────────────────────────────────────────────────

class _BubbleRow extends StatelessWidget {
  const _BubbleRow({required this.isSentByMe, required this.child});

  final bool isSentByMe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: child,
        ),
      ),
    );
  }
}

// ── Inline video player ───────────────────────────────────────────────────────

/// Wraps a [FlyerChatVideoMessage] and plays the video inline on tap.
///
/// Automatically selects the right [VideoPlayerController] factory based on
/// [VideoMessage.source]:
/// - `http://` / `https://` → [VideoPlayerController.networkUrl]
/// - bare path (native)     → [VideoPlayerController.file]
/// - anything else          → [VideoPlayerController.asset]
class _InlineVideoMessage extends StatefulWidget {
  const _InlineVideoMessage({
    required this.message,
    required this.index,
    this.overlay,
    this.thumbnailBuilder,
    this.showTime = true,
    this.showStatus = true,
  });

  final VideoMessage message;
  final int index;
  final Widget? overlay;
  final Widget Function(BuildContext, VideoMessage)? thumbnailBuilder;
  final bool showTime;
  final bool showStatus;

  @override
  State<_InlineVideoMessage> createState() => _InlineVideoMessageState();
}

class _InlineVideoMessageState extends State<_InlineVideoMessage> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  // Overrides widget.message when we auto-detect a duration.
  VideoMessage? _resolvedMessage;

  VideoMessage get _effectiveMessage => _resolvedMessage ?? widget.message;

  static String _formatDuration(Duration d) {
    if (d == Duration.zero) return '';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    // Probe duration in the background so the badge is visible on the
    // thumbnail before the user taps play.
    if (widget.message.metadata?['duration'] == null) {
      _probeDuration();
    }
  }

  Future<void> _probeDuration() async {
    final probe = _makeController();
    try {
      await probe.initialize();
      if (!mounted) return;
      final label = _formatDuration(probe.value.duration);
      if (label.isNotEmpty) {
        setState(() {
          _resolvedMessage = widget.message.copyWith(
            metadata: {...?widget.message.metadata, 'duration': label},
          );
        });
      }
    } catch (_) {
      // Duration unavailable — badge simply won't appear.
    } finally {
      await probe.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  /// Creates the appropriate controller for [VideoMessage.source].
  VideoPlayerController _makeController() {
    final src = widget.message.source;
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return VideoPlayerController.networkUrl(Uri.parse(src));
    }
    if (!kIsWeb && !src.startsWith('assets/')) {
      return fileController(src);
    }
    return VideoPlayerController.asset(src);
  }

  void _onTap() {
    final ctrl = _controller;
    if (ctrl != null && ctrl.value.isInitialized) {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
      return;
    }
    if (_initializing) return;
    setState(() => _initializing = true);

    final newCtrl = _makeController();
    newCtrl.initialize().then((_) {
      if (!mounted) {
        newCtrl.dispose();
        return;
      }
      setState(() {
        _controller = newCtrl;
        _initializing = false;
      });
      newCtrl.addListener(_onUpdate);
      newCtrl.play();
    }).catchError((Object e, StackTrace s) {
      debugPrint('[VideoDemo] initialize() error: $e');
      if (mounted) setState(() => _initializing = false);
      newCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final initialized = ctrl != null && ctrl.value.isInitialized;

    final msg = _effectiveMessage;
    final aspectRatio =
        (msg.width != null && msg.height != null && msg.width! > 0 && msg.height! > 0)
            ? msg.width! / msg.height!
            : 16 / 9;

    if (!initialized) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Stack(
          children: [
            FlyerChatVideoMessage(
              message: msg,
              index: widget.index,
              overlay: widget.overlay,
              thumbnailBuilder: widget.thumbnailBuilder,
              showTime: widget.showTime,
              showStatus: widget.showStatus,
            ),
            if (_initializing)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(ctrl),
            AnimatedOpacity(
              opacity: ctrl.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: const ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 48),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Local asset demos ─────────────────────────────────────────────────────────

class _LocalAssetSent extends StatelessWidget {
  const _LocalAssetSent();

  @override
  Widget build(BuildContext context) {
    return _BubbleRow(
      isSentByMe: true,
      child: Provider<UserID>.value(
        value: _selfId,
        child: _InlineVideoMessage(
          message: VideoMessage(
            id: 'demo-asset-sent',
            authorId: _selfId,
            source: _demoVideoAsset,
            width: 1280,
            height: 720,
            sentAt: DateTime.now().subtract(const Duration(minutes: 2)),
            metadata: const {
              'thumbnailUrl': 'https://picsum.photos/id/1015/640/360',
            },
          ),
          index: 0,
        ),
      ),
    );
  }
}

class _LocalAssetReceived extends StatelessWidget {
  const _LocalAssetReceived();

  @override
  Widget build(BuildContext context) {
    return _BubbleRow(
      isSentByMe: false,
      child: _InlineVideoMessage(
        message: VideoMessage(
          id: 'demo-asset-recv',
          authorId: _otherId,
          source: _demoVideoAsset,
          width: 1280,
          height: 720,
          sentAt: DateTime.now().subtract(const Duration(hours: 1)),
          metadata: const {
            'thumbnailUrl': 'https://picsum.photos/id/1043/640/360',
          },
        ),
        index: 1,
      ),
    );
  }
}

// ── Network URL demos ─────────────────────────────────────────────────────────

class _NetworkSent extends StatelessWidget {
  const _NetworkSent();

  @override
  Widget build(BuildContext context) {
    return _BubbleRow(
      isSentByMe: true,
      child: Provider<UserID>.value(
        value: _selfId,
        child: _InlineVideoMessage(
          message: VideoMessage(
            id: 'demo-network-sent',
            authorId: _selfId,
            source: _demoNetworkUrl,
            width: 1280,
            height: 720,
            sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
            metadata: const {
              'thumbnailUrl': 'https://picsum.photos/id/1035/640/360',
            },
          ),
          index: 2,
        ),
      ),
    );
  }
}

class _NetworkReceived extends StatelessWidget {
  const _NetworkReceived();

  @override
  Widget build(BuildContext context) {
    return _BubbleRow(
      isSentByMe: false,
      child: _InlineVideoMessage(
        message: VideoMessage(
          id: 'demo-network-recv',
          authorId: _otherId,
          source: _demoNetworkUrl,
          width: 1280,
          height: 720,
          sentAt: DateTime.now().subtract(const Duration(hours: 2)),
          metadata: const {
            'thumbnailUrl': 'https://picsum.photos/id/1056/640/360',
          },
        ),
        index: 3,
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
    return _BubbleRow(
      isSentByMe: true,
      child: Provider<UserID>.value(
        value: _selfId,
        child: _InlineVideoMessage(
          message: VideoMessage(
            id: 'demo-overlay',
            authorId: _selfId,
            source: _demoVideoAsset,
            width: 1280,
            height: 720,
            sentAt: DateTime.now(),
            metadata: const {
              'thumbnailUrl': 'https://picsum.photos/id/1035/640/360',
              'duration': '3:01',
            },
          ),
          index: 5,
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
      ),
    );
  }
}

class _NoTimestamps extends StatelessWidget {
  const _NoTimestamps();

  @override
  Widget build(BuildContext context) {
    return _BubbleRow(
      isSentByMe: false,
      child: _InlineVideoMessage(
        message: VideoMessage(
          id: 'demo-no-ts',
          authorId: _otherId,
          source: _demoVideoAsset,
          width: 16,
          height: 9,
          metadata: const {
            'thumbnailUrl': 'https://picsum.photos/id/1056/640/360',
          },
        ),
        index: 6,
        showTime: false,
        showStatus: false,
      ),
    );
  }
}

class _CustomThumbnailBuilder extends StatelessWidget {
  const _CustomThumbnailBuilder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _BubbleRow(
      isSentByMe: false,
      child: _InlineVideoMessage(
        message: VideoMessage(
          id: 'demo-custom-thumb',
          authorId: _otherId,
          source: _demoVideoAsset,
          width: 1280,
          height: 720,
          metadata: const {'duration': '0:12'},
        ),
        index: 7,
        thumbnailBuilder: (_, _) => Container(
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
    return _BubbleRow(
      isSentByMe: false,
      child: FlyerChatVideoMessage(
        message: VideoMessage(
          id: 'demo-loading',
          authorId: _otherId,
          source: 'https://example.com/not-yet-ready.mp4',
          width: 1280,
          height: 720,
        ),
        index: 8,
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
    return _BubbleRow(
      isSentByMe: false,
      child: FlyerChatVideoMessage(
        message: VideoMessage(
          id: 'demo-error',
          authorId: _otherId,
          source: 'https://example.com/missing.mp4',
          width: 1280,
          height: 720,
        ),
        index: 9,
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
