import 'package:material_ui/material_ui.dart';

/// Circular arrow button for click-based navigation on web.
class NavArrowButton extends StatelessWidget {
  const NavArrowButton({
    super.key,
    required this.icon,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: foregroundColor, size: 28),
        ),
      ),
    );
  }
}
