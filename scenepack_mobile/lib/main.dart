import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'dart:async';
import 'logic/detector_engine.dart';
import 'logic/project_manager.dart';
import 'screens/app_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppState.log("FlutterError: ${details.exceptionAsString()}\n${details.stack}");
  };

  // Capture uncaught platform/Dart asynchronous errors
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppState.log("PlatformError: $error\n$stack");
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(prefs),
      child: const CFXApp(),
    ),
  );
}

class CFXApp extends StatelessWidget {
  const CFXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D0F14),
            primaryColor: const Color(0xFFFF3B30),
            dividerColor: Colors.white.withOpacity(0.02),
            cardColor: Colors.white.withOpacity(0.06),
          ),
          home: appState.isHomeLoading
              ? const AppLoadingScreen()
              : const AppNavigator(),
        );
      },
    );
  }
}

class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({super.key});
  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: Stack(
        children: [

          // Centered logo + pulse
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulse ring around logo
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF3B30).withOpacity(_pulseAnim.value * 0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Inner glow ring
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF3B30).withOpacity(_pulseAnim.value * 0.15),
                              width: 1,
                            ),
                          ),
                        ),
                        child!,
                      ],
                    );
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D24),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1A2540), width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        "CFX",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  "SCP",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Color(0xFFFF3B30),
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "STARTING UP...",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: Colors.white24,
                  ),
                ),
              ],
            ),
          ),

          // Bottom progress bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.white.withOpacity(0.03),
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFFF3B30).withOpacity(0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  static final List<String> developerLogs = [];
  
  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logLine = "[$timestamp] $message";
    developerLogs.add(logLine);
    if (developerLogs.length > 200) {
      developerLogs.removeAt(0); // keep last 200 logs to avoid memory bloat
    }
    debugPrint(logLine);
  }

  final SharedPreferences prefs;
  String? videoPath;
  List<Map<String, dynamic>> scenes = [];
  Set<int> selectedIndices = {};
  double progress = 0.0;
  double threshold = 0.23;
  double minSceneDuration = 0.5; // Production standard to avoid micro-cuts
  double aspectRatio = 16 / 9;

  // Frame Pack Fields
  double exportFps = 10.0;
  double videoFps = 30.0;
  double exportStartTime = 0.0;
  double exportEndTime = 10.0;
  double videoDuration = 0.0;
  double currentPlayerTime = 0.0;
  int selectedQualityIndex = 0; // Default to PRODUCTION
  bool muteAudio = true;       // Default to MUTED
  int exportCrf = 16;          
  bool useHardwareAcceleration = false;
  String calibrationStatus = "WAITING...";
  String status = "HOME"; // HOME, PICKER, PROCESSING, PREVIEW, CLIPS, REVIEW, EXPORT
  String toolMode = "DETECTION"; // DETECTION, FRAME_PACK
  
  List<String> reviewFrames = [];
  Set<int> selectedFrameIndices = {};
  int dailyScansUsed = 0;
  final int maxDailyScans = 5;
  List<String> lastExportedPaths = [];
  Map<String, Uint8List> clipMemoryBuffer = {};

  // Auto-Save Projects System
  List<ScenePackProject> projects = [];
  ScenePackProject? currentProject;

  Future<void> loadProjects() async {
    projects = await ProjectManager.loadAllProjects();
    notifyListeners();
  }

  Future<void> autoSaveProject() async {
    if (currentProject == null) return;
    currentProject!.scenes = scenes;
    currentProject!.selectedIndices = selectedIndices;
    currentProject!.duration = videoDuration;
    currentProject!.fps = videoFps;
    currentProject!.aspectRatio = aspectRatio;
    currentProject!.toolMode = toolMode;
    if (scenes.isNotEmpty && scenes[0]['thumbnail'] != null) {
      currentProject!.thumbnailPath = scenes[0]['thumbnail'];
    }
    await ProjectManager.saveProject(currentProject!);
    projects = await ProjectManager.loadAllProjects();
    notifyListeners();
  }

  Future<void> openProject(ScenePackProject proj) async {
    currentProject = proj;
    videoPath = proj.videoPath;
    scenes = List<Map<String, dynamic>>.from(proj.scenes);
    selectedIndices = Set<int>.from(proj.selectedIndices);
    videoDuration = proj.duration;
    videoFps = proj.fps;
    aspectRatio = proj.aspectRatio;
    toolMode = proj.toolMode;
    exportEndTime = videoDuration > 10.0 ? 10.0 : videoDuration;
    exportStartTime = 0.0;
    exportFps = videoFps;

    if (scenes.isNotEmpty) {
      status = "CLIPS";
    } else {
      status = "PREVIEW";
    }
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    await ProjectManager.deleteProject(id);
    if (currentProject?.id == id) {
      currentProject = null;
      videoPath = null;
      scenes = [];
      selectedIndices = {};
      status = "HOME";
    }
    await loadProjects();
  }

  bool isUnlimited = true;
  bool isTrialActive = false;
  int trialDaysRemaining = 0;
  bool hasPendingUpgrade = false;
  bool isTrialUsedOnAnotherEmail = false;
  
  bool get isUiLocked => false;
  
  String deviceId = "LOADING...";
  final String _salt = "CFX_ELITE_FORCE_2024";
  String appVersion = "v0.0.0";
  
  // News Feed / Broadcast System
  Map<String, dynamic>? broadcastData;
  bool isBroadcastLoading = false;

  // Update Hub Fields
  Map<String, dynamic>? updateData;
  bool isUpdateLoading = false;
  bool hasUpdate = false;
  bool hasUpdateNotification = false;
  double downloadProgress = 0.0;
  String updateStatus = "IDLE";
  bool isHomeLoading = true;
  bool hasShownTrialExpiredDialog = false;

  // Storage & Cache Optimization
  bool autoClearCache = true;
  String cacheSizeFormatted = "0.0 MB";
  int cacheSizeBytes = 0;

  Future<void> refreshCacheSize() async {
    cacheSizeBytes = await CacheManager.getTotalCacheSizeBytes();
    cacheSizeFormatted = CacheManager.formatBytes(cacheSizeBytes);
    notifyListeners();
  }

  Future<int> clearAllCache() async {
    final freedBytes = await CacheManager.clearAllCache();
    await ProjectManager.clearAllProjects();
    projects.clear();
    currentProject = null;
    videoPath = null;
    scenes = [];
    selectedIndices = {};
    selectedFrameIndices = {};
    await refreshCacheSize();
    notifyListeners();
    return freedBytes;
  }

  Future<void> setAutoClearCache(bool enabled) async {
    autoClearCache = enabled;
    await prefs.setBool('auto_clear_cache', enabled);
    notifyListeners();
  }

  void setHasShownTrialExpiredDialog(bool val) {
    hasShownTrialExpiredDialog = val;
    notifyListeners();
  }

  Future<void> _initApp() async {
    isHomeLoading = true;
    await _loadDeviceId();
    
    // Dynamic Version Probe
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appVersion = "v${packageInfo.version}";
    
    cloudFolderName = prefs.getString('cloud_folder_name') ?? "CFX_SCP_SYNC";
    autoClearCache = prefs.getBool('auto_clear_cache') ?? true;
    unawaited(refreshCacheSize());
    await _loadUsage();
    await loadProjects();
    
    isUnlimited = true;
    
    fetchBroadcast(); 
    checkForUpdates(silent: true);
    _initDrive(); // Silent Cloud Link (Fire-and-forget in background to prevent app startup lag)
    isHomeLoading = false;
    notifyListeners();
  }

   Future<void> _initDrive() async {
     try {
       final account = await _googleSignIn.signInSilently();
       if (account != null) {
         final httpClient = (await _googleSignIn.authenticatedClient())!;
         _driveApi = drive.DriveApi(httpClient);
         notifyListeners();
       }
     } catch (e) {
       debugPrint("DRIVE_SILENT_AUTH_ERROR: $e");
     }
   }

   // Cloud Sync Fields
   drive.DriveApi? _driveApi;
   drive.DriveApi? get driveApi => _driveApi;
   bool get isDriveConnected => _driveApi != null;
   String cloudFolderName = "CFX_SCP_SYNC";
   bool isCloudSyncing = false;
   double cloudProgress = 0.0;

   Future<void> checkForUpdates({bool silent = false}) async {
    if (!silent) {
      updateStatus = "CHECKING";
      isUpdateLoading = true;
      notifyListeners();
    }
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = 'https://gist.githubusercontent.com/dilipparvee2603-ui/3e590c9ad84e55f2c347d58c20870376/raw/gistfile4.txt?t=$timestamp';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        updateData = jsonDecode(response.body);
        final latestVer = updateData?['latest_version'] as String? ?? "0.0";
        
        // Surgical Version Extraction
        String currentClean = appVersion.replaceAll('v', '').split('+').first;
        String latestClean = latestVer.replaceAll('v', '').split('+').first;
        
        // Handle semantic 2.20.0 by taking first two parts
        List<String> currentParts = currentClean.split('.');
        List<String> latestParts = latestClean.split('.');
        
        double currentVal = double.tryParse("${currentParts[0]}.${currentParts.length > 1 ? currentParts[1] : '0'}") ?? 0.0;
        double latestVal = double.tryParse("${latestParts[0]}.${latestParts.length > 1 ? latestParts[1] : '0'}") ?? 0.0;
        
        hasUpdate = latestVal > currentVal;
        if (hasUpdate) hasUpdateNotification = true;
        updateStatus = hasUpdate ? "DOWNLOAD_READY" : "IDLE";
        if (!hasUpdate && !silent) {
          updateStatus = "UP_TO_DATE_FEEDBACK";
          Future.delayed(const Duration(seconds: 3), () {
            updateStatus = "IDLE";
            notifyListeners();
          });
        }
      }
    } catch (e) {
      debugPrint("Update Check Error: $e");
    } finally {
      isUpdateLoading = false;
      notifyListeners();
      
      if (!hasUpdate && !silent) {
        updateStatus = "UP_TO_DATE_FEEDBACK";
        notifyListeners();
        Future.delayed(const Duration(seconds: 3), () {
          updateStatus = "IDLE";
          notifyListeners();
        });
      }
    }
  }

  void clearUpdateNotification() {
    hasUpdateNotification = false;
    notifyListeners();
  }

  Future<void> downloadAndUpdate() async {
    if (updateData == null) return;
    final downloadUrl = updateData!['download_url'];
    if (downloadUrl == null) return;

    updateStatus = "DOWNLOADING";
    downloadProgress = 0.0;
    notifyListeners();

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final savePath = "${tempDir.path}/update.apk";

      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress = received / total;
            notifyListeners();
          }
        },
      );

      updateStatus = "COMPLETE";
      notifyListeners();
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        throw result.message;
      }
    } catch (e) {
      debugPrint("Download Error: $e");
      updateStatus = "DOWNLOAD_READY";
      notifyListeners();
      
      // SURGICAL ERROR FEEDBACK
      if (e.toString().contains("Permission")) {
         // Show specific permission instruction if needed
      }
    }
  }

   final GoogleSignIn _googleSignIn = GoogleSignIn(
     scopes: [
       'email',
       drive.DriveApi.driveFileScope,
     ],
   );
 
   Future<void> connectDrive() async {
     try {
       final account = await _googleSignIn.signIn();
       if (account != null) {
         final httpClient = (await _googleSignIn.authenticatedClient())!;
         _driveApi = drive.DriveApi(httpClient);
         notifyListeners();
       }
     } catch (e) {
       debugPrint("DRIVE_AUTH_ERROR: $e");
     }
   }
 
   Future<void> disconnectDrive() async {
     await _googleSignIn.signOut();
     _driveApi = null;
     notifyListeners();
   }
 
   Future<void> updateCloudFolderName(String name) async {
      cloudFolderName = name.isEmpty ? "CFX_SCP_SYNC" : name;
     final prefs = await SharedPreferences.getInstance();
     await prefs.setString('cloud_folder_name', cloudFolderName);
     notifyListeners();
   }

  Future<bool> syncToCloud(List<String> filePaths) async {
    if (_driveApi == null || filePaths.isEmpty) return false;
    isCloudSyncing = true;
    cloudProgress = 0.0;
    notifyListeners();
    
    try {
      // 1. Find or Create the CUSTOM Folder
      String? folderId = await _getOrCreateFolder(cloudFolderName);
      if (folderId == null) {
        isCloudSyncing = false;
        notifyListeners();
        return false;
      }

      // 2. Upload only the SELECTED files
      for (int i = 0; i < filePaths.length; i++) {
        final filePath = filePaths[i];
        final driveFile = drive.File();
        final fileName = path.basename(filePath);
        driveFile.name = fileName;
        driveFile.parents = [folderId];

        String mimeType = "application/octet-stream";
        if (fileName.toLowerCase().endsWith(".mp4")) mimeType = "video/mp4";
        if (fileName.toLowerCase().endsWith(".jpg")) mimeType = "image/jpeg";
        driveFile.mimeType = mimeType;

        final file = File(filePath);
        if (!await file.exists()) continue;
        final length = await file.length();
        final media = drive.Media(file.openRead(), length, contentType: mimeType);

        await _driveApi!.files.create(driveFile, uploadMedia: media);
        cloudProgress = (i + 1) / filePaths.length;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint("CLOUD_SYNC_ERROR: $e");
      return false;
    } finally {
      isCloudSyncing = false;
      notifyListeners();
    }
  }

  HttpServer? _localServer;
  String? localServerUrl;
  bool get isLocalServerRunning => _localServer != null;

  Future<void> startLocalServer() async {
    await stopLocalServer(); // Ensure any existing server is fully stopped first
    try {
      String? ip;
      final interfaces = await NetworkInterface.list();
      
      // 1. Try to find a Wi-Fi/Ethernet interface (typically en0, wlan0, eth0, etc.)
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains("wlan") || name.contains("wifi") || name.contains("en") || name.contains("eth") || name.contains("lan")) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              ip = addr.address;
              break;
            }
          }
        }
        if (ip != null) break;
      }
      
      // 2. Fallback to any non-loopback IPv4 address
      if (ip == null) {
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              ip = addr.address;
              break;
            }
          }
          if (ip != null) break;
        }
      }
      
      if (ip == null) {
        ip = "127.0.0.1";
      }

      // Try binding to port 8080, fallback to port 0 (any random free port)
      try {
        _localServer = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      } catch (_) {
        _localServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      }
      final port = _localServer!.port;
      localServerUrl = "http://$ip:$port";
      notifyListeners();

      _localServer!.listen((HttpRequest request) async {
        try {
          final uri = request.uri;
          if (uri.path == '/') {
            request.response.headers.contentType = ContentType.html;
            request.response.write(_buildServerHtml());
            await request.response.close();
          } else if (uri.path == '/favicon.ico') {
            request.response.statusCode = HttpStatus.noContent;
            await request.response.close();
          } else if (uri.path == '/download') {
            final fileName = uri.queryParameters['file'];
            if (fileName == null) {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.write("File not specified");
              await request.response.close();
              return;
            }

            String? targetPath;
            for (var p in lastExportedPaths) {
              if (path.basename(p) == fileName) {
                targetPath = p;
                break;
              }
            }

            if (targetPath == null) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write("File not found");
              await request.response.close();
              return;
            }

            final file = File(targetPath);
            if (!await file.exists()) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write("File does not exist on disk");
              await request.response.close();
              return;
            }

            request.response.headers.contentType = ContentType('video', 'mp4');
            request.response.headers.add('Content-Disposition', 'attachment; filename="$fileName"');
            request.response.headers.contentLength = await file.length();

            await file.openRead().pipe(request.response);
          } else if (uri.path == '/thumbnail') {
            final fileName = uri.queryParameters['file'];
            if (fileName == null) {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.write("File not specified");
              await request.response.close();
              return;
            }
            final thumbPath = getThumbnailPathForClip(fileName);
            if (thumbPath == null) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write("Thumbnail not found");
              await request.response.close();
              return;
            }
            final file = File(thumbPath);
            request.response.headers.contentType = ContentType('image', 'jpeg');
            request.response.headers.contentLength = await file.length();
            await file.openRead().pipe(request.response);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write("Not found");
            await request.response.close();
          }
        } catch (e) {
          debugPrint("Server error serving request: $e");
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint("Failed to start local server: $e");
      stopLocalServer();
    }
  }

  Future<void> stopLocalServer() async {
    if (_localServer != null) {
      await _localServer!.close(force: true);
      _localServer = null;
      localServerUrl = null;
      notifyListeners();
    }
  }

  String? getThumbnailPathForClip(String fileName) {
    try {
      final parts = fileName.split('_');
      if (parts.length >= 2 && parts[0] == 'clip') {
        final idx = int.tryParse(parts[1]);
        if (idx != null && idx >= 0 && idx < scenes.length) {
          final thumb = scenes[idx]['thumbnail'] as String?;
          if (thumb != null && File(thumb).existsSync()) {
            return thumb;
          }
        }
      }
    } catch (e) {
      debugPrint("Error getting thumbnail for $fileName: $e");
    }
    return null;
  }

  String _buildServerHtml() {
    final fileListHtml = lastExportedPaths.map((p) {
      final name = path.basename(p);
      final file = File(p);
      final sizeMb = file.existsSync() ? (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1) : "N/A";

      final hasThumb = getThumbnailPathForClip(name) != null;
      final thumbUrl = hasThumb ? '/thumbnail?file=${Uri.encodeComponent(name)}' : null;

      return '''
      <div class="file-card">
        <div class="file-preview">
          ${thumbUrl != null ? '<img src="$thumbUrl" class="clip-thumb" alt="Preview"/>' : '<div class="file-icon">Ã°Å¸Å½Â¬</div>'}
        </div>
        <div class="file-info">
          <div class="file-name">$name</div>
          <div class="file-size">$sizeMb MB</div>
        </div>
        <a href="/download?file=${Uri.encodeComponent(name)}" class="download-btn">DOWNLOAD</a>
      </div>
      ''';
    }).join('\n');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CFX SCP - Desktop Sync</title>
  <style>
    body {
      background-color: #090B10;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      margin: 0;
      padding: 40px 20px;
      display: flex;
      justify-content: center;
    }
    .container {
      width: 100%;
      max-width: 600px;
    }
    .header {
      margin-bottom: 40px;
      border-bottom: 1px solid #1E293B;
      padding-bottom: 20px;
    }
    .title {
      font-size: 32px;
      font-weight: 900;
      letter-spacing: -1px;
      margin: 0 0 5px 0;
    }
    .accent {
      color: #FF3B30;
      font-size: 11px;
      font-weight: 900;
      letter-spacing: 4px;
      text-transform: uppercase;
    }
    .subtitle {
      color: rgba(255,255,255,0.4);
      font-size: 14px;
      margin-top: 10px;
    }
    .file-list {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .file-card {
      background: #14161C;
      border: 1px solid #1E293B;
      border-radius: 16px;
      padding: 18px;
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .file-preview {
      width: 100px;
      height: 56px;
      border-radius: 10px;
      overflow: hidden;
      background: rgba(255,255,255,0.02);
      border: 1px solid rgba(255,255,255,0.08);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .clip-thumb {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .file-icon {
      font-size: 20px;
      color: #FF3B30;
    }
    .file-info {
      flex: 1;
      min-width: 0;
    }
    .file-name {
      font-weight: 700;
      font-size: 15px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      margin-bottom: 4px;
    }
    .file-size {
      color: rgba(255,255,255,0.3);
      font-size: 12px;
      font-weight: 600;
    }
    .download-btn {
      background: linear-gradient(135deg, #10B981, #34D399);
      color: white;
      text-decoration: none;
      font-size: 11px;
      font-weight: 900;
      letter-spacing: 1px;
      padding: 10px 20px;
      border-radius: 12px;
      transition: background 0.2s, transform 0.2s;
    }
    .download-btn:hover {
      background: #ffffff;
      color: #090B10;
      transform: translateY(-1px);
    }
    .empty-state {
      text-align: center;
      color: rgba(255,255,255,0.25);
      padding: 60px 0;
      font-weight: 600;
      border: 1px dashed #1E293B;
      border-radius: 16px;
    }
    .info-box {
      background: rgba(255, 179, 0, 0.08);
      border: 1px solid rgba(255, 179, 0, 0.25);
      border-radius: 14px;
      padding: 12px 16px;
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 24px;
    }
    .info-icon {
      font-size: 16px;
    }
    .info-text {
      color: #FFB300;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.5px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="title">CFX <span style="font-weight: 300;">SCP</span></div>
      <div class="accent">Desktop Sync Link</div>
      <div class="subtitle">Download exported clips directly over your local Wi-Fi network at maximum speed.</div>
    </div>
    
    <div class="info-box">
      <div class="info-icon">&#x26A0;&#xFE0F;</div>
      <div class="info-text">In case of Download Failure - Resync</div>
    </div>
    
    <div class="file-list">
      ${fileListHtml.isEmpty ? '<div class="empty-state">No clips ready for download</div>' : fileListHtml}
    </div>
  </div>
</body>
</html>
    ''';
  }

  Future<String?> _getOrCreateFolder(String folderName) async {
    if (_driveApi == null) return null;
    final list = await _driveApi!.files.list(q: "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false");
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id;
    }
    
    final folder = drive.File();
    folder.name = folderName;
    folder.mimeType = 'application/vnd.google-apps.folder';
    final result = await _driveApi!.files.create(folder);
    return result.id;
  }

  Future<void> _uploadFileToFolder(File file, String folderId) async {
    if (_driveApi == null) return;
    final driveFile = drive.File();
    final fileName = path.basename(file.path);
    driveFile.name = fileName;
    driveFile.parents = [folderId];
    
    // Set Mime Type so Drive knows how to play/view it
    String mimeType = "application/octet-stream";
    if (fileName.toLowerCase().endsWith(".mp4")) {
      mimeType = "video/mp4";
    } else if (fileName.toLowerCase().endsWith(".jpg") || fileName.toLowerCase().endsWith(".jpeg")) {
      mimeType = "image/jpeg";
    }
    driveFile.mimeType = mimeType;
    
    // Atomic Upload: Read entire file into memory first to prevent stream interruption
    final bytes = await file.readAsBytes();
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: mimeType);
    
    await _driveApi!.files.create(driveFile, uploadMedia: media);
  }

  AppState(this.prefs) {
    DetectorEngine.logCallback = log;
    isUnlimited = true;
    _initApp();
  }

  Future<void> fetchBroadcast() async {
    isBroadcastLoading = true;
    notifyListeners();
    try {
      // Add Cache-Buster to bypass GitHub's 5-minute raw cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = 'https://gist.githubusercontent.com/dilipparvee2603-ui/1fe63514b3ecd44ee78204544e42fcf9/raw/gistfile2.txt?t=$timestamp';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        broadcastData = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Broadcast Fetch Error: $e");
    } finally {
      isBroadcastLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id.toUpperCase().replaceAll(RegExp(r'[.#$\[\]]'), '_');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = (iosInfo.identifierForVendor ?? 'IOS_DEVICE').toUpperCase().replaceAll(RegExp(r'[.#$\[\]]'), '_');
      } else {
        deviceId = "UNKNOWN-ID";
      }
    } catch (e) {
      deviceId = "ERROR-GETTING-ID";
    }
    notifyListeners();
  }

  Future<void> resetEliteAccess() async {
    isUnlimited = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_unlimited', false);
    notifyListeners();
  }

  Future<void> resetDailyUsage() async {
    dailyScansUsed = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_scans_used', 0);
    notifyListeners();
  }

  Future<void> _loadUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('last_scan_date') ?? "";
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (lastDate != today) {
      dailyScansUsed = 0;
      await prefs.setString('last_scan_date', today);
      await prefs.setInt('daily_scans_used', 0);
    } else {
      dailyScansUsed = prefs.getInt('daily_scans_used') ?? 0;
    }
    notifyListeners();
  }

  Future<void> incrementUsage() async {
    dailyScansUsed++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_scans_used', dailyScansUsed);
    notifyListeners();
  }

  bool get canScan => isUnlimited || (dailyScansUsed < maxDailyScans);

  void setStatus(String s) {
    status = s;
    if (s == "PROCESSING") progress = 0.0;
    notifyListeners();
  }

  void setToolMode(String mode) {
    toolMode = mode;
    notifyListeners();
  }

  void setExportCrf(int crf) {
    exportCrf = crf;
    notifyListeners();
  }

  void setUseHardwareAcceleration(bool value) {
    useHardwareAcceleration = value;
    notifyListeners();
  }

  void setThreshold(double t) {
    threshold = t;
    notifyListeners();
  }

  void setAspectRatio(double ar) {
    aspectRatio = ar;
    notifyListeners();
  }

  void setProgress(double p) {
    progress = p;
    notifyListeners();
  }

  void toggleSelection(int index) {
    if (selectedIndices.contains(index)) {
      selectedIndices.remove(index);
    } else {
      selectedIndices.add(index);
    }
    notifyListeners();
    autoSaveProject();
  }

  void selectAllScenes() {
    selectedIndices = List.generate(scenes.length, (i) => i).toSet();
    notifyListeners();
    autoSaveProject();
  }

  void deselectAllScenes() {
    selectedIndices.clear();
    notifyListeners();
    autoSaveProject();
  }

  void toggleFrameSelection(int index) {
    if (selectedFrameIndices.contains(index)) {
      selectedFrameIndices.remove(index);
    } else {
      selectedFrameIndices.add(index);
    }
    notifyListeners();
  }

  void setScenes(List<Map<String, dynamic>> s) {
    scenes = s;
    selectedIndices = {};
    status = "CLIPS";
    notifyListeners();
    autoSaveProject();
  }

  void setVideo(String filePath) async {
    if (!canScan) return;
    await incrementUsage();
    
    videoPath = filePath;
    status = "PREVIEW";
    progress = 0.0;
    scenes = [];
    selectedIndices = {};
    selectedFrameIndices = {};

    final fileName = path.basename(filePath);
    currentProject = ScenePackProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: fileName,
      videoPath: filePath,
      toolMode: toolMode,
    );
    await ProjectManager.saveProject(currentProject!);
    await loadProjects();
    notifyListeners();

    // Probe duration and FPS
    final info = await FFprobeKit.getMediaInformation(filePath);
    final media = info.getMediaInformation();
    videoDuration = double.tryParse(media?.getDuration() ?? "0") ?? 0;
    exportEndTime = videoDuration > 10.0 ? 10.0 : videoDuration;
    exportStartTime = 0.0;

    final streams = media?.getStreams();
    if (streams != null && streams.isNotEmpty) {
      // Set Aspect Ratio for Grids
      final double width = streams[0].getWidth()?.toDouble() ?? 1280.0;
      final double height = streams[0].getHeight()?.toDouble() ?? 720.0;
      aspectRatio = width / height;

      // Dual-Probe FPS Extraction: Prioritize r_frame_rate for absolute accuracy
      String? fpsString = streams[0].getRealFrameRate();
      if (fpsString == null || fpsString == "0/0") {
        fpsString = streams[0].getAverageFrameRate() ?? "30/1";
      }

      if (fpsString.contains('/')) {
        final parts = fpsString.split('/');
        final num = double.parse(parts[0]);
        final den = double.parse(parts[1]);
        videoFps = (den != 0) ? num / den : 30.0;
      } else {
        videoFps = double.tryParse(fpsString) ?? 30.0;
      }
      exportFps = videoFps;
    }
    notifyListeners();

    // Elite Pulse Probe: Auto-Calibration
    calibrationStatus = "ANALYZING...";
    notifyListeners();
    
    try {
      final double autoThreshold = await DetectorEngine.autoCalibrate(filePath, videoDuration);
      threshold = autoThreshold;
      calibrationStatus = _getCalibrationLabel(autoThreshold);
    } catch (e) {
      debugPrint("Auto-calibration failed: $e");
      calibrationStatus = "BALANCED (AUTO-FAIL)";
      threshold = 0.23;
    }
    await autoSaveProject();
    notifyListeners();
  }

  String _getCalibrationLabel(double t) {
    if (t >= 0.32) return "CALIBRATED: ACTION";
    if (t <= 0.15) return "CALIBRATED: SENSITIVE";
    return "CALIBRATED: BALANCED";
  }

  void setExportRange(double start, double end) {
    exportStartTime = start;
    exportEndTime = end;
    notifyListeners();
  }

  void setExportFps(double fps) {
    exportFps = fps;
    notifyListeners();
  }

  void setCurrentPlayerTime(double t) {
    currentPlayerTime = t;
  }

  void setReviewFrames(List<String> frames) {
    reviewFrames = frames;
    selectedFrameIndices = {};
    status = "REVIEW";
    notifyListeners();
  }

  void setMuteAudio(bool m) {
    muteAudio = m;
    notifyListeners();
  }

  Future<void> saveSelectedFrames() async {
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) return;
    }
    for (var index in selectedFrameIndices) {
      await Gal.putImage(reviewFrames[index], album: "CFX SCP");
    }
  }

  Future<bool> performExport() async {
    progress = 0;
    status = "PROCESSING";
    notifyListeners();

    final Directory tempDir = await getTemporaryDirectory();
    final String clipsPath = "${tempDir.path}/production_clips";
    final Directory clipsDir = Directory(clipsPath);
    if (await clipsDir.exists()) await clipsDir.delete(recursive: true);
    await clipsDir.create();

    final List<ClipExportTask> tasks = [];
    for (int i = 0; i < selectedIndices.length; i++) {
      final index = selectedIndices.elementAt(i);
      final scene = scenes[index];
      final String ext = exportCrf == 0 ? "mkv" : "mp4";
      final String outputPath = "$clipsPath/clip_${index}_${DateTime.now().millisecondsSinceEpoch}.$ext";
      tasks.add(ClipExportTask(
        start: scene['start'],
        end: scene['end'],
        outputPath: outputPath,
      ));
    }

    if (tasks.isEmpty) {
      status = "EXPORT";
      notifyListeners();
      return true;
    }

    try {
      final resultPaths = await DetectorEngine.exportClips(
        input: videoPath!,
        tasks: tasks,
        crfValue: exportCrf,
        muteAudio: muteAudio,
        useHardwareAcceleration: useHardwareAcceleration,
        onProgress: (p) {
          progress = p * 100;
          notifyListeners();
        },
      );
      lastExportedPaths = resultPaths;
    } catch (e) {
      debugPrint("EXPORT_ERROR: $e");
      rethrow;
    }

    clipMemoryBuffer.clear();

    status = "EXPORT";
    notifyListeners();
    return true;
  }
}

