// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'recorded_audio.dart';

class VoiceRecorderService {
  static html.MediaStream? _stream;
  static html.MediaRecorder? _recorder;
  static List<html.Blob> _chunks = [];
  static Completer<RecordedAudio?>? _stopCompleter;
  static DateTime? _recordStartTime;
  static html.AudioElement? _activeAudio;
  static StreamSubscription? _onEndedSub;
  static StreamSubscription? _onTimeUpdateSub;

  /// Returns true if the browser supports MediaRecorder and mediaDevices
  static bool get isSupported {
    try {
      return html.window.navigator.mediaDevices != null;
    } catch (_) {
      return false;
    }
  }

  /// Request microphone access permission from the browser
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
      for (final track in stream.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('Microphone permission request failed: $e');
      return false;
    }
  }

  /// Starts recording microphone audio using the browser's MediaRecorder API
  static Future<void> startRecording() async {
    if (!isSupported) {
      throw Exception('The MediaRecorder API is not supported in this browser.');
    }

    // Stop any in-progress recording or playback
    await cancelRecording();
    stopAudio();

    _chunks = [];
    _recordStartTime = DateTime.now();

    try {
      _stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      });
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('notallowed') || errStr.contains('permission') || errStr.contains('denied')) {
        throw Exception('Microphone permission was denied. Please allow microphone access in your browser settings to record voice messages.');
      } else if (errStr.contains('notfound') || errStr.contains('device')) {
        throw Exception('No microphone was found on this device. Please connect a microphone and try again.');
      } else {
        throw Exception('Failed to access microphone: $e');
      }
    }

    String mimeType = 'audio/webm';
    try {
      if (html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
        mimeType = 'audio/webm;codecs=opus';
      } else if (html.MediaRecorder.isTypeSupported('audio/webm')) {
        mimeType = 'audio/webm';
      } else if (html.MediaRecorder.isTypeSupported('audio/ogg;codecs=opus')) {
        mimeType = 'audio/ogg;codecs=opus';
      } else if (html.MediaRecorder.isTypeSupported('audio/mp4')) {
        mimeType = 'audio/mp4';
      }
    } catch (_) {}

    try {
      _recorder = html.MediaRecorder(_stream!, {'mimeType': mimeType});
    } catch (_) {
      // Fallback without explicit mimeType if browser options differ
      _recorder = html.MediaRecorder(_stream!);
    }

    _recorder!.addEventListener('dataavailable', (html.Event event) {
      try {
        final html.BlobEvent blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && blobEvent.data!.size > 0) {
          _chunks.add(blobEvent.data!);
        }
      } catch (e) {
        debugPrint('Error handling audio chunk: $e');
      }
    });

    _recorder!.addEventListener('stop', (html.Event event) async {
      try {
        final duration = _recordStartTime != null
            ? DateTime.now().difference(_recordStartTime!).inSeconds
            : 0;

        final cleanMime = mimeType.split(';').first;
        final blob = html.Blob(_chunks, cleanMime);
        final blobUrl = html.Url.createObjectUrl(blob);

        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        await reader.onLoadEnd.first;

        final rawResult = reader.result;
        Uint8List bytes;
        if (rawResult is ByteBuffer) {
          bytes = rawResult.asUint8List();
        } else if (rawResult is Uint8List) {
          bytes = rawResult;
        } else if (rawResult is List<int>) {
          bytes = Uint8List.fromList(rawResult);
        } else {
          bytes = Uint8List(0);
        }

        final audio = RecordedAudio(
          bytes: bytes,
          mimeType: cleanMime,
          durationSeconds: duration > 0 ? duration : 1,
          blobUrl: blobUrl,
        );

        if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
          _stopCompleter!.complete(audio);
        }
      } catch (e) {
        debugPrint('Error processing audio stop event: $e');
        if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
          _stopCompleter!.completeError(e);
        }
      } finally {
        _cleanupStream();
      }
    });

    // Start with 100ms timeslice to ensure continuous data gathering
    _recorder!.start(100);
  }

  /// Stops the active recording and returns the RecordedAudio payload
  static Future<RecordedAudio?> stopRecording() async {
    if (_recorder == null || _recorder!.state != 'recording') {
      _cleanupStream();
      return null;
    }

    _stopCompleter = Completer<RecordedAudio?>();
    _recorder!.stop();
    return _stopCompleter!.future;
  }

  /// Cancels and discards the active recording session
  static Future<void> cancelRecording() async {
    try {
      if (_recorder != null && _recorder!.state == 'recording') {
        _recorder!.stop();
      }
    } catch (_) {}
    _cleanupStream();
    _chunks.clear();
    _recordStartTime = null;
  }

  static void _cleanupStream() {
    if (_stream != null) {
      for (final track in _stream!.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      _stream = null;
    }
  }

  // ==========================================
  // REAL AUDIO PLAYBACK (PREVIEW & MESSAGES)
  // ==========================================

  /// Plays audio from a URL, Blob URL, or base64 data URI
  static void playAudio(
    String audioUrl, {
    void Function()? onEnded,
    void Function(Duration current, Duration total)? onProgress,
  }) {
    stopAudio();
    try {
      _activeAudio = html.AudioElement(audioUrl);
      _onEndedSub = _activeAudio!.onEnded.listen((_) {
        _onEndedSub?.cancel();
        _onTimeUpdateSub?.cancel();
        if (onEnded != null) onEnded();
      });

      _onTimeUpdateSub = _activeAudio!.onTimeUpdate.listen((_) {
        if (_activeAudio != null && onProgress != null) {
          final currSec = _activeAudio!.currentTime;
          final totSec = _activeAudio!.duration;
          final current = Duration(milliseconds: (currSec * 1000).toInt());
          final total = (!totSec.isNaN && !totSec.isInfinite)
              ? Duration(milliseconds: (totSec * 1000).toInt())
              : current;
          onProgress(current, total);
        }
      });

      _activeAudio!.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (onEnded != null) onEnded();
    }
  }

  static void pauseAudio() {
    try {
      _activeAudio?.pause();
    } catch (_) {}
  }

  static void resumeAudio() {
    try {
      _activeAudio?.play();
    } catch (_) {}
  }

  static void stopAudio() {
    try {
      _onEndedSub?.cancel();
      _onTimeUpdateSub?.cancel();
      if (_activeAudio != null) {
        _activeAudio!.pause();
        _activeAudio!.src = '';
        _activeAudio = null;
      }
    } catch (_) {}
  }

  static bool get isAudioPlaying {
    return _activeAudio != null && !_activeAudio!.paused;
  }
}
