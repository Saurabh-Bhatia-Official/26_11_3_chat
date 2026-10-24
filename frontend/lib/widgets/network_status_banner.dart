import 'package:flutter/material.dart';
import '../services/network_service.dart';

/// App-wide banner that displays active connectivity and server availability conditions
class NetworkStatusBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkStatusBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkCondition>(
      valueListenable: NetworkService.conditionNotifier,
      builder: (context, condition, _) {
        if (condition == NetworkCondition.connected) {
          return const SizedBox.shrink();
        }

        final isNoInternet = condition == NetworkCondition.noInternet;
        final icon = isNoInternet ? Icons.wifi_off_rounded : Icons.dns_rounded;
        final message = isNoInternet
            ? NetworkService.msgNoInternet
            : NetworkService.msgServerUnavailable;
        final bgColor = isNoInternet ? const Color(0xFFB91C1C) : const Color(0xFFC2410C);

        return Material(
          color: bgColor,
          elevation: 4,
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await NetworkService.checkBackendHealth();
                      if (result == NetworkCondition.connected && onRetry != null) {
                        onRetry!();
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
