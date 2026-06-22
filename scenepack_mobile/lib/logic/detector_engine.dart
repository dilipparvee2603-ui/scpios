import 'dart:io';
import 'dart:async';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class DetectorEngine {
  /// Batch Frame Extraction for Review.
  /// Extracts frames to a temp folder and returns the list of file paths.
  /// Does NOT save to gallery yet (User will select).
  static Future<List<String>> extractFramesForReview({
    required String videoPath,
    required double fps,
    required double startTime,
    required double endTime,
    required Function(int) onProgress,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String exportPath = "${tempDir.path}/frame_review_${DateTime.now().millisecondsSinceEpoch}";
    
    final Directory packDir = Directory(exportPath);
    await packDir.create(recursive: true);

    final double duration = endTime - startTime;
    final String proCommand = "-ss $startTime -t $duration -i \"$videoPath\" -vf \"fps=$fps,scale=720:-1\" -q:v 2 \"$exportPath/frame_%04d.jpg\"";
    
    print("📸 FRAME EXTRACTION FOR REVIEW: $proCommand");
    
    final session = await FFmpegKit.execute(proCommand);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final List<String> paths = packDir.listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toList();
      paths.sort(); // Ensure order
      onProgress(100);
      return paths;
    }
    return [];
  }

  /// The "Proper" Native Scene Detection Engine (Dual-Pass Edition)
  static Future<List<Map<String, dynamic>>> detectScenes({
    required String videoPath,
    required double threshold, // Ignoring this for fixed dual-pass as requested
    required Function(int) onProgress,
    required Function(double) onAspectRatio,
  }) async {
    final List<Map<String, dynamic>> scenes = [];
    try {
      final Directory tempDir = await getTemporaryDirectory();
      // Use unique session timestamp to completely prevent file locking conflicts and cache collisions
      final String thumbPath = "${tempDir.path}/thumbnails_${DateTime.now().millisecondsSinceEpoch}";
      
      final Directory thumbsDir = Directory(thumbPath);
      await thumbsDir.create(recursive: true);

      final probeSession = await FFprobeKit.getMediaInformation(videoPath);
      final mediaInfo = probeSession.getMediaInformation();
      final double totalDuration = double.tryParse(mediaInfo?.getDuration() ?? "0") ?? 0;

      double aspectRatio = 16 / 9;
      final streams = mediaInfo?.getStreams();
      if (streams != null && streams.isNotEmpty) {
        try {
          final width = streams[0].getWidth() ?? 1280;
          final height = streams[0].getHeight() ?? 720;
          aspectRatio = width / height;
          onAspectRatio(aspectRatio);
        } catch (e) {
          print("⚠️ Warning: Probing aspect ratio failed: $e");
        }
      }

      // Helper to parse timestamps from FFmpeg showinfo logs
      Future<List<double>> parseCuts(dynamic session) async {
        final List<double> cuts = [];
        final logs = await session.getLogs();
        final RegExp timeRegex = RegExp(r"pts_time:(\d+\.?\d*)");
        for (var log in logs) {
          final match = timeRegex.firstMatch(log.getMessage());
          if (match != null) {
            cuts.add(double.parse(match.group(1)!));
          }
        }
        return cuts;
      }

      // SINGLE-PASS: Extract all cuts at the subtle threshold (with scaling & no audio) - 0% to 70%
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        if (totalDuration > 0) {
          final double timeInSeconds = stats.getTime() / 1000.0;
          final int p = ((timeInSeconds / totalDuration) * 70).toInt();
          onProgress(p.clamp(0, 70));
        }
      });
      final double subtleThreshold = (threshold - 0.05).clamp(0.01, 1.0);
      final String cmd = "-i \"$videoPath\" -vf \"select='gt(scene,$subtleThreshold)',showinfo\" -f null -";
      final session = await FFmpegKit.execute(cmd);
      final List<double> cutPoints = await parseCuts(session);
      FFmpegKitConfig.enableStatisticsCallback(null);

      // TEMPORAL STABILITY: Filter out micro-cuts < 0.5s
      cutPoints.sort();
      List<double> finalPoints = [];
      double lastPoint = 0.0;
      for (double pt in cutPoints) {
        if (pt - lastPoint >= 0.5) { // Harden 0.5s stability floor
          finalPoints.add(pt);
          lastPoint = pt;
        }
      }
      if (totalDuration > lastPoint) finalPoints.add(totalDuration);

      // Calculate target thumbnail dimensions (max 360px on larger side) to prevent UI thread memory lag/freeze
      int targetWidth = 360;
      int targetHeight = 202;
      if (aspectRatio >= 1.0) {
        targetWidth = 360;
        targetHeight = (360 / aspectRatio).round();
      } else {
        targetHeight = 360;
        targetWidth = (360 * aspectRatio).round();
      }
      if (targetWidth % 2 != 0) targetWidth++;
      if (targetHeight % 2 != 0) targetHeight++;

      // Phase 3: Thumbnailing (70% - 100%)
      double segmentStart = 0.0;
      for (int i = 0; i < finalPoints.length; i++) {
        double segmentEnd = finalPoints[i];
        double midPoint = (segmentStart + segmentEnd) / 2;
        final String thumbFile = "$thumbPath/scene_${i + 1}.jpg";
        await FFmpegKit.execute("-ss $midPoint -i \"$videoPath\" -vframes 1 -s ${targetWidth}x${targetHeight} -q:v 2 \"$thumbFile\"");
        scenes.add({'id': i, 'start': segmentStart, 'end': segmentEnd, 'thumbnail': thumbFile});
        segmentStart = segmentEnd;
        onProgress(70 + ((i / finalPoints.length) * 30).toInt());
      }
      onProgress(100);
      return scenes;
    } catch (e, stack) {
      print("🚨 Error in detectScenes: $e\n$stack");
      rethrow;
    }
  }

  /// Clinical Clip Export
  static Future<String> exportClip({
    required String input,
    required String output,
    required double start,
    required double end,
    required int crfValue,
    bool muteAudio = false,
    bool useHardwareAcceleration = false,
    Function(double)? onProgress,
  }) async {
    final File outFile = File(output);
    if (!await outFile.parent.exists()) await outFile.parent.create(recursive: true);
    
    final double duration = end - start;
    if (onProgress != null) {
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        if (duration > 0) {
          final double timeInSeconds = stats.getTime() / 1000.0;
          final double p = (timeInSeconds / duration).clamp(0.0, 1.0);
          onProgress(p);
        }
      });
    }

    try {
      final String audioCommand = muteAudio ? "-an" : "-c:a aac";
      
      String videoParams;
      if (useHardwareAcceleration) {
        // Switch to Android hardware accelerated H.264 MediaCodec encoding
        videoParams = "-c:v h264_mediacodec -b:v 8M";
      } else {
        // Elite 3-Tier Encoder Chassis (Standard libx264 software encoding)
        String preset = "medium";
        String codec = "libx264";
        String extraParams = "";

        if (crfValue == 0) {
          // LOSSLESS TRUE: Master Archiving (H.264 CRF 0 is mathematically perfect)
          codec = "libx264";
          preset = "slow";
          extraParams = ""; 
        } else if (crfValue <= 16) {
          // ELITE: Professional Delivery
          codec = "libx264";
          preset = "slow";
        } else {
          // BALANCED: Standard Efficiency
          codec = "libx264";
          preset = "medium";
        }
        videoParams = "-c:v $codec -crf $crfValue -preset $preset $extraParams";
      }

      final String command = "-y -ss $start -t $duration -i \"$input\" "
                             "$videoParams "
                             "-pix_fmt yuv420p -movflags +faststart "
                             "$audioCommand \"$output\"";
      
      // Clean up previous sessions to avoid memory leak build-up
      await FFmpegKitConfig.clearSessions();

      var session = await FFmpegKit.execute(command);
      var returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode) && useHardwareAcceleration) {
        final String hwLogs = await session.getAllLogsAsString() ?? '';
        print("⚠️ HARDWARE ACCELERATION FAILED (mediacodec). Falling back to software encoding (libx264). Logs:\n$hwLogs");

        // Software fallback parameters
        String fallbackPreset = "medium";
        String fallbackCodec = "libx264";
        String fallbackExtraParams = "";

        if (crfValue == 0) {
          fallbackPreset = "slow";
        } else if (crfValue <= 16) {
          fallbackPreset = "slow";
        }

        final String fallbackVideoParams = "-c:v $fallbackCodec -crf $crfValue -preset $fallbackPreset $fallbackExtraParams";
        final String fallbackCommand = "-y -ss $start -t $duration -i \"$input\" "
                                       "$fallbackVideoParams "
                                       "-pix_fmt yuv420p -movflags +faststart "
                                       "$audioCommand \"$output\"";

        await FFmpegKitConfig.clearSessions();
        session = await FFmpegKit.execute(fallbackCommand);
        returnCode = await session.getReturnCode();
      }

      if (ReturnCode.isSuccess(returnCode)) return output;

      final String failLogs = await session.getAllLogsAsString() ?? '';
      print("❌ FFmpeg Export Failed. Logs:\n$failLogs");
      throw Exception("FFmpeg Export Failed: $failLogs");
    } finally {
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
      }
      // Clear sessions from memory to avoid leakage
      await FFmpegKitConfig.clearSessions();
    }
  }

  /// Professional Frame Capture
  static Future<void> saveFrame({
    required String videoPath,
    required double timestamp,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String outPath = "${tempDir.path}/captured_frame_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final String command = "-ss $timestamp -i \"$videoPath\" -vframes 1 -q:v 2 \"$outPath\"";
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      await Gal.putImage(outPath, album: "Cfx Studios");
    } else {
      throw Exception("Frame Capture Failed");
    }
  }

  /// The "Elite Pulse Probe": Fast Temporal Calibration
  static Future<double> autoCalibrate(String videoPath, double totalDuration) async {
    double startTime = totalDuration * 0.25;
    double probeDuration = totalDuration > 10.0 ? 10.0 : totalDuration;
    
    int cuts = 0;
    final String cmd = "-ss $startTime -t $probeDuration -i \"$videoPath\" -vf \"select='gt(scene,0.1)',showinfo\" -f null -";
    
    print("🛰️ ELITE PULSE PROBE START: $cmd");
    final session = await FFmpegKit.execute(cmd);
    final String logs = await session.getAllLogsAsString() ?? '';
    
    // Count occurrences of "pts_time" in the showinfo logs
    final RegExp reg = RegExp(r"pts_time:");
    cuts = reg.allMatches(logs).length;

    double cutsPerSecond = cuts / probeDuration;
    print("🛰️ PULSE DATA: Cuts found: $cuts | Density: ${cutsPerSecond.toStringAsFixed(2)} cuts/sec");

    // NEW AGGRESSIVE RANGES
    if (cutsPerSecond > 0.8) {
      print("🛰️ CALIBRATION DECISION: ACTION (THRESHOLD 0.32)");
      return 0.32;
    }
    if (cutsPerSecond < 0.5) {
      print("🛰️ CALIBRATION DECISION: SENSITIVE (THRESHOLD 0.15)");
      return 0.15;
    }
    print("🛰️ CALIBRATION DECISION: BALANCED (THRESHOLD 0.23)");
    return 0.23;
  }
}

