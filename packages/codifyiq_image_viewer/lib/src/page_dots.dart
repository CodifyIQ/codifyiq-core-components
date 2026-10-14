import 'package:material_ui/material_ui.dart';

/// A row of dots marking the visible image among the others.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.color,
  });

  final int count;
  final int currentIndex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == currentIndex ? 10 : 6,
            height: i == currentIndex ? 10 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == currentIndex ? color : color.withValues(alpha: 0.38),
            ),
          ),
      ],
    );
  }
}
