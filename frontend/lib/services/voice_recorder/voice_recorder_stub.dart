import 'recorded_audio.dart';

class VoiceRecorderService {
  static bool get isSupported => false;

  static Future<bool> requestPermission() async => false;

  static Future<void> startRecording() async {
    throw Exception('The MediaRecorder API is supported in web browser environments.');
  }

  static Future<RecordedAudio?> stopRecording() async => null;

  static Future<void> cancelRecording() async {}

  static void playAudio(
    String audioUrl, {
    void Function()? onEnded,
    void Function(Duration current, Duration total)? onProgress,
  }) {}

  static void pauseAudio() {}

  static void resumeAudio() {}

  static void stopAudio() {}

  static bool get isAudioPlaying => false;
}
