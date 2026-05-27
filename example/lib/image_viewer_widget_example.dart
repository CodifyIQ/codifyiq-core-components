import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';
import 'package:flutter/material.dart';

/// Example page demonstrating [ImageViewerWidget].
///
/// Renders a responsive grid of thumbnails. Tapping a thumbnail pushes the
/// full-screen viewer onto the navigation stack, opened to that image, with
/// a Hero transition from the thumbnail. Action menu callbacks surface
/// feedback through a [SnackBar].
class ImageViewerWidgetExample extends StatelessWidget {
  /// Creates an [ImageViewerWidgetExample].
  const ImageViewerWidgetExample({super.key});

  /// Demo images sourced from picsum.photos. Each picks a fixed id so the
  /// thumbnail and full image refer to the same photo.
  static const List<_DemoImage> _demoImages = [
    _DemoImage(id: 1015, title: 'Canyon river'),
    _DemoImage(id: 1025, title: 'Pup at rest'),
    _DemoImage(id: 1035, title: 'Waterfall rainbow'),
    _DemoImage(id: 1043, title: 'Valley park'),
    _DemoImage(id: 1056, title: 'Clouds'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Viewer Example')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive thumbnail grid: more columns as the viewport widens.
            final crossAxisCount = switch (constraints.maxWidth) {
              < 600 => 2,
              < 900 => 3,
              < 1200 => 4,
              _ => 5,
            };
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tap a thumbnail to open the full-screen viewer.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _demoImages.length,
                      itemBuilder: (context, index) {
                        final demo = _demoImages[index];
                        return _Thumbnail(
                          demo: demo,
                          onTap: () => _openViewer(context, index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    final items = _demoImages.map((d) => d.toItem()).toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (dialogContext) => ImageViewerWidget(
          items: items,
          initialIndex: initialIndex,
          onShare: (item, index, sharePositionOrigin) =>
              _showSnack(dialogContext, 'Share: ${item.title}'),
          onDownload: (item, index) =>
              _showSnack(dialogContext, 'Download: ${item.title}'),
          onDelete: (item, index) =>
              _showSnack(dialogContext, 'Delete: ${item.title}'),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// A demo image — pairs a picsum id with a display title.
class _DemoImage {
  const _DemoImage({required this.id, required this.title});

  final int id;
  final String title;

  String get fullUrl => 'https://picsum.photos/id/$id/1600/1200';
  String get thumbUrl => 'https://picsum.photos/id/$id/400/300';
  String get heroTag => 'image-viewer-demo-$id';

  ImageViewerItem toItem() =>
      ImageViewerItem.network(fullUrl, title: title, heroTag: heroTag);
}

/// Thumbnail card that animates into the full-screen viewer via [Hero].
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.demo, required this.onTap});

  final _DemoImage demo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: demo.heroTag,
              child: Image.network(
                demo.thumbUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Text(
                  demo.title,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
