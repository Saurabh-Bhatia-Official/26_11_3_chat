import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/permission_service.dart';

class CameraCaptureResult {
  final Uint8List bytes;
  final String filename;
  final String dataUri;

  const CameraCaptureResult({
    required this.bytes,
    required this.filename,
    required this.dataUri,
  });
}

class CameraCaptureHelper {
  // Test mock overrides
  static Future<CameraCaptureResult?> Function()? mockCapture;

  /// Full camera capture workflow:
  /// 1. Requests camera permission with rationale
  /// 2. Opens camera interface
  /// 3. Catches camera unavailability or errors gracefully
  /// 4. Shows live preview dialog allowing user to Confirm or Retake
  static Future<CameraCaptureResult?> captureWithCamera(
    BuildContext context, {
    VoidCallback? onFallbackGallery,
    VoidCallback? onFallbackPreset,
  }) async {
    if (mockCapture != null) {
      return await mockCapture!();
    }

    // Step 1: Permission flow
    final hasPermission = await PermissionService.requestPermission(
      context,
      AppPermissionType.camera,
      showRationale: true,
    );

    if (!hasPermission) {
      return null;
    }

    // Step 2 & 3: Camera interface and error handling
    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } on PlatformException catch (e) {
      debugPrint('Camera platform error: ${e.code} - ${e.message}');
      if (context.mounted) {
        await PermissionService.showUnavailableDialog(
          context,
          message: 'Camera could not be accessed (${e.message ?? e.code}). You can pick an image from the gallery or select an available preset icon.',
          onChooseGallery: onFallbackGallery,
          onChoosePreset: onFallbackPreset,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Camera unexpected error: $e');
      if (context.mounted) {
        await PermissionService.showUnavailableDialog(
          context,
          message: 'Unable to open camera on this device. Please select an image from gallery or choose an available preset icon.',
          onChooseGallery: onFallbackGallery,
          onChoosePreset: onFallbackPreset,
        );
      }
      return null;
    }

    if (pickedFile == null) {
      // User cancelled camera
      return null;
    }

    final bytes = await pickedFile.readAsBytes();
    if (bytes.isEmpty) {
      return null;
    }

    // Step 4: Preview dialog with Confirm & Retake options
    if (!context.mounted) return null;

    final confirmedResult = await showDialog<CameraCaptureResult?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CameraPreviewDialog(
        initialBytes: bytes,
        initialFilename: pickedFile!.name,
      ),
    );

    return confirmedResult;
  }
}

class CameraPreviewDialog extends StatefulWidget {
  final Uint8List initialBytes;
  final String initialFilename;

  const CameraPreviewDialog({
    super.key,
    required this.initialBytes,
    required this.initialFilename,
  });

  @override
  State<CameraPreviewDialog> createState() => _CameraPreviewDialogState();
}

class _CameraPreviewDialogState extends State<CameraPreviewDialog> {
  late Uint8List _currentBytes;
  late String _currentFilename;
  bool _isRetaking = false;

  @override
  void initState() {
    super.initState();
    _currentBytes = widget.initialBytes;
    _currentFilename = widget.initialFilename;
  }

  void _retakePhoto() async {
    setState(() => _isRetaking = true);
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file != null && mounted) {
        final newBytes = await file.readAsBytes();
        if (newBytes.isNotEmpty) {
          setState(() {
            _currentBytes = newBytes;
            _currentFilename = file.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error retaking photo: $e');
    } finally {
      if (mounted) setState(() => _isRetaking = false);
    }
  }

  void _confirmPhoto() {
    final mimeType = _currentFilename.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final base64Str = base64Encode(_currentBytes);
    final dataUri = 'data:$mimeType;base64,$base64Str';

    Navigator.of(context).pop(
      CameraCaptureResult(
        bytes: _currentBytes,
        filename: _currentFilename,
        dataUri: dataUri,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF06B6D4).withValues(alpha: 0.4), width: 1.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.photo_camera, color: Color(0xFF06B6D4), size: 22),
          SizedBox(width: 10),
          Text(
            'Preview Photo',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Captured Photo Preview Card
            Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
                border: Border.all(color: const Color(0xFF06B6D4), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(120),
                child: Image.memory(
                  _currentBytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Looking good! Confirm to use this photo as your icon or retake for a new shot.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
          icon: _isRetaking
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh, size: 16),
          label: const Text('Retake'),
          onPressed: _isRetaking ? null : _retakePhoto,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF06B6D4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Confirm & Use'),
          onPressed: _confirmPhoto,
        ),
      ],
    );
  }
}
