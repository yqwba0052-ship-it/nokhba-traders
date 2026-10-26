import 'package:flutter/material.dart';

/// Round avatar with a gradient ring; a person icon when there is no image.
class TraderAvatar extends StatelessWidget {
  const TraderAvatar({
    super.key,
    required this.url,
    this.size = 46,
    this.colors = const [Color(0xFFA78BFA), Color(0xFF60A5FA)],
  });

  final String? url;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.person_rounded,
      color: Colors.white,
      size: size * 0.58,
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: colors,
        ),
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.first.withValues(alpha: 0.8),
                colors.last.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: url == null
              ? placeholder
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  loadingBuilder: (_, image, progress) =>
                      progress == null ? image : placeholder,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}
