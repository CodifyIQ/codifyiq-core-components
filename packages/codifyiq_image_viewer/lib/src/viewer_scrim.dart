import 'package:material_ui/material_ui.dart';

/// A dark gradient behind controls laid over the image, fading out towards
/// the image.
class ViewerScrim extends StatelessWidget {
  const ViewerScrim({super.key, required this.fromTop, required this.child});

  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Colors.black54, Colors.transparent],
        ),
      ),
      child: child,
    );
  }
}
