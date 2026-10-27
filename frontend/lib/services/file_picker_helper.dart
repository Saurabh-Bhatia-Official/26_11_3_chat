import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_image_picker_dialog.dart';

class PickedFileData {
  final Uint8List bytes;
  final String name;
  final int size;
  final String? extension;

  const PickedFileData({
    required this.bytes,
    required this.name,
    required this.size,
    this.extension,
  });

  String get dataUri {
    final ext = (extension ?? (name.contains('.') ? name.split('.').last : 'png')).toLowerCase();
    final mime = ext == 'png'
        ? 'image/png'
        : (ext == 'jpg' || ext == 'jpeg'
            ? 'image/jpeg'
            : (ext == 'webp'
                ? 'image/webp'
                : (ext == 'gif'
                    ? 'image/gif'
                    : (ext == 'svg'
                        ? 'image/svg+xml'
                        : (ext == 'pdf' ? 'application/pdf' : 'application/octet-stream')))));
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}

class FilePickerHelper {
  // Test mock overrides
  static Future<PickedFileData?> Function()? mockPickImage;
  static Future<PickedFileData?> Function()? mockPickFile;

  /// Picks an image file using CustomImagePickerDialog when context is provided, with graceful fallback across platforms
  static Future<PickedFileData?> pickImage({
    BuildContext? context,
    String title = 'Select Image',
    List<String>? allowedExtensions,
  }) async {
    if (mockPickImage != null) {
      return await mockPickImage!();
    }

    // 1. If context is provided and mounted, display the Custom-themed Image Picker Dialog
    if (context != null && context.mounted) {
      try {
        final customResult = await CustomImagePickerDialog.pickSingleImage(
          context,
          title: title,
          allowedExtensions: allowedExtensions,
        );
        if (customResult != null) {
          return customResult;
        }
      } catch (e) {
        debugPrint('[FilePickerHelper] CustomImagePicker notice: $e');
      }
    }

    // 2. Direct ImagePicker gallery fallback
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty) {
          final name = picked.name.isNotEmpty ? picked.name : 'image.png';
          final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'png';
          return PickedFileData(
            bytes: bytes,
            name: name,
            size: bytes.length,
            extension: ext,
          );
        }
      }
    } catch (e) {
      debugPrint('ImagePicker notice (falling back to FilePicker): $e');
    }

    // 3. Fallback to FilePicker.pickFiles across platforms
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final len = (await file.length()) ?? bytes.length;
        if (bytes.isNotEmpty) {
          return PickedFileData(
            bytes: bytes,
            name: file.name,
            size: len,
            extension: file.extension?.toLowerCase(),
          );
        }
      }
    } catch (e) {
      debugPrint('FilePicker pickImage error: $e');
    }

    return null;
  }

  /// Picks multiple images using CustomImagePickerDialog with fallback
  static Future<List<PickedFileData>> pickMultipleImages({
    BuildContext? context,
    String title = 'Select Images',
    int maxImages = 5,
    List<String>? allowedExtensions,
  }) async {
    if (context != null && context.mounted) {
      try {
        return await CustomImagePickerDialog.pickMultipleImages(
          context,
          title: title,
          maxImages: maxImages,
          allowedExtensions: allowedExtensions,
        );
      } catch (e) {
        debugPrint('[FilePickerHelper] Custom multiple picker notice: $e');
      }
    }

    final single = await pickImage(context: context, allowedExtensions: allowedExtensions);
    return single != null ? [single] : [];
  }

  /// Picks any document or file using FilePicker.pickFiles
  static Future<PickedFileData?> pickDocument({List<String>? allowedExtensions}) async {
    if (mockPickFile != null) {
      return await mockPickFile!();
    }

    try {
      final files = await FilePicker.pickFiles(
        type: (allowedExtensions != null && allowedExtensions.isNotEmpty) ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final len = (await file.length()) ?? bytes.length;
        if (bytes.isNotEmpty) {
          return PickedFileData(
            bytes: bytes,
            name: file.name,
            size: len,
            extension: file.extension?.toLowerCase(),
          );
        }
      }
    } catch (e) {
      debugPrint('FilePicker pickDocument error: $e');
    }
    return null;
  }

  /// Picks audio files
  static Future<PickedFileData?> pickAudio() async {
    return pickDocument(allowedExtensions: ['webm', 'wav', 'mp3', 'ogg', 'm4a', 'aac']);
  }
}
