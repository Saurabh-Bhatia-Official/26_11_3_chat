import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_picker_helper.dart';
import '../services/permission_service.dart';
import 'camera_capture_dialog.dart';
import 'glass_container.dart';

class CustomImagePickerItem {
  final Uint8List bytes;
  final String name;
  final int size;
  final String extension;
  final String? path;

  CustomImagePickerItem({
    required this.bytes,
    required this.name,
    required this.size,
    required this.extension,
    this.path,
  });

  PickedFileData toPickedFileData() {
    return PickedFileData(
      bytes: bytes,
      name: name,
      size: size,
      extension: extension,
    );
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class CustomImagePickerDialog extends StatefulWidget {
  final bool allowMultiple;
  final int maxImages;
  final String title;
  final List<String> allowedExtensions;
  final int maxFileSizeMB;

  const CustomImagePickerDialog({
    super.key,
    this.allowMultiple = false,
    this.maxImages = 5,
    this.title = 'Select Image',
    this.allowedExtensions = const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    this.maxFileSizeMB = 15,
  });

  /// Static helper for single image selection
  static Future<PickedFileData?> pickSingleImage(
    BuildContext context, {
    String title = 'Select Image',
    List<String>? allowedExtensions,
  }) async {
    final results = await showDialog<List<PickedFileData>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomImagePickerDialog(
        allowMultiple: false,
        title: title,
        allowedExtensions: allowedExtensions ?? const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      ),
    );
    if (results != null && results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  /// Static helper for multiple image selection
  static Future<List<PickedFileData>> pickMultipleImages(
    BuildContext context, {
    String title = 'Select Images',
    int maxImages = 5,
    List<String>? allowedExtensions,
  }) async {
    final results = await showDialog<List<PickedFileData>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomImagePickerDialog(
        allowMultiple: true,
        maxImages: maxImages,
        title: title,
        allowedExtensions: allowedExtensions ?? const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      ),
    );
    return results ?? [];
  }

  @override
  State<CustomImagePickerDialog> createState() => _CustomImagePickerDialogState();
}

class _CustomImagePickerDialogState extends State<CustomImagePickerDialog> {
  final List<CustomImagePickerItem> _loadedImages = [];
  final Set<int> _selectedIndexIndices = {};
  bool _isLoading = false;
  String? _warningMessage;
  CustomImagePickerItem? _previewItem;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndBrowse(silent: true);
  }

  Future<void> _requestPermissionAndBrowse({bool silent = false}) async {
    final hasPermission = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: !silent,
    );

    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _warningMessage =
              'Photos & storage permission is required to browse device images. You can still use "Browse Files" or "Take Photo".';
        });
      }
      return;
    }

    if (!silent) {
      _browseGalleryViaPicker();
    }
  }

  Future<void> _browseGalleryViaPicker() async {
    setState(() {
      _isLoading = true;
      _warningMessage = null;
    });

    try {
      final picker = ImagePicker();
      if (widget.allowMultiple) {
        final pickedList = await picker.pickMultiImage(
          imageQuality: 88,
          maxWidth: 1600,
          maxHeight: 1600,
        );

        for (final file in pickedList) {
          await _processAndAddFile(file.name, await file.readAsBytes(), file.path);
        }
      } else {
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 88,
          maxWidth: 1600,
          maxHeight: 1600,
        );

        if (file != null) {
          await _processAndAddFile(file.name, await file.readAsBytes(), file.path);
        }
      }
    } catch (e) {
      debugPrint('[CustomImagePicker] Gallery error, trying file picker fallback: $e');
      _browseFileStorage();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _browseFileStorage() async {
    setState(() {
      _isLoading = true;
      _warningMessage = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.allowedExtensions,
      );

      if (result.isNotEmpty) {
        for (final f in result) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            await _processAndAddFile(f.name, bytes, f.path);
          }
        }
      }
    } catch (e) {
      debugPrint('[CustomImagePicker] FilePicker error: $e');
      if (mounted) {
        setState(() {
          _warningMessage = 'Error accessing device files: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _takePhotoWithCamera() async {
    final capture = await CameraCaptureHelper.captureWithCamera(context);
    if (capture != null && capture.bytes.isNotEmpty) {
      await _processAndAddFile(capture.filename, capture.bytes, null);
    }
  }

  Future<void> _processAndAddFile(String rawName, Uint8List bytes, String? path) async {
    if (bytes.isEmpty) {
      if (mounted) {
        setState(() {
          _warningMessage = 'Warning: Selected file is empty or corrupted.';
        });
      }
      return;
    }

    final ext = (rawName.contains('.') ? rawName.split('.').last : 'png').toLowerCase();

    // 1. Validate file extension
    if (!widget.allowedExtensions.contains(ext) && ext != 'jpeg' && ext != 'jpg') {
      if (mounted) {
        setState(() {
          _warningMessage =
              'Warning: Unsupported image format ".$ext". Allowed formats: ${widget.allowedExtensions.join(', ')}.';
        });
      }
      return;
    }

    // 2. Validate file size (maxFileSizeMB)
    final maxBytes = widget.maxFileSizeMB * 1024 * 1024;
    if (bytes.lengthInBytes > maxBytes) {
      if (mounted) {
        setState(() {
          _warningMessage =
              'Warning: Image exceeds maximum allowed size of ${widget.maxFileSizeMB} MB (${(bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB).';
        });
      }
      return;
    }

    final item = CustomImagePickerItem(
      bytes: bytes,
      name: rawName,
      size: bytes.lengthInBytes,
      extension: ext,
      path: path,
    );

    if (mounted) {
      setState(() {
        _warningMessage = null;
        _loadedImages.insert(0, item);
        final newIndex = 0;
        if (!widget.allowMultiple) {
          _selectedIndexIndices.clear();
          _selectedIndexIndices.add(newIndex);
        } else {
          if (_selectedIndexIndices.length < widget.maxImages) {
            _selectedIndexIndices.add(newIndex);
          }
        }
        _previewItem = item;
      });
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (!widget.allowMultiple) {
        _selectedIndexIndices.clear();
        _selectedIndexIndices.add(index);
        _previewItem = _loadedImages[index];
      } else {
        if (_selectedIndexIndices.contains(index)) {
          _selectedIndexIndices.remove(index);
        } else {
          if (_selectedIndexIndices.length >= widget.maxImages) {
            _warningMessage = 'Maximum of ${widget.maxImages} images can be selected at once.';
            return;
          }
          _selectedIndexIndices.add(index);
          _previewItem = _loadedImages[index];
        }
      }
    });
  }

  void _confirmSelection() {
    if (_selectedIndexIndices.isEmpty) return;

    final List<PickedFileData> selectedFiles = [];
    for (final idx in _selectedIndexIndices) {
      if (idx < _loadedImages.length) {
        selectedFiles.add(_loadedImages[idx].toPickedFileData());
      }
    }

    Navigator.of(context).pop(selectedFiles);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selectedIndexIndices.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF090D16),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 1. Top Header Bar
              _buildHeaderBar(),

              // 2. Warning / Error Banner (if any)
              if (_warningMessage != null) _buildWarningBanner(),

              // 3. Quick Action Buttons Bar
              _buildQuickActionsBar(),

              // 4. Main Gallery & Preview Area
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                      )
                    : _loadedImages.isEmpty
                        ? _buildEmptyState()
                        : _buildImagesGridAndPreview(),
              ),

              // 5. Bottom Confirm / Cancel Actions
              _buildBottomControlsBar(selectedCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library_rounded, color: Color(0xFF06B6D4), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.allowMultiple
                      ? 'Select up to ${widget.maxImages} photos (${widget.allowedExtensions.join(", ").toUpperCase()})'
                      : 'Choose an image from gallery, camera, or storage',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          if (widget.allowMultiple && _selectedIndexIndices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF06B6D4)),
              ),
              child: Text(
                '${_selectedIndexIndices.length}/${widget.maxImages}',
                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Cancel',
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _warningMessage!,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.white54),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _warningMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D131F),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF06B6D4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                ),
              ),
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('Open Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _browseGalleryViaPicker,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
              ),
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _takePhotoWithCamera,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                ),
              ),
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _browseFileStorage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, size: 44, color: Color(0xFF06B6D4)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Images Selected',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "Open Gallery", "Camera", or "Files" above to pick photos from your device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Browse Device Gallery'),
              onPressed: _browseGalleryViaPicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesGridAndPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 420 ? 3 : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: _loadedImages.length,
          itemBuilder: (context, index) {
            final item = _loadedImages[index];
            final isSelected = _selectedIndexIndices.contains(index);

            return InkWell(
              onTap: () => _toggleSelection(index),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131D2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF06B6D4) : Colors.white10,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Image Thumbnail
                    Positioned.fill(
                      child: Image.memory(
                        item.bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white38),
                        ),
                      ),
                    ),

                    // Bottom info gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                        child: Text(
                          '${item.name} • ${item.formattedSize}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),

                    // Top Selection Indicator Badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF06B6D4) : Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white60,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomControlsBar(int selectedCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 13)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              selectedCount == 0
                  ? 'Select Image'
                  : (widget.allowMultiple ? 'Attach ($selectedCount)' : 'Use Image'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: selectedCount > 0 ? _confirmSelection : null,
          ),
        ],
      ),
    );
  }
}
