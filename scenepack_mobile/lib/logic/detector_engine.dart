import 'dart:io';
import 'dart:async';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class ClipExportTask {
  final double start;
  final double end;
  final String outputPath;

  ClipExportTask({
    required this.start,
    required this.end,
    required this.outputPath,
  });
}

class DetectorEngine {
  static void Function(String)? logCallback;
  static void _log(String msg) {
    if (logCallback != null) {
      logCallback!(msg);
    } else {
      print(msg);
    }
  }

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
    final String proCommand = "-ss $startTime -t $duration -an -sn -dn -i \"$videoPath\" -vf \"fps=$fps,scale=720:-2:flags=fast_bilinear\" -q:v 2 \"$exportPath/frame_%04d.jpg\"";
    
    _log("📸 FRAME EXTRACTION FOR REVIEW: $proCommand");
    
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
          _log("⚠️ Warning: Probing aspect ratio failed: $e");
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

      // SINGLE-PASS: Extract all cuts with fast 360p scaling and no audio/subtitles - 0% to 70%
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        if (totalDuration > 0) {
          final double timeInSeconds = stats.getTime() / 1000.0;
          final int p = ((timeInSeconds / totalDuration) * 70).toInt();
          onProgress(p.clamp(0, 70));
        }
      });
      final double subtleThreshold = (threshold - 0.05).clamp(0.01, 1.0);
      // Downscale stream to 360p with fast_bilinear to eliminate 36x redundant pixel decoding on 4K files
      final String cmd = "-an -sn -dn -i \"$videoPath\" -vf \"scale=360:-2:flags=fast_bilinear,select='gt(scene,$subtleThreshold)',showinfo\" -f null -";
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

      // Phase 3: High-Speed Thumbnailing (70% - 100%)
      double segmentStart = 0.0;
      final List<Map<String, dynamic>> sceneMeta = [];
      for (int i = 0; i < finalPoints.length; i++) {
        double segmentEnd = finalPoints[i];
        double midPoint = (segmentStart + segmentEnd) / 2;
        final String thumbFile = "$thumbPath/scene_${i + 1}.jpg";
        sceneMeta.add({
          'id': i,
          'start': segmentStart,
          'end': segmentEnd,
          'midPoint': midPoint,
          'thumbFile': thumbFile,
        });
        segmentStart = segmentEnd;
      }

      int completedThumbs = 0;
      for (var meta in sceneMeta) {
        final double midPoint = meta['midPoint'];
        final String thumbFile = meta['thumbFile'];
        
        // Fast keyframe seek without decoding intermediate GOP frames
        final String thumbCmd = "-ss $midPoint -noaccurate_seek -an -sn -dn -i \"$videoPath\" "
            "-frames:v 1 -vf \"scale=$targetWidth:$targetHeight:flags=fast_bilinear\" -q:v 3 \"$thumbFile\"";
        await FFmpegKit.execute(thumbCmd);

        // Fallback if fast seek did not yield a frame
        if (!File(thumbFile).existsSync()) {
          await FFmpegKit.execute("-ss $midPoint -an -sn -dn -i \"$videoPath\" -vframes 1 -s $targetWidth" "x$targetHeight -q:v 3 \"$thumbFile\"");
        }

        scenes.add({
          'id': meta['id'],
          'start': meta['start'],
          'end': meta['end'],
          'thumbnail': thumbFile,
        });
        
        completedThumbs++;
        onProgress(70 + ((completedThumbs / sceneMeta.length) * 30).toInt());
      }
      onProgress(100);
      return scenes;
    } catch (e, stack) {
      _log("🚨 Error in detectScenes: $e\n$stack");
      rethrow;
    }
  }

  static String get _hwEncoder => Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';

  /// Fast compatibility check for hardware acceleration on the input video.
  static Future<bool> checkHardwareSupport(String input) async {
    // Run a quick 1-frame dry run encoding test using platform hardware encoder
    // Writing to a null muxer avoids actual file write overhead.
    final String encoder = _hwEncoder;
    final String testCommand = "-y -ss 0 -t 0.05 -i \"$input\" -c:v $encoder -b:v 8M -profile:v baseline -an -f null -";
    await FFmpegKitConfig.clearSessions();
    final session = await FFmpegKit.execute(testCommand);
    final returnCode = await session.getReturnCode();
    final success = ReturnCode.isSuccess(returnCode);
    if (!success) {
      final logs = await session.getAllLogsAsString() ?? '';
      _log("⚠️ [Hardware Check] Compatibility test failed for $encoder on this device/resolution.\nLogs:\n$logs");
    } else {
      _log("✅ [Hardware Check] Hardware encoder ($encoder) successfully initialized for this resolution.");
    }
    return success;
  }

  /// High-Performance Batch Clip Exporter.
  /// Runs all exports in a single FFmpeg execution session.
  static Future<List<String>> exportClips({
    required String input,
    required List<ClipExportTask> tasks,
    required int crfValue,
    bool muteAudio = false,
    bool useHardwareAcceleration = false,
    Function(double)? onProgress,
  }) async {
    if (tasks.isEmpty) return [];

    // Ensure parent directories exist
    for (var task in tasks) {
      final File outFile = File(task.outputPath);
      if (!await outFile.parent.exists()) {
        await outFile.parent.create(recursive: true);
      }
    }

    // Check hardware support once at the beginning
    bool hardwareSupported = false;
    if (useHardwareAcceleration) {
      hardwareSupported = await checkHardwareSupport(input);
    }

    final List<String> results = [];
    final double totalDuration = tasks.fold(0.0, (sum, task) => sum + (task.end - task.start));
    double completedDuration = 0.0;

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final double duration = task.end - task.start;

      // Setup statistics callback for the current task
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((stats) {
          if (totalDuration > 0) {
            final double timeInSeconds = stats.getTime() / 1000.0;
            final double progressFraction = (completedDuration + timeInSeconds).clamp(0.0, totalDuration);
            final double p = progressFraction / totalDuration;
            onProgress(p);
          }
        });
      }

      try {
        String buildCommand(bool useHw) {
          final String audioCommand = muteAudio ? "-an" : "-map 0:a:0? -c:a copy";
          
          String videoParams;
          if (useHw) {
            final String encoder = _hwEncoder;
            videoParams = "-c:v $encoder -b:v 8M -profile:v baseline";
          } else {
            // For software fallback on mobile, use a faster preset (e.g. superfast) to prevent OOM / heat
            String preset = "superfast";
            String codec = "libx264";
            if (crfValue == 0) {
              preset = "veryfast";
            }
            videoParams = "-c:v $codec -crf $crfValue -preset $preset";
          }

          return "-y -ss ${task.start} -t $duration -i \"$input\" "
                 "-map 0:v:0 $videoParams -pix_fmt yuv420p $audioCommand \"${task.outputPath}\"";
        }

        final String mainCommand = buildCommand(hardwareSupported);
        _log("🚀 EXPORTING CLIP (${i + 1}/${tasks.length}): $mainCommand");

        await FFmpegKitConfig.clearSessions();
        var session = await FFmpegKit.execute(mainCommand);
        var returnCode = await session.getReturnCode();

        // Fallback to software encoding if hardware encoding fails
        if (!ReturnCode.isSuccess(returnCode) && hardwareSupported) {
          final String hwLogs = await session.getAllLogsAsString() ?? '';
          _log("⚠️ HARDWARE ACCELERATION FAILED for clip ${i + 1}. Falling back to software encoding (libx264).\nLogs:\n$hwLogs");

          final String fallbackCommand = buildCommand(false);
          _log("🚀 FALLBACK EXPORT START: $fallbackCommand");

          await FFmpegKitConfig.clearSessions();
          session = await FFmpegKit.execute(fallbackCommand);
          returnCode = await session.getReturnCode();
        }

        if (!ReturnCode.isSuccess(returnCode)) {
          final String failLogs = await session.getAllLogsAsString() ?? '';
          _log("❌ FFmpeg Export Failed for clip ${i + 1}. Logs:\n$failLogs");
          throw Exception("FFmpeg Export Failed: $failLogs");
        }

        results.add(task.outputPath);
        completedDuration += duration;

      } finally {
        if (onProgress != null) {
          FFmpegKitConfig.enableStatisticsCallback(null);
        }
        await FFmpegKitConfig.clearSessions();
      }
    }

    return results;
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
    final results = await exportClips(
      input: input,
      tasks: [ClipExportTask(start: start, end: end, outputPath: output)],
      crfValue: crfValue,
      muteAudio: muteAudio,
      useHardwareAcceleration: useHardwareAcceleration,
      onProgress: onProgress,
    );
    return results.first;
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
    
    _log("🛰️ ELITE PULSE PROBE START: $cmd");
    final session = await FFmpegKit.execute(cmd);
    final String logs = await session.getAllLogsAsString() ?? '';
    
    // Count occurrences of "pts_time" in the showinfo logs
    final RegExp reg = RegExp(r"pts_time:");
    cuts = reg.allMatches(logs).length;

    double cutsPerSecond = cuts / probeDuration;
    _log("🛰️ PULSE DATA: Cuts found: $cuts | Density: ${cutsPerSecond.toStringAsFixed(2)} cuts/sec");

    // NEW AGGRESSIVE RANGES
    if (cutsPerSecond > 0.8) {
      _log("🛰️ CALIBRATION DECISION: ACTION (THRESHOLD 0.32)");
      return 0.32;
    }
    if (cutsPerSecond < 0.5) {
      _log("🛰️ CALIBRATION DECISION: SENSITIVE (THRESHOLD 0.15)");
      return 0.15;
    }
    _log("🛰️ CALIBRATION DECISION: BALANCED (THRESHOLD 0.23)");
    return 0.23;
  }
}

