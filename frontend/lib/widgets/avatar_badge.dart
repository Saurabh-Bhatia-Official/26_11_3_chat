import 'package:flutter/material.dart';

class AvatarBadge extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final bool isOnline;
  final bool showBadge;
  final int? safetyScore;

  const AvatarBadge({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
    this.isOnline = true,
    this.showBadge = true,
    this.safetyScore,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: radius * 0.75,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : null,
        ),
        if (showBadge && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.65,
              height: radius * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981), // Emerald green online
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
