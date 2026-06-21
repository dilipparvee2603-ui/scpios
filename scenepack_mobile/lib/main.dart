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
import 'logic/detector_engine.dart';
import 'logic/supabase_service.dart';
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

class SupabaseUser {
  final String id;
  final String email;
  final String createdAt;

  SupabaseUser({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  factory SupabaseUser.fromJson(Map<String, dynamic> json) {
    return SupabaseUser(
      id: json['id'] ?? json['user_id'] ?? '',
      email: json['email'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'created_at': createdAt,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
            scaffoldBackgroundColor: const Color(0xFF05070E),
            primaryColor: const Color(0xFFFF2D55),
            dividerColor: Colors.white.withOpacity(0.08),
            cardColor: Colors.white.withOpacity(0.04),
          ),
          home: appState.currentUser == null
              ? const LoginScreen()
              : appState.isHomeLoading
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
      backgroundColor: const Color(0xFF05070E),
      body: Stack(
        children: [
          // Subtle grid background
          Positioned.fill(
            child: Opacity(
              opacity: 0.006,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                itemBuilder: (_, __) => Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 0.5)),
                ),
              ),
            ),
          ),

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
                              color: const Color(0xFFFF2D55).withOpacity(_pulseAnim.value * 0.25),
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
                              color: const Color(0xFFFF2D55).withOpacity(_pulseAnim.value * 0.15),
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
                      color: const Color(0xFF0C1120),
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
                    color: Color(0xFFFF2D55),
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
                  const Color(0xFFFF2D55).withOpacity(0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _switchMode(bool toLogin) {
    if (_isLogin == toLogin) return;
    setState(() {
      _isLogin = toLogin;
      _pass.clear();
      _obscurePass = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context, listen: false);
    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Dark base
          Positioned.fill(child: Container(color: const Color(0xFF05070E))),
          // Brand red top blob
          Positioned(
            top: -120, left: -60, right: -60,
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF2D55).withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Brand red bottom-right blob
          Positioned(
            bottom: -80, right: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF2D55).withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Grid texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.008,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 12),
                itemBuilder: (_, __) => Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 0.4)),
                ),
              ),
            ),
          ),
          // Decorative rings
          Positioned(top: -70, left: -70, child: _buildRing(240, 0.08)),
          Positioned(top: -30, left: -30, child: _buildRing(160, 0.12)),
          Positioned(bottom: -50, right: -50, child: _buildRing(200, 0.06)),
          // Neon glow dots
          Positioned(top: 90, right: 30, child: _buildGlowDot(7, 0.9, 18, 6)),
          Positioned(top: 280, left: 20, child: _buildGlowDot(4, 0.5, 10, 3)),
          Positioned(bottom: 180, right: 50, child: _buildGlowDot(5, 0.6, 12, 4)),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 36),

                  // CFX wordmark with gradient
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFFFCCD5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(b),
                    child: const Text("CFX",
                      style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: -3, color: Colors.white, height: 0.9)),
                  ),
                  const SizedBox(height: 5),
                  const Text("S  C  P",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 9, color: Color(0xFFFF2D55))),
                  const SizedBox(height: 12),

                  // Badge pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.35), width: 1),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.15), blurRadius: 12)],
                    ),
                    child: const Text("CFX SCENE PACK",
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: Color(0xFFFF2D55))),
                  ),

                  const SizedBox(height: 36),

                  // Glassmorphism form card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tab switcher
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.15), width: 1),
                              ),
                              child: Row(children: [
                                _buildTab("SIGN IN", _isLogin, () => _switchMode(true)),
                                _buildTab("REGISTER", !_isLogin, () => _switchMode(false)),
                              ]),
                            ),
                            const SizedBox(height: 22),

                            // Headline
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: <Widget>[
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              child: SizedBox(
                                key: ValueKey(_isLogin),
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_isLogin ? "Welcome back." : "Create account.",
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: Colors.white, height: 1.1)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isLogin ? "Sign in to continue." : "Create an account to get started.",
                                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w400)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Email
                            _buildField(controller: _email, hint: "Email address", icon: Icons.alternate_email_rounded),
                            const SizedBox(height: 12),

                            // Password
                            _buildField(controller: _pass, hint: "Password", icon: Icons.lock_outline_rounded,
                              isPass: true, obscure: _obscurePass, onToggle: () => setState(() => _obscurePass = !_obscurePass)),

                            // Forgot password
                            if (_isLogin) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () async {
                                    try {
                                      await launchUrl(
                                        Uri.parse("https://www.cfxstudios.in/forgot-password"),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("COULD NOT OPEN PAGE: $e".toUpperCase()), backgroundColor: const Color(0xFFFF2D55)));
                                    }
                                  },
                                  style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(vertical: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  child: const Text("Forgot password?", style: TextStyle(color: Color(0xFFFF2D55), fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ] else ...[
                              const SizedBox(height: 14),
                            ],

                            // CTA Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: _loading
                                    ? LinearGradient(colors: [const Color(0xFF2A1020).withOpacity(0.8), const Color(0xFF1A0810).withOpacity(0.8)])
                                    : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF2D55), Color(0xFFBB1035)]),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFF2D55).withOpacity(_loading ? 0.2 : 0.6), width: 1),
                                  boxShadow: _loading ? [] : [
                                    BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 8)),
                                    BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.15), blurRadius: 40, spreadRadius: 4),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _loading ? null : () async {
                                    setState(() => _loading = true);
                                    try {
                                      bool success = _isLogin
                                        ? await app.login(_email.text, _pass.text)
                                        : await app.register(_email.text, _pass.text);
                                      if (!mounted) return;
                                      if (!success) ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("AUTHENTICATION FAILED"), backgroundColor: Color(0xFFFF2D55)));
                                    } catch (e) {
                                      if (!mounted) return;
                                      String cleanMsg = e.toString().contains("]") ? e.toString().split("]").last.trim() : e.toString().replaceAll("Exception: ", "");
                                      if (cleanMsg.toLowerCase().contains("credential") || cleanMsg.toLowerCase().contains("incorrect") || cleanMsg.toLowerCase().contains("malformed")) {
                                        cleanMsg = "PASSWORD INCORRECT";
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(cleanMsg.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                        backgroundColor: const Color(0xFFFF2D55),
                                        behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ));
                                    } finally {
                                      if (mounted) setState(() => _loading = false);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  child: _loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white60, strokeWidth: 2))
                                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Text(_isLogin ? "SIGN IN" : "CREATE ACCOUNT",
                                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.5, fontSize: 13)),
                                        const SizedBox(width: 10),
                                        const Icon(Icons.arrow_forward_rounded, size: 16),
                                      ]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),


                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowDot(double size, double opacity, double blur, double spread) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF2D55).withOpacity(opacity),
        boxShadow: [BoxShadow(color: const Color(0xFFFF2D55).withOpacity(opacity * 0.8), blurRadius: blur, spreadRadius: spread)],
      ),
    );
  }

  Widget _buildRing(double size, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFF2D55).withOpacity(opacity), width: 1),
      ),
    );
  }

  Widget _buildTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 40,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF2D55).withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFFFF2D55).withOpacity(0.4) : Colors.transparent,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5,
            color: active ? const Color(0xFFFF2D55) : Colors.white24)),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPass = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13, fontWeight: FontWeight.w400),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(icon, color: const Color(0xFFFF2D55).withOpacity(0.7), size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: isPass ? IconButton(onPressed: onToggle,
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white30, size: 18)) : null,
            filled: true,
            fillColor: const Color(0xFFFF2D55).withOpacity(0.06),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFFFF2D55).withOpacity(0.18), width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFF2D55), width: 1.5)),
          ),
        ),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
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

  SupabaseUser? currentUser;
  String? _accessToken;
  String? _refreshToken;
  
  bool isUnlimited = false;
  bool isTrialActive = false;
  int trialDaysRemaining = 0;
  bool hasPendingUpgrade = false;
  
  bool get isUiLocked => !isUnlimited && !isTrialActive;
  
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
    await _loadUsage();
    
    final sessionStr = prefs.getString('supabase_session');
    if (sessionStr != null) {
      try {
        final session = jsonDecode(sessionStr);
        final refToken = session['refresh_token'] as String?;
        if (refToken != null) {
          final res = await SupabaseService.refreshSession(refToken);
          if (res['status'] == 'ok') {
            final data = res['data'];
            _accessToken = data['access_token'];
            _refreshToken = data['refresh_token'];
            final userData = data['user'];
            currentUser = SupabaseUser(
              id: userData['id'] ?? '',
              email: userData['email'] ?? '',
              createdAt: userData['created_at'] ?? '',
            );
            
            final sessionData = {
              'access_token': _accessToken,
              'refresh_token': _refreshToken,
              'user_id': currentUser!.id,
              'user_email': currentUser!.email,
              'user_created_at': currentUser!.createdAt,
            };
            await prefs.setString('supabase_session', jsonEncode(sessionData));
            
            await _checkActivationStatus(_accessToken!);
          } else {
            // Check if it is a network issue. If it is, do NOT clear session.
            final errorMsg = res['message'] as String? ?? '';
            final isNetworkErr = errorMsg.toLowerCase().contains("socketexception") ||
                                 errorMsg.toLowerCase().contains("timeoutexception") ||
                                 errorMsg.toLowerCase().contains("failed host") ||
                                 errorMsg.toLowerCase().contains("connection failed") ||
                                 errorMsg.toLowerCase().contains("clientexception") ||
                                 errorMsg.toLowerCase().contains("network");
            if (!isNetworkErr) {
              currentUser = null;
              _accessToken = null;
              _refreshToken = null;
              isUnlimited = false;
              await prefs.remove('supabase_session');
              await prefs.setBool('is_unlimited', false);
            }
          }
        }
      } catch (e) {
        debugPrint("Session restore error: $e");
      }
    } else {
      isUnlimited = false;
      await prefs.setBool('is_unlimited', false);
    }
    
    fetchBroadcast(); 
    checkForUpdates(silent: true);
    await _initDrive(); // Silent Cloud Link
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

        drive.Media media;
        if (clipMemoryBuffer.containsKey(filePath)) {
          final bytes = clipMemoryBuffer[filePath]!;
          // True Pacing: Break into 1MB Chunks
          final chunks = <List<int>>[];
          int offset = 0;
          while (offset < bytes.length) {
            int end = (offset + 1024 * 1024 < bytes.length) ? offset + 1024 * 1024 : bytes.length;
            chunks.add(bytes.sublist(offset, end));
            offset = end;
          }
          media = drive.Media(Stream<List<int>>.fromIterable(chunks), bytes.length, contentType: mimeType);
        } else {
          final file = File(filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final chunks = <List<int>>[];
            int offset = 0;
            while (offset < bytes.length) {
              int end = (offset + 1024 * 1024 < bytes.length) ? offset + 1024 * 1024 : bytes.length;
              chunks.add(bytes.sublist(offset, end));
              offset = end;
            }
            media = drive.Media(Stream<List<int>>.fromIterable(chunks), bytes.length, contentType: mimeType);
          } else {
            continue;
          }
        }

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
          ${thumbUrl != null ? '<img src="$thumbUrl" class="clip-thumb" alt="Preview"/>' : '<div class="file-icon">ðŸŽ¬</div>'}
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
      background-color: #080A10;
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
      color: #FF2D55;
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
      background: #0E131F;
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
      color: #FF2D55;
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
      color: #080A10;
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
      <div class="info-icon">âš ï¸</div>
      <div class="info-text">Incase of Download Failure - Resync</div>
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
    final sessionStr = prefs.getString('supabase_session');
    if (sessionStr != null) {
      try {
        final session = jsonDecode(sessionStr);
        _accessToken = session['access_token'];
        _refreshToken = session['refresh_token'];
        currentUser = SupabaseUser(
          id: session['user_id'] ?? '',
          email: session['user_email'] ?? '',
          createdAt: session['user_created_at'] ?? '',
        );
        isUnlimited = prefs.getBool('is_unlimited') ?? false;
      } catch (e) {
        debugPrint("Session parse error: $e");
      }
    }
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
  }  Future<void> _checkActivationStatus(String token) async {
    if (currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final profile = await SupabaseService.getProfile(currentUser!.id, token);
      if (profile != null) {
        final dbPremium = profile['is_premium'] == true;
        if (dbPremium) {
          isUnlimited = true;
          isTrialActive = false;
          trialDaysRemaining = 0;
          final dbHwid = profile['hardware_id'] as String?;
          if (dbHwid == null || dbHwid.isEmpty) {
            await SupabaseService.updateHardwareId(currentUser!.id, deviceId, token);
          }
        } else {
          isUnlimited = false;
          final createdStr = currentUser!.createdAt;
          if (createdStr.isNotEmpty) {
            DateTime? created;
            try {
              created = DateTime.parse(createdStr);
            } catch (_) {}
            
            if (created != null) {
              final elapsedSec = DateTime.now().toUtc().difference(created.toUtc()).inSeconds;
              final elapsedDays = elapsedSec / 86400.0;
              const freeDays = 2.0;
              if (elapsedDays < freeDays) {
                isTrialActive = true;
                trialDaysRemaining = (freeDays - elapsedDays).ceil();
              } else {
                isTrialActive = false;
                trialDaysRemaining = 0;
              }
            } else {
              isTrialActive = false;
              trialDaysRemaining = 0;
            }
          } else {
            isTrialActive = false;
            trialDaysRemaining = 0;
          }
          
          hasPendingUpgrade = await SupabaseService.checkPendingRequests(currentUser!.id, token);
        }
      } else {
        isUnlimited = prefs.getBool('is_unlimited') ?? false;
        isTrialActive = false;
        trialDaysRemaining = 0;
      }
    } catch (e) {
      debugPrint("Check activation status error: $e");
    }
    
    await prefs.setBool('is_unlimited', isUnlimited);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final res = await SupabaseService.login(email.trim(), password);
      if (res['status'] != 'ok') {
        throw Exception(res['message'] ?? 'Invalid email or password.');
      }
      
      final data = res['data'];
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      final userData = data['user'];
      currentUser = SupabaseUser(
        id: userData['id'] ?? '',
        email: userData['email'] ?? '',
        createdAt: userData['created_at'] ?? '',
      );
      
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
        'user_id': currentUser!.id,
        'user_email': currentUser!.email,
        'user_created_at': currentUser!.createdAt,
      };
      await prefs.setString('supabase_session', jsonEncode(sessionData));
      
      await SupabaseService.createProfile(currentUser!.id, currentUser!.email, _accessToken!);
      
      final profile = await SupabaseService.getProfile(currentUser!.id, _accessToken!);
      if (profile == null) {
        throw Exception("Failed to retrieve user profile.");
      }
      
      final dbPremium = profile['is_premium'] == true;
      if (dbPremium) {
        isUnlimited = true;
        isTrialActive = false;
        trialDaysRemaining = 0;
        final dbHwid = profile['hardware_id'] as String?;
        if (dbHwid == null || dbHwid.isEmpty) {
          await SupabaseService.updateHardwareId(currentUser!.id, deviceId, _accessToken!);
        }
      } else {
        isUnlimited = false;
        final createdStr = currentUser!.createdAt;
        if (createdStr.isNotEmpty) {
          DateTime? created;
          try {
            created = DateTime.parse(createdStr);
          } catch (_) {}
          
          if (created != null) {
            final elapsedSec = DateTime.now().toUtc().difference(created.toUtc()).inSeconds;
            final elapsedDays = elapsedSec / 86400.0;
            const freeDays = 2.0;
            if (elapsedDays < freeDays) {
              isTrialActive = true;
              trialDaysRemaining = (freeDays - elapsedDays).ceil();
            } else {
              isTrialActive = false;
              trialDaysRemaining = 0;
            }
          } else {
            isTrialActive = false;
            trialDaysRemaining = 0;
          }
        } else {
          isTrialActive = false;
          trialDaysRemaining = 0;
        }
        
        hasPendingUpgrade = await SupabaseService.checkPendingRequests(currentUser!.id, _accessToken!);
      }
      
      await prefs.setBool('is_unlimited', isUnlimited);
      notifyListeners();
      return true;
    } catch (e) {
      currentUser = null;
      _accessToken = null;
      _refreshToken = null;
      isUnlimited = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> register(String email, String password) async {
    try {
      final res = await SupabaseService.signUp(email.trim(), password);
      if (res['status'] != 'ok') {
        throw Exception(res['message'] ?? 'Registration failed.');
      }
      return await login(email, password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    isUnlimited = false;
    isTrialActive = false;
    trialDaysRemaining = 0;
    hasPendingUpgrade = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('supabase_session');
    await prefs.setBool('is_unlimited', false);
    notifyListeners();
  }

  Future<void> forgotPassword(String email) async {
    if (email.isEmpty) throw "PLEASE ENTER YOUR EMAIL FIRST";
    final res = await SupabaseService.recoverPassword(email.trim());
    if (res['status'] != 'ok') {
      throw Exception(res['message'] ?? 'Failed to send recovery email.');
    }
  }

  Future<void> _loadDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id.toUpperCase().replaceAll(RegExp(r'[.#$\[\]]'), '_');
      } else {
        deviceId = "UNKNOWN-ID";
      }
    } catch (e) {
      deviceId = "ERROR-GETTING-ID";
    }
    notifyListeners();
  }

  Future<void> submitUtr(String utr) async {
    if (currentUser == null || _accessToken == null) {
      throw Exception("PLEASE LOGIN FIRST");
    }
    final res = await SupabaseService.submitTransaction(currentUser!.id, currentUser!.email, utr, _accessToken!);
    if (res['status'] == 'ok') {
      hasPendingUpgrade = true;
      notifyListeners();
    } else {
      throw Exception(res['message'] ?? 'Failed to submit transaction.');
    }
  }

  Future<bool> deregisterDevice() async {
    if (currentUser == null || _accessToken == null) return false;
    try {
      final success = await SupabaseService.updateHardwareId(currentUser!.id, null, _accessToken!);
      if (success) {
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Deregister device error: $e");
    }
    return false;
  }

  Future<void> refreshStatus() async {
    if (currentUser == null || _accessToken == null) return;
    await _checkActivationStatus(_accessToken!);
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
  }

  void setVideo(String path) async {
    if (!canScan) return;
    await incrementUsage();
    
    videoPath = path;
    status = "PREVIEW";
    progress = 0.0;
    scenes = [];
    selectedIndices = {};
    selectedFrameIndices = {};
    notifyListeners();

    // Probe duration and FPS
    final info = await FFprobeKit.getMediaInformation(path);
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
      final double autoThreshold = await DetectorEngine.autoCalibrate(path, videoDuration);
      threshold = autoThreshold;
      calibrationStatus = _getCalibrationLabel(autoThreshold);
    } catch (e) {
      print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂºÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â PULSE ERROR: $e");
      calibrationStatus = "BALANCED (AUTO-FAIL)";
      threshold = 0.23;
    }
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
    notifyListeners();
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

    final exportPaths = <String>[];
    for (int i = 0; i < selectedIndices.length; i++) {
      final index = selectedIndices.elementAt(i);
      final scene = scenes[index];
      final String ext = exportCrf == 0 ? "mkv" : "mp4";
      final String outputPath = "$clipsPath/clip_${index}_${DateTime.now().millisecondsSinceEpoch}.$ext";
      final resultPath = await DetectorEngine.exportClip(
        input: videoPath!,
        output: outputPath,
        start: scene['start'],
        end: scene['end'],
        crfValue: exportCrf,
        muteAudio: muteAudio,
        useHardwareAcceleration: useHardwareAcceleration,
        onProgress: (subP) {
          progress = ((i + subP) / selectedIndices.length) * 100;
          notifyListeners();
        },
      );
      exportPaths.add(resultPath);
      progress = ((i + 1) / selectedIndices.length) * 100;
      notifyListeners();
    }

    for (var path in exportPaths) {
      // We don't save to gallery automatically anymore
      // await Gal.putVideo(path, album: "CFX SCP");
    }

    lastExportedPaths = exportPaths;
    
    // Memory Lock: Capture raw bytes into RAM for instant cloud sync
    clipMemoryBuffer.clear();
    for (var path in exportPaths) {
      final file = File(path);
      if (await file.exists()) {
        clipMemoryBuffer[path] = await file.readAsBytes();
      }
    }

    status = "EXPORT";
    notifyListeners();
    return true;
  }
}