class CacheManager {
  /// Calculates the total size of all temporary/cached files in bytes.
  static Future<int> getTotalCacheSizeBytes() async {
    int totalBytes = 0;
    try {
      final Directory tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final List<FileSystemEntity> entities = tempDir.listSync(recursive: true);
        for (final FileSystemEntity entity in entities) {
          if (entity is File) {
            try {
              totalBytes += await entity.length();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      DetectorEngine._log("Error calculating cache size: $e");
    }
    return totalBytes;
  }

  /// Formats bytes into a human-readable string (e.g. "124.5 MB" or "1.8 GB")
  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0.0 MB";
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;
    if (bytes >= gb) {
      return "${(bytes / gb).toStringAsFixed(2)} GB";
    } else {
      return "${(bytes / mb).toStringAsFixed(1)} MB";
    }
  }

  /// Clears 100% of temporary files:
  ///   • file_picker imported videos (which can be several GBs)
  ///   • thumbnails_* folders (scene detection thumbnails)
  ///   • frame_review_* folders (frame extraction preview sessions)
  ///   • production_clips/ (exported clip staging area)
  ///   • captured_frame_* files (single captured frames)
  ///   • FFmpegKit session logs and caches
  static Future<int> clearAllCache() async {
    int bytesFreed = await getTotalCacheSizeBytes();
    try {
      final Directory tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final List<FileSystemEntity> entities = tempDir.listSync(recursive: false);
        for (final FileSystemEntity entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            DetectorEngine._log("Could not delete ${entity.path}: $e");
          }
        }
      }
      await FFmpegKitConfig.clearSessions();
    } catch (e) {
      DetectorEngine._log("Error clearing all cache: $e");
    }
    return bytesFreed;
  }

