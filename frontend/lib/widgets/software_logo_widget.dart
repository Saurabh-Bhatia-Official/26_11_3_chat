import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SoftwareLogoWidget extends StatelessWidget {
  final double size;
  final double iconSize;
  final double borderRadius;
  final bool showShadow;
  final EdgeInsetsGeometry padding;

  const SoftwareLogoWidget({
    super.key,
    this.size = 44,
    this.iconSize = 24,
    this.borderRadius = 12,
    this.showShadow = true,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: ApiService.customLogoDataNotifier,
      builder: (context, customLogoData, _) {
        if (customLogoData != null && customLogoData.isNotEmpty) {
          return _buildCustomLogo(customLogoData);
        }

        return ValueListenableBuilder<String>(
          valueListenable: ApiService.currentAppIconNotifier,
          builder: (context, iconId, _) {
            final iconOpt = AppIconHelper.getIcon(iconId);
            final Color iconColor = iconOpt['color'] as Color;
            final IconData iconData = iconOpt['icon'] as IconData;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size,
              height: size,
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColor,
                    iconColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: showShadow
                    ? [
                        BoxShadow(
                          color: iconColor.withOpacity(0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(iconData, color: Colors.white, size: iconSize),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomLogo(String dataOrUrl) {
    Widget imageWidget;

    if (dataOrUrl.startsWith('data:image')) {
      try {
        final commaIdx = dataOrUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? dataOrUrl.substring(commaIdx + 1) : dataOrUrl;
        final Uint8List bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
        );
      } catch (_) {
        imageWidget = _buildFallbackIcon();
      }
    } else {
      imageWidget = Image.network(
        dataOrUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackIcon(),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4), width: 1.5),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: imageWidget,
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: Icon(Icons.apps, color: Colors.white, size: iconSize),
    );
  }
}
