import 'package:flutter/material.dart';

/// Centralized cloud-hosted game assets (banners, thumbnails, and interactive dice)
class GameCloudAssets {
  // High-Resolution Game Banners from Cloud CDN
  static const String chessBanner =
      'https://images.unsplash.com/photo-1529699211952-734e80c4d42b?w=600&auto=format&fit=crop&q=80';
  static const String chessThumb =
      'https://images.unsplash.com/photo-1586165368502-1bad197a6461?w=300&auto=format&fit=crop&q=80';

  static const String ludoBanner =
      'https://images.unsplash.com/photo-1610890716171-6b1bb98ffd09?w=600&auto=format&fit=crop&q=80';
  static const String ludoThumb =
      'https://images.unsplash.com/photo-1563941402622-4e7a488bcc57?w=300&auto=format&fit=crop&q=80';

  static const String snakesLaddersBanner =
      'https://images.unsplash.com/photo-1611891487122-207579d67d98?w=600&auto=format&fit=crop&q=80';
  static const String snakesLaddersThumb =
      'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300&auto=format&fit=crop&q=80';

  // Transparent Cloud Dice Assets (1 through 6)
  static const Map<int, String> diceImages = {
    1: 'https://upload.wikimedia.org/wikipedia/commons/c/c5/Dice-1.png',
    2: 'https://upload.wikimedia.org/wikipedia/commons/2/26/Dice-2.png',
    3: 'https://upload.wikimedia.org/wikipedia/commons/2/26/Dice-3.png',
    4: 'https://upload.wikimedia.org/wikipedia/commons/a/a9/Dice-4.png',
    5: 'https://upload.wikimedia.org/wikipedia/commons/6/6c/Dice-5.png',
    6: 'https://upload.wikimedia.org/wikipedia/commons/c/cd/Dice-6.png',
  };

  static String getBanner(String gameType) {
    switch (gameType.toUpperCase()) {
      case 'CHESS':
        return chessBanner;
      case 'LUDO':
        return ludoBanner;
      case 'SNAKES_AND_LADDERS':
      default:
        return snakesLaddersBanner;
    }
  }

  static String getThumbnail(String gameType) {
    switch (gameType.toUpperCase()) {
      case 'CHESS':
        return chessThumb;
      case 'LUDO':
        return ludoThumb;
      case 'SNAKES_AND_LADDERS':
      default:
        return snakesLaddersThumb;
    }
  }

  static String getDice(int value) {
    final v = value.clamp(1, 6);
    return diceImages[v] ?? diceImages[1]!;
  }
}

/// Helper widget to render cloud game images with loading states and graceful fallback
class CloudGameImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const CloudGameImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.sports_esports,
    this.fallbackColor = const Color(0xFF8B5CF6),
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFF1E293B),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [fallbackColor.withOpacity(0.3), const Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(fallbackIcon, color: fallbackColor, size: 24),
          ),
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