  /// Clears temporary detection cache respecting active session files
  static Future<void> clearDetectionCache({Set<String>? keepPaths}) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;

      final List<FileSystemEntity> entities = tempDir.listSync(recursive: false);
      for (final FileSystemEntity entity in entities) {
        final String path = entity.path;
        final String name = path.split(Platform.pathSeparator).last;

        // ── Files ──────────────────────────────────────────────────────────
        if (entity is File) {
          final bool isTarget =
              name.startsWith('captured_frame_') || name == 'update.apk';
          if (isTarget) {
            try { await entity.delete(); } catch (_) {}
          }

        // ── Directories ────────────────────────────────────────────────────
        } else if (entity is Directory) {
          final bool isTarget =
              name.startsWith('thumbnails_') ||
              name == 'thumbnails' ||
              name.startsWith('frame_review_') ||
              name == 'production_clips';

          if (!isTarget) continue;

          // Respect keepPaths so active thumbnails aren't wiped mid-session
          bool hasActiveFiles = false;
          if (keepPaths != null && keepPaths.isNotEmpty) {
            try {
              for (var f in entity.listSync(recursive: true)) {
                if (keepPaths.contains(f.path)) { hasActiveFiles = true; break; }
              }
            } catch (_) {}
          }

          if (!hasActiveFiles) {
            try { await entity.delete(recursive: true); } catch (_) {}
          } else {
            // Partial clean – delete only files not in keepPaths
            try {
              for (var f in entity.listSync(recursive: false)) {
                if (f is File && (keepPaths == null || !keepPaths.contains(f.path))) {
                  try { await f.delete(); } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      DetectorEngine._log("Error clearing temp files: $e");
    }
  }

  /// Returns true if the temporary folder exceeds 500MB.
  static Future<bool> isCacheTooLarge() async {
    final int size = await getTotalCacheSizeBytes();
    return size > 500 * 1024 * 1024;
  }
}
