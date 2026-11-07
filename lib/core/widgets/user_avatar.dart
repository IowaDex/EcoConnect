import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Round avatar shared by the hero and the profile sheet. Shows the uploaded
/// picture when there is one, otherwise the person glyph.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.size,
    this.background = AppColors.mint,
    this.showBadge = false,
    this.onTap,
  });

  final String? photoUrl;
  final double size;
  final Color background;
  final bool showBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: size,
          width: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          child: _image(),
        ),
        if (showBadge)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.forest,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cream, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: AppColors.creamBright,
              ),
            ),
          ),
      ],
    );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }

  Widget _image() {
    final url = photoUrl;
    if (url == null || url.isEmpty) return _placeholder;

    if (url.startsWith('data:')) {
      try {
        return Image.memory(
          base64Decode(url.substring(url.indexOf(',') + 1)),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder,
        );
      } catch (_) {
        return _placeholder;
      }
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder,
    );
  }

  Widget get _placeholder =>
      Icon(Icons.person, size: size * 0.48, color: AppColors.forest);
}


