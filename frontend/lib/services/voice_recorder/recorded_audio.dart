import 'dart:typed_data';

class RecordedAudio {
  final Uint8List bytes;
  final String mimeType;
  final int durationSeconds;
  final String? blobUrl;

  const RecordedAudio({
    required this.bytes,
    required this.mimeType,
    required this.durationSeconds,
    this.blobUrl,
  });

  String get formattedDuration {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get sizeInBytes => bytes.lengthInBytes;

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
  }
}