class CacheManager {
  /// Safely cleans up the session's temporary files and folders using fast, targeted non-recursive scans.
  static Future<void> clearDetectionCache({Set<String>? keepPaths}) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;

      // Scan only the top-level temporary directory non-recursively
      final List<FileSystemEntity> entities = tempDir.listSync(recursive: false);
      for (final FileSystemEntity entity in entities) {
        final String path = entity.path;
        final String name = path.split(Platform.pathSeparator).last;

        if (entity is File) {
          if (name.startsWith('captured_frame_')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        } else if (entity is Directory) {
          if (name.startsWith('frame_review_') || name.startsWith('thumbnails_') || name == 'thumbnails') {
            // Check if any file inside this directory is in keepPaths
            bool hasActiveFiles = false;
            if (keepPaths != null && keepPaths.isNotEmpty) {
              try {
                final List<FileSystemEntity> files = entity.listSync(recursive: true);
                for (var file in files) {
                  if (keepPaths.contains(file.path)) {
                    hasActiveFiles = true;
                    break;
                  }
                }
              } catch (_) {}
            }

            if (!hasActiveFiles) {
              try {
                await entity.delete(recursive: true);
              } catch (_) {}
            } else {
              // If it contains active files, clean up only the inactive files in it
              try {
                final List<FileSystemEntity> files = entity.listSync(recursive: false);
                for (var file in files) {
                  if (file is File && (keepPaths == null || !keepPaths.contains(file.path))) {
                    try {
                      await file.delete();
                    } catch (_) {}
                  }
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      print("Error clearing detection cache: $e");
    }
  }

  /// Returns true if the temporary folder exceeds 500MB.
  static Future<bool> isCacheTooLarge() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return false;

      int totalSize = 0;
      final List<FileSystemEntity> entities = tempDir.listSync(recursive: true);
      for (final FileSystemEntity entity in entities) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (_) {}
        }
      }

      // 500MB = 500 * 1024 * 1024 bytes
      const int limit = 500 * 1024 * 1024;
      return totalSize > limit;
    } catch (e) {
      print("Error checking cache size: $e");
      return false;
    }
  }
}
