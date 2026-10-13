import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:material_ui/material_ui.dart';

/// Example page demonstrating the video viewer package.
///
/// Shows a row of [VideoThumbnailTile]s that each open a full-screen
/// [VideoViewerScreen], and an inline [VideoViewerWidget] below them. Action
/// callbacks surface feedback through a [SnackBar].
class VideoViewerExample extends StatelessWidget {
  /// Creates a [VideoViewerExample].
  const VideoViewerExample({super.key});

  // Short public sample clips from the Flutter API docs. They are served with
  // CORS headers and support range requests, so they play on web too.
  static final List<_DemoVideo> _demoVideos = [
    _DemoVideo(
      id: 'bee',
      filename: 'bee.mp4',
      duration: const Duration(seconds: 4),
    ),
    _DemoVideo(
      id: 'butterfly',
      filename: 'butterfly.mp4',
      duration: const Duration(seconds: 8),
    ),
  ];

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Pushes the full-screen viewer as its own route. Share and Download are
  // callbacks, so a real app would hand them to share_plus or a file saver.
  // The inline player below pauses itself once the viewer covers it.
  void _openViewer(BuildContext context, _DemoVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (screenContext) => VideoViewerScreen(
          source: video.source,
          title: video.filename,
          onShare: (sharePositionOrigin) =>
              _showSnack(screenContext, 'Share: ${video.filename}'),
          onDownload: () =>
              _showSnack(screenContext, 'Download: ${video.filename}'),
          actions: [
            VideoViewerAction(
              label: 'Copy link',
              icon: Icons.link,
              onSelected: () => _showSnack(screenContext, 'Link copied'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Viewer Example'),
        actions: const [BrightnessButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Tap a thumbnail to open the full-screen viewer.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final video in _demoVideos) ...[
                      if (video != _demoVideos.first) const SizedBox(width: 12),
                      Expanded(
                        child: VideoThumbnailTile(
                          thumbnail: video.thumbnail,
                          duration: video.duration,
                          onTap: () => _openViewer(context, video),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Or embed the player inline.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: VideoViewerWidget(source: _demoVideos.last.source),
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

class _DemoVideo {
  _DemoVideo({
    required this.id,
    required this.filename,
    required this.duration,
  });

  final String id;
  final String filename;
  final Duration duration;

  VideoSource get source => VideoSource.uri(
    Uri.parse(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/$filename',
    ),
  );

  // A frame of the clip, bundled with the example as its poster.
  ImageProvider get thumbnail => AssetImage('assets/images/video-$id.jpg');
}
