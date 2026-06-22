import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scenepack_mobile/logic/detector_engine.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'dart:io';
import 'dart:ui' as ui;


class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.status == "HOME" && state.isUiLocked && !state.hasShownTrialExpiredDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!state.hasShownTrialExpiredDialog) {
          state.setHasShownTrialExpiredDialog(true);
          _showTrialExpiredPopup(context, state);
        }
      });
    }

    return PopScope(
      canPop: state.status == "HOME",
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (state.status == "PICKER") {
           state.setStatus("HOME");
        } else if (state.status == "REVIEW") {
          state.setStatus("CLIPS");
        } else if (state.status == "CLIPS") {
          state.setStatus("PREVIEW");
        } else if (state.status == "PREVIEW") {
          state.setStatus("PICKER");
        } else if (state.status == "UPDATE") {
          state.setStatus("SETTINGS");
        } else if (state.status == "ACCOUNT" || state.status == "SETTINGS") {
          state.setStatus("HOME");
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF05070E),
        appBar: (state.status == "HOME" || state.status == "UPDATE" || state.status == "ACCOUNT" || state.status == "SETTINGS") ? null : AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: state.status == "UPDATE" ? null : IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () {
              if (state.status == "PICKER") state.setStatus("HOME");
              else if (state.status == "PREVIEW") state.setStatus("PICKER");
              else if (state.status == "REVIEW") state.setStatus("CLIPS");
              else if (state.status == "CLIPS") state.setStatus("PREVIEW");
              else if (state.status == "UPDATE") state.setStatus("HOME");
            },
          ),
        ),
        body: Stack(
          children: [
            // Dark base background
            Positioned.fill(child: Container(color: const Color(0xFF05070E))),
            // Brand red top blob (global glow)
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
            // Brand red bottom-right blob (global glow)
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
            // Tech-Grid Background Texture (Optimized const RepaintBoundary Grid)
            const Positioned.fill(
              child: TechGridBackground(),
            ),
            // Main Content Layer
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                child: _buildBody(context, state),
              ),
            ),
          ],
        ),
        bottomNavigationBar: (state.status == "HOME" || state.status == "ACCOUNT" || state.status == "SETTINGS" || state.status == "UPDATE")
            ? SafeArea(child: _buildMainBottomNavBar(context, state))
            : ((state.status == "CLIPS" || state.status == "REVIEW") ? SafeArea(child: _buildBottomBar(context, state)) : null),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppState state) {
    switch (state.status) {
      case "HOME":
        return _buildHome(context, state);
      case "ACCOUNT":
        return AccountPage(state: state);
      case "SETTINGS":
        return SettingsPage(state: state);
      case "PROCESSING":
        return _buildProcessing(context, state);
      case "PREVIEW":
        return _buildPreview(context, state);
      case "CLIPS":
        return _buildClips(context, state);
      case "REVIEW":
        return _buildFrameReview(context, state);
      case "EXPORT":
        return _buildExportPortal(context, state);
      case "UPDATE":
        return _buildUpdateHub(context, state);
      default:
        return _buildPicker(context, state);
    }
  }

  Widget _buildHome(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50),
          // Clean Minimalist Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CFX", style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text("SCP", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 8, color: const Color(0xFFFF2D55).withOpacity(0.8))),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 10, color: Colors.white10),
                      const SizedBox(width: 8),
                      Text(state.appVersion, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white24)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _showHelpDisclaimer(context),
                    icon: const Icon(Icons.help_outline_rounded, color: Colors.white24, size: 28),
                  ),
                  IconButton(
                    onPressed: () => state.setStatus("ACCOUNT"),
                    icon: const Icon(Icons.account_circle_outlined, color: Colors.white24, size: 32),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),

          // System & License Hub
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem("SYSTEM", "ONLINE"),
                    GestureDetector(
                      onLongPress: state.currentUser?.email == 'dilipkumar16398@gmail.com'
                          ? () => _showDeveloperPanel(context, state)
                          : null,
                      child: _buildStatItem("LICENSE", state.isUnlimited ? "ELITE" : "STANDARD"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionChip(
                        state.isUnlimited ? "PREMIUM" : "ACTIVATE PRO",
                        Icons.bolt_rounded,
                        state.isUnlimited ? null : () => AppNavigator.showActivationPortal(context, state),
                        color: state.isUnlimited ? const Color(0xFFFFB300) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildActionChip("BENEFITS", Icons.stars_rounded, () => _showProBenefits(context))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          const Text("EDITORIAL WORKFLOWS", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 24),
          _buildModernToolCard(
            context, state,
            title: "SCENE FINDER", desc: "High-precision scene cut detection", icon: Icons.track_changes_rounded,
            mode: "DETECTION"
          ),
          const SizedBox(height: 16),
          _buildModernToolCard(
            context, state,
            title: "FRAME EXPORTER", desc: "Lossless frame sequence extraction", icon: Icons.layers_outlined,
            mode: "FRAME_PACK"
          ),
          const SizedBox(height: 40),

        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {Color color = Colors.white, VoidCallback? onLongPress}) {
    return InkWell(
      onLongPress: onLongPress,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: Colors.white24),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback? onTap, {Color? color}) {
    return Material(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color ?? const Color(0xFFFF2D55)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: color ?? Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, VoidCallback onTap, {bool hasPulse = false}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: Colors.white38, size: 20),
              if (hasPulse)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2D55),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFFF2D55), blurRadius: 4, spreadRadius: 1),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildBroadcastBanner(BuildContext context, AppState state) {
    final msg = state.broadcastData?['message'] ?? "";
    final url = state.broadcastData?['url'] ?? "";
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: InkWell(
        onTap: url.isNotEmpty ? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFFFF2D55), size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  msg.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              if (url.isNotEmpty) const Icon(Icons.open_in_new_rounded, color: Colors.white24, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoadmapSection(BuildContext context, AppState state) {
    final upcoming = (state.broadcastData!['upcoming'] as List).cast<String>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("UPCOMING ENGINE UPDATES",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white24, fontSize: 10)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: upcoming.map((item) => Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2D55),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFFF2D55), blurRadius: 10, spreadRadius: 1),
                      ]
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(item.toUpperCase(), 
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildModernToolCard(BuildContext context, AppState state,
      {required String title, required String desc, required IconData icon, required String mode}) {
    bool isActive = state.toolMode == mode;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isActive ? const Color(0xFFFF2D55) : Colors.white.withOpacity(0.08)),
      ),
      child: InkWell(
        onTap: () {
          if (state.isUiLocked) {
            AppNavigator.showActivationPortal(context, state);
            return;
          }
          state.setToolMode(mode);
          state.setStatus("PICKER");
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFF2D55).withOpacity(0.1) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: isActive ? const Color(0xFFFF2D55) : Colors.white24, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.3)),
                  ],
                ),
              ),
              state.isUiLocked
                  ? const Icon(Icons.lock_rounded, color: Color(0xFFFF2D55), size: 16)
                  : Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.05), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onLongPress}) {
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Left aligned for readability
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildIconLink(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF2D55), size: 24),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildChangelogCard({required String version, required List<String> logs}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(version.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12, letterSpacing: 1)),
              const Icon(Icons.terminal_rounded, size: 14, color: Colors.white24),
            ],
          ),
          const SizedBox(height: 16),
          ...logs.map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("» ", style: TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.bold, fontSize: 12)),
                Expanded(
                  child: Text(
                    log.toUpperCase(), 
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7), 
                      fontSize: 10, 
                      height: 1.4, 
                      fontFamily: 'monospace', 
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  static void showActivationPortal(BuildContext context, AppState state) {
    launchUrl(Uri.parse("https://www.cfxstudios.in/scp-premium"), mode: LaunchMode.externalApplication);
  }

  void _showHelpDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0E17).withOpacity(0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFFF2D55),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "SUITE DISCLAIMER",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "As scene detection is heavy processing method we recommend to use only for short videos.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("GOT IT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTrialExpiredPopup(BuildContext context, AppState state) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0E17).withOpacity(0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: Color(0xFFFF2D55),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "FREE TRIAL EXPIRED",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Your 2-day trial has completed. Upgrade to PRO to continue using the suite.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                          ),
                          child: const Text(
                            "CLOSE",
                            style: TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF2D55), Color(0xFFBB1035)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2D55).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              AppNavigator.showActivationPortal(context, state);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "UPGRADE",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeveloperPanel(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0E17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white10, width: 1),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            const Text("GHOST DEVELOPER PANEL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Color(0xFFFF2D55))),
            const SizedBox(height: 20),
            _devActionTile("RESET ELITE ACCESS", "Removes unlimited license", Icons.lock_reset_rounded, () async {
              await state.resetEliteAccess();
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            const SizedBox(height: 12),
            _devActionTile("CLEAR DAILY USAGE", "Resets today's video count", Icons.refresh_rounded, () async {
              await state.resetDailyUsage();
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            const SizedBox(height: 12),
            _devActionTile("SYSTEM REBOOT", "Clear all temporary cache", Icons.power_settings_new_rounded, () async {
               final Directory tempDir = await getTemporaryDirectory();
               if (await tempDir.exists()) await tempDir.delete(recursive: true);
               if (ctx.mounted) Navigator.pop(ctx);
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _devActionTile(String title, String sub, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2D55).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFFF2D55), size: 18),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
        subtitle: Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showEngineLogs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0E17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white10, width: 1),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("UPDATE LOGS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
                TextButton(
                  onPressed: () {
                     Navigator.pop(ctx);
                     _showOldLogs(context);
                  },
                  child: const Text("PREVIOUS LOGS", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildChangelogCard(
              version: "v2.5.3 ELITE",
              logs: [
                "Dual-Pass Scene Detection (0.23 + 0.18 threshold)",
                "Intelligent Cut Merging (0.5s proximity logic)",
                "Optimized scanner for subtle transition accuracy",
                "Integrated official CFX Logo as App Icon",
                "Refined Selection UI (Balanced 2px Neon borders)",
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showOldLogs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0E17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white10, width: 1),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            const Text("LEGACY LOGS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
            const SizedBox(height: 16),
            _buildChangelogCard(
              version: "v2.5.2",
              logs: [
                "Integrated official CFX Logo as App Icon",
                "Refined Selection UI (Balanced 2px Neon borders)",
                "Streamlined results workflow (Optimized for speed)",
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showProBenefits(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0E17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white10, width: 1),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 24),
              const Text("ELITE PRO BENEFITS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Color(0xFFFF2D55))),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withOpacity(0.08), 
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Color(0xFFFF2D55), size: 16),
                    SizedBox(width: 10),
                    Text("LIFETIME PRO: ₹299 ONLY", style: TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                  ],
                ),
              ),
              _buildProItem(Icons.all_inclusive_rounded, "Unlimited Video Processing", "No daily 5-video limit. Process entire movies without stopping."),
              const SizedBox(height: 12),
              _buildProItem(Icons.bolt_rounded, "Elite Preset Intelligence", "Optimized presets for Action (0.32), Balanced (0.23), and Sensitive (0.15) clips."),
              const SizedBox(height: 12),
              _buildProItem(Icons.high_quality_rounded, "Lossless Export Access", "Enable pure RAW exports with CRF 0 quality settings."),
              const SizedBox(height: 12),
              _buildProItem(Icons.support_agent_rounded, "Priority Stability", "Faster processing priority and background execution support."),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProItem(IconData icon, String title, String desc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFF2D55), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }



  void _showPremiumSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0E131F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isError ? const Color(0xFFFF2D55) : const Color(0xFF10B981)).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.check_rounded, 
                color: isError ? const Color(0xFFFF2D55) : const Color(0xFF10B981), 
                size: 14
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message.toUpperCase(), 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, AppState state,
      {required String title, required String desc, required IconData icon, required String mode}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E131F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: InkWell(
        onTap: () {
          state.setToolMode(mode);
          state.setStatus("PICKER");
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFF2D55).withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: const Color(0xFFFF2D55), size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing(BuildContext context, AppState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(state.selectedIndices.isEmpty ? "FINDING SCENES" : "PREPARING EXPORT", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 5, color: Color(0xFFFF2D55))),
          const SizedBox(height: 8),
          const Text("DO NOT CLOSE THE SUITE", style: TextStyle(fontSize: 8, color: Colors.white24, letterSpacing: 1)),
          const SizedBox(height: 24),
          Container(
            width: 280,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: state.progress / 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFFD81B4B)]),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.4), blurRadius: 12)],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text("${state.progress.toInt()}%",
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF2D55), fontSize: 20)),
          const Text("Please wait...",
              style: TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildPicker(BuildContext context, AppState state) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.94,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(state.toolMode == "DETECTION" ? Icons.radar_rounded : Icons.auto_awesome_motion_rounded,
                  size: 64, color: const Color(0xFFFF2D55)),
            ),
            const SizedBox(height: 24),
            Text(state.toolMode == "DETECTION" ? "SCENE FINDER" : "FRAME PACKER",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(state.toolMode == "DETECTION" ? "Select video to find scene cuts" : "Select video to extract frame sequence",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 40),
            _PickerButton(onVideoSelected: (path) => state.setVideo(path)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, AppState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StudioMasterPlayer(
            videoPath: state.videoPath!, 
            fps: state.videoFps,
            onTimeUpdate: (t) => state.setCurrentPlayerTime(t),
            showJogControls: state.toolMode == "FRAMEPACK",
          ),
          const SizedBox(height: 24),
          // Mode Specific Controls
          if (state.toolMode == "DETECTION") _buildDetectionPanel(context, state) else _buildFramePackPanel(context, state),
        ],
      ),
    );
  }

  Widget _buildDetectionPanel(BuildContext context, AppState state) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("SENSITIVITY PRESET",
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
                  Text(state.calibrationStatus,
                      style: const TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.bold, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPresetButton("SENSITIVE", 0.15, state.threshold == 0.15, () => state.setThreshold(0.15)),
                  const SizedBox(width: 8),
                  _buildPresetButton("BALANCED", 0.23, state.threshold == 0.23, () => state.setThreshold(0.23)),
                  const SizedBox(width: 8),
                  _buildPresetButton("ACTION", 0.32, state.threshold == 0.32, () => state.setThreshold(0.32)),
                ],
              ),
              const SizedBox(height: 12),
              const Text("Action: Fast cuts | Balanced: Normal | Sensitive: Subtle cinematic cuts",
                  style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButtons(context, state),
      ],
    );
  }

  Widget _buildPresetButton(String label, double value, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF2D55).withOpacity(0.2) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF2D55) : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: isSelected ? const Color(0xFFFF2D55) : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppState state) {
    bool isLocked = state.isUiLocked;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isLocked
            ? null
            : const LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFFD81B4B)]),
        color: isLocked ? Colors.white.withOpacity(0.04) : null,
        border: isLocked ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
        boxShadow: isLocked
            ? null
            : [
                BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: isLocked
            ? () => AppNavigator.showActivationPortal(context, state)
            : () async {
                try {
                  state.setStatus("PROCESSING");
                  final scenes = await DetectorEngine.detectScenes(
                    videoPath: state.videoPath!,
                    threshold: state.threshold,
                    onProgress: (p) => state.setProgress(p.toDouble()),
                    onAspectRatio: (ar) => state.setAspectRatio(ar),
                  );
                  state.setScenes(scenes);
                } catch (e) {
                  state.setStatus("PREVIEW");
                  state.setProgress(0.0);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error detecting scenes: ${e.toString().split('\n').first}"),
                        backgroundColor: const Color(0xFFFF2D55),
                      ),
                    );
                  }
                }
              },
        icon: Icon(isLocked ? Icons.lock_rounded : Icons.radar_rounded),
        label: Text(isLocked ? "UPGRADE TO RUN" : "FIND SCENES", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: isLocked ? Colors.white24 : Colors.white,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 72),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildFramePackPanel(BuildContext context, AppState state) {
    int estimatedFrames = ((state.exportEndTime - state.exportStartTime) * state.exportFps).toInt();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text("Start Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 12),
                      _buildSmallButton("USE CURRENT", () {
                        state.setExportRange(
                          state.currentPlayerTime,
                          state.currentPlayerTime > state.exportEndTime ? state.currentPlayerTime : state.exportEndTime
                        );
                      }),
                    ],
                  ),
                  Text("${state.exportStartTime.toStringAsFixed(1)}s", 
                      style: const TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              Slider(
                value: state.exportStartTime.clamp(0, state.videoDuration > 0 ? state.videoDuration : 10),
                min: 0,
                max: state.videoDuration > 0 ? state.videoDuration : 10,
                activeColor: const Color(0xFFFF2D55),
                inactiveColor: Colors.white.withOpacity(0.12),
                onChanged: state.videoDuration == 0 ? null : (v) {
                  state.setExportRange(v, v > state.exportEndTime ? v : state.exportEndTime);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text("End Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 12),
                      _buildSmallButton("USE CURRENT", () {
                        state.setExportRange(
                          state.currentPlayerTime < state.exportStartTime ? state.currentPlayerTime : state.exportStartTime,
                          state.currentPlayerTime
                        );
                      }),
                    ],
                  ),
                  Text("${state.exportEndTime.toStringAsFixed(1)}s", 
                      style: const TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              Slider(
                value: state.exportEndTime.clamp(0, state.videoDuration > 0 ? state.videoDuration : 10),
                min: 0,
                max: state.videoDuration > 0 ? state.videoDuration : 10,
                activeColor: const Color(0xFFFF2D55),
                inactiveColor: Colors.white.withOpacity(0.12),
                onChanged: state.videoDuration == 0 ? null : (v) {
                  state.setExportRange(v < state.exportStartTime ? v : state.exportStartTime, v);
                },
              ),
              Divider(height: 40, color: Colors.white.withOpacity(0.08)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Images Per Second", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  Text("${state.exportFps.toInt()} fps", 
                      style: const TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Slider(
                value: state.exportFps,
                min: 1,
                max: state.videoFps,
                divisions: state.videoFps.toInt() > 1 ? state.videoFps.toInt() - 1 : 1,
                activeColor: const Color(0xFFFF2D55),
                inactiveColor: Colors.white.withOpacity(0.12),
                onChanged: (v) => state.setExportFps(v),
              ),
              const SizedBox(height: 8),
              Text("Extracting approx. $estimatedFrames frames.", 
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: state.isUiLocked
                ? null
                : const LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFFD81B4B)]),
            color: state.isUiLocked ? Colors.white.withOpacity(0.04) : null,
            border: state.isUiLocked ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
            boxShadow: state.isUiLocked
                ? null
                : [
                    BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
          ),
          child: ElevatedButton.icon(
            onPressed: state.isUiLocked
                ? () => AppNavigator.showActivationPortal(context, state)
                : () async {
                    state.setStatus("PROCESSING");
                    final frames = await DetectorEngine.extractFramesForReview(
                      videoPath: state.videoPath!,
                      fps: state.exportFps,
                      startTime: state.exportStartTime,
                      endTime: state.exportEndTime,
                      onProgress: (p) => state.setProgress(p.toDouble()),
                    );
                    state.setReviewFrames(frames);
                  },
            icon: Icon(state.isUiLocked ? Icons.lock_rounded : Icons.auto_awesome_motion_rounded),
            label: Text(state.isUiLocked ? "UPGRADE TO RUN" : "EXTRACT SELECTION", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: state.isUiLocked ? Colors.white24 : Colors.white,
              shadowColor: Colors.transparent,
              minimumSize: const Size(double.infinity, 72),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrameReview(BuildContext context, AppState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("FRAME REVIEW (${state.reviewFrames.length})",
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey)),
              TextButton(
                onPressed: () => state.setStatus("PREVIEW"),
                child: const Text("CLOSE", style: TextStyle(color: Color(0xFFFF2D55))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: state.aspectRatio > 1.2 ? 2 : 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: state.aspectRatio,
            ),
            itemCount: state.reviewFrames.length,
            itemBuilder: (context, index) {
              bool isSelected = state.selectedFrameIndices.contains(index);
              return GestureDetector(
                onTap: () => state.toggleFrameSelection(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFF2D55) : Colors.white.withOpacity(0.08),
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(state.reviewFrames[index]), cacheWidth: 240, fit: BoxFit.cover),
                      if (isSelected)
                        const Center(
                          child: Icon(Icons.check_circle, color: Color(0xFFFF2D55), size: 32),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildActionBtn(
            label: "SAVE ${state.selectedFrameIndices.length} FRAMES",
            onPressed: state.selectedFrameIndices.isEmpty ? null : () async {
              await state.saveSelectedFrames();
              if (context.mounted) {
                _showPremiumSnackBar(context, "FRAMES SAVED TO GALLERY");
              }
            },
          ),
          const SizedBox(height: 12),
          if (state.isDriveConnected)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: (state.selectedFrameIndices.isEmpty || state.isCloudSyncing) ? null : () async {
                  final selectedFiles = state.selectedFrameIndices.map((i) => state.reviewFrames[i]).toList();
                  final success = await state.syncToCloud(selectedFiles);
                  if (context.mounted) {
                    if (success) {
                      _showPremiumSnackBar(context, "FRAMES SYNCED TO DRIVE");
                    } else {
                      _showPremiumSnackBar(context, "SYNC TO DRIVE FAILED", isError: true);
                    }
                  }
                },
                icon: state.isCloudSyncing 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  state.isCloudSyncing 
                    ? "SYNCING... ${(state.cloudProgress * 100).toInt()}%" 
                    : "SYNC TO CLOUD", 
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildClips(BuildContext context, AppState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("DETECTED CLIPS (${state.scenes.length})",
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey)),
              TextButton(
                onPressed: () => state.setStatus("PREVIEW"),
                child: const Text("CLOSE", style: TextStyle(color: Color(0xFFFF2D55))),
              ),
            ],
          ),
          // Integrated Command Hub (Always Visible)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Colors.white38, size: 14),
                    const SizedBox(width: 8),
                    const Text("EXPORT SETTINGS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white38, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 16),
                // Audio Control Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.volume_off_rounded, color: Colors.grey, size: 16),
                          SizedBox(width: 12),
                          Text("MUTE AUDIO", 
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.grey)),
                        ],
                      ),
                      Switch(
                        value: state.muteAudio,
                        onChanged: (v) => state.setMuteAudio(v),
                        activeColor: const Color(0xFFFF2D55),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Hardware Acceleration Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: Colors.grey, size: 16),
                          SizedBox(width: 12),
                          Text("HARDWARE ACCELERATION", 
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.grey)),
                        ],
                      ),
                      Switch(
                        value: state.useHardwareAcceleration,
                        onChanged: (v) => state.setUseHardwareAcceleration(v),
                        activeColor: const Color(0xFFFF2D55),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Quality Segment Selection: Elite 3-Tier Chassis
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      _buildQualityCard(context, state, "LOSSLESS TRUE", 0, "MASTER"),
                      _buildQualityCard(context, state, "ELITE", 16, "PRO"),
                      _buildQualityCard(context, state, "BALANCED", 23, "STD"),
                    ],
                  ),
                ),
                if (state.useHardwareAcceleration) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 14),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text("HARDWARE ACCELERATION ENABLED: Video will be exported using MediaCodec H.264 at a fast target 8 Mbps bitrate.", 
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ] else if (state.exportCrf == 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFFF2D55), size: 14),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text("WARNING: LOSSLESS TRUE creates extremely large files. Use only for master archiving.", 
                              style: TextStyle(color: Color(0xFFFF2D55), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text("Tip: Tap any clip to select it for export", 
              style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: state.aspectRatio * 0.9,
            ),
            itemCount: state.scenes.length,
            itemBuilder: (context, index) {
              final scene = state.scenes[index];
              bool isSelected = state.selectedIndices.contains(index);
              return GestureDetector(
                onTap: () => state.toggleSelection(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E131F),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.3), blurRadius: 15, spreadRadius: 2)] : null,
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFF2D55) : const Color(0xFF1E293B), 
                      width: isSelected ? 2 : 1
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(scene['thumbnail']), cacheWidth: 240, fit: BoxFit.cover),
                      // Top Bar Info (Scene Index)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Text("S-${(index + 1).toString().padLeft(2, '0')}", 
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                      // Selection Indicator
                      if (isSelected) Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFFFF2D55), shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                      // Bottom Info Gradient
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                            ),
                          ),
                        ),
                      ),
                      // Duration ONLY
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.3)),
                          ),
                          child: Text("${(scene['end'] - scene['start']).toStringAsFixed(1)}s", 
                              style: const TextStyle(color: Color(0xFFFF2D55), fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildExportPortal(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.04),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.08),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                ),
                const SizedBox(height: 24),
                const Text("EXPORT READY", 
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16, color: Color(0xFF10B981))),
                const SizedBox(height: 6),
                Text("${state.lastExportedPaths.length} CLIPS READY", 
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 48),
          const Text("WHERE TO SAVE:", style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          
          if (state.isCloudSyncing) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text("SAVING TO GOOGLE DRIVE", 
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ],
                      ),
                      Text("${(state.cloudProgress * 100).toInt()}%", 
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: state.cloudProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.35),
                              blurRadius: 10,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildPortalAction(
            icon: Icons.photo_library_rounded,
            title: "SAVE TO GALLERY",
            desc: "Save clips directly to your phone",
            onTap: () async {
              for (var path in state.lastExportedPaths) {
                await Gal.putVideo(path, album: "CFX SCP");
              }
              if (context.mounted) {
                _showPremiumSnackBar(context, "SAVED TO PHONE GALLERY");
              }
            },
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          if (!state.isDriveConnected)
            _buildPortalAction(
              icon: Icons.cloud_off_rounded,
              title: "LINK GOOGLE DRIVE",
              desc: "Connect your Drive to save clips online",
              onTap: () => state.connectDrive(),
              color: Colors.white12,
            )
          else
            _buildPortalAction(
              icon: Icons.cloud_upload_rounded,
              title: "SAVE TO DRIVE",
              desc: "Upload clips to your personal Google Drive",
              onTap: () async {
                final success = await state.syncToCloud(state.lastExportedPaths);
                if (context.mounted) {
                  if (success) {
                    _showPremiumSnackBar(context, "SAVED TO GOOGLE DRIVE");
                  } else {
                    _showPremiumSnackBar(context, "SAVE TO DRIVE FAILED", isError: true);
                  }
                }
              },
              color: const Color(0xFF10B981),
            ),
          const SizedBox(height: 16),
          _buildPortalAction(
            icon: Icons.wifi_rounded,
            title: "DESKTOP WI-FI SYNC",
            desc: "Download clips directly to your computer",
            onTap: () => _showWifiSyncPanel(context, state),
            color: const Color(0xFF10B981),
          ),
          
          const SizedBox(height: 48),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFFD81B4B)]),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2D55).withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ElevatedButton(
              onPressed: () => state.setStatus("CLIPS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("DONE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showWifiSyncPanel(BuildContext context, AppState state) {
    state.startLocalServer();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0E17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        side: BorderSide(color: Colors.white10),
      ),
      builder: (context) {
        return AnimatedBuilder(
          animation: state,
          builder: (context, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  const Icon(Icons.wifi_rounded, size: 36, color: Color(0xFF10B981)),
                  const SizedBox(height: 8),
                  const Text("DESKTOP WI-FI SYNC", 
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text("Make sure both devices are on the same Wi-Fi network", 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500)),
                  
                  const SizedBox(height: 16),

                  if (state.localServerUrl == null)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/?size=120x120&color=10B981&bgcolor=080A10&data=${Uri.encodeComponent(state.localServerUrl!)}',
                          width: 120,
                          height: 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 120,
                              height: 120,
                              color: Colors.white.withOpacity(0.02),
                              child: const Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.white10),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              state.localServerUrl!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: state.localServerUrl!));
                              _showPremiumSnackBar(context, "URL COPIED TO CLIPBOARD");
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text("Type this URL in your computer's browser to download clips",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.03),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        elevation: 0,
                      ),
                      child: const Text("STOP SYNCING", 
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      state.stopLocalServer();
    });
  }

  Widget _buildPortalAction({required IconData icon, required String title, required String desc, required VoidCallback onTap, required Color color}) {
    final bool isGrey = color == Colors.white12;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGrey ? Colors.white.withOpacity(0.08) : color.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGrey ? Colors.white.withOpacity(0.03) : color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isGrey ? Colors.white38 : color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: isGrey ? Colors.white24 : color.withOpacity(0.4), size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({required String label, required VoidCallback? onPressed}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFFD81B4B)]),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, shadowColor: Colors.transparent, minimumSize: const Size(double.infinity, 64)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppState state) {
    if (state.status == "REVIEW") return const SizedBox.shrink();
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04), 
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: Row(
            children: [
              Expanded(child: Text("${state.selectedIndices.length} SELECTED", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF2D55)))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: state.selectedIndices.isEmpty ? null : () async {
                  await state.performExport();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D55), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("PREPARE EXPORT"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF2D55).withOpacity(0.08), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.15)),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFFFF2D55), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildQualityCard(BuildContext context, AppState state, String label, int crf, String sub) {
    final bool isSelected = state.exportCrf == crf;
    final bool isLocked = crf == 0 && !state.isUnlimited && !state.isTrialActive;

    return Expanded(
      child: GestureDetector(
        onTap: isLocked ? () {
          _showProBenefits(context);
        } : () => state.setExportCrf(crf),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF2D55).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isLocked ? Colors.white.withOpacity(0.08) : (isSelected ? const Color(0xFFFF2D55) : Colors.white.withOpacity(0.08))),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: isSelected ? Colors.white : Colors.grey)),
                  if (isLocked) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_rounded, color: Colors.grey, size: 10),
                  ]
                ],
              ),
              const SizedBox(height: 4),
              Text(crf == 0 ? "RAW" : "CRF $crf", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isLocked ? Colors.white24 : (isSelected ? const Color(0xFFFF2D55) : Colors.white24))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateHub(BuildContext context, AppState state) {
    final String latestVer = state.updateData?['latest_version'] as String? ?? "0.0.0";
    final String notes = state.updateData?['release_notes'] as String? ?? "NO RELEASE NOTES AVAILABLE.";
    final noteLines = notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("UPDATE HUB", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text("CURRENT SYSTEM: ${state.appVersion.toUpperCase()}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5)),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
                child: IconButton(
                  onPressed: () => state.setStatus("SETTINGS"),
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // PREMIUM STATUS CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.hasUpdate ? const Color(0xFFFF2D55) : const Color(0xFF10B981),
                    boxShadow: [
                      BoxShadow(
                        color: (state.hasUpdate ? const Color(0xFFFF2D55) : const Color(0xFF10B981)).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.hasUpdate ? "NEW BUILD FOUND" : "SYSTEM UP TO DATE", 
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11, 
                          color: state.hasUpdate ? const Color(0xFFFF2D55) : const Color(0xFF10B981))),
                      const SizedBox(height: 4),
                      Text(state.hasUpdate ? "STABLE BUILD $latestVer IS READY FOR DEPLOYMENT" : "YOU ARE RUNNING THE LATEST OPTIMIZED VERSION", 
                        style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (state.hasUpdate)
                  const Text("CRITICAL", style: TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          const Text("CHANGELOG", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 16),
          
          // TERMINAL CHANGELOG CONSOLE
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: noteLines.map((line) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "» ",
                            style: TextStyle(
                              color: Color(0xFFFF2D55),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                height: 1.4,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // ACTION HUB
          _buildUpdateActionHub(context, state),
        ],
      ),
    );
  }

  Widget _buildUpdateActionHub(BuildContext context, AppState state) {
    if (state.updateStatus == "DOWNLOADING") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("DOWNLOADING SYSTEM UPDATE...", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white24, fontSize: 8, letterSpacing: 1)),
              Text("${(state.downloadProgress * 100).toInt()}%", 
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF2D55), fontSize: 13, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.downloadProgress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2D55)),
            ),
          ),
        ],
      );
    }
    
    String btnText = "CHECK FOR UPDATES";
    if (state.updateStatus == "CHECKING") btnText = "SYNCING...";
    if (state.updateStatus == "UP_TO_DATE_FEEDBACK") btnText = "SYNC COMPLETE";
    if (state.updateStatus == "DOWNLOAD_READY") btnText = "INSTALL UPDATE";
    if (state.updateStatus == "COMPLETE") btnText = "EXECUTING...";
    
    final bool isBusy = state.updateStatus == "CHECKING" || state.updateStatus == "UP_TO_DATE_FEEDBACK" || state.updateStatus == "COMPLETE";
    final bool useGradient = state.hasUpdate || state.updateStatus == "DOWNLOAD_READY";

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: useGradient
            ? const LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFFD81B4B)])
            : null,
        color: useGradient ? null : Colors.white.withOpacity(0.03),
        border: useGradient
            ? null
            : Border.all(color: const Color(0xFF1E293B)),
        boxShadow: useGradient ? [
          BoxShadow(
            color: const Color(0xFFFF2D55).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: ElevatedButton(
        onPressed: isBusy ? null : () {
          if (state.updateStatus == "DOWNLOAD_READY") {
            state.downloadAndUpdate();
          } else {
            state.checkForUpdates();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11)),
      ),
    );
  }

  Widget _buildMainBottomNavBar(BuildContext context, AppState state) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavBarItem(
                  icon: Icons.track_changes_rounded,
                  label: "WORKSTATION",
                  isActive: state.status == "HOME",
                  onTap: () => state.setStatus("HOME"),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                _buildNavBarItem(
                  icon: Icons.person_rounded,
                  label: "ACCOUNT",
                  isActive: state.status == "ACCOUNT",
                  onTap: () => state.setStatus("ACCOUNT"),
                ),
                _buildNavBarItem(
                  icon: Icons.settings_rounded,
                  label: "SETTINGS",
                  isActive: state.status == "SETTINGS" || state.status == "UPDATE",
                  onTap: () => state.setStatus("SETTINGS"),
                  showDot: state.hasUpdateNotification,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool showDot = false,
    BorderRadius? borderRadius,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 16 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55),
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2D55).withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? const Color(0xFFFF2D55) : Colors.white24,
                  size: 20,
                ),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2D55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF05070E),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white24,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// New Top-Level Pages (formerly Modal Bottom Sheets / Slide-Ups)
// -------------------------------------------------------------

class AccountPage extends StatelessWidget {
  final AppState state;
  const AccountPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final hasPremium = state.isUnlimited;
    final hasTrial = state.isTrialActive;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          
          // 1. Profile Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                // Circular Monogram Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38121E).withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFFFF2D55),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                // Email
                Text(
                  state.currentUser?.email ?? "GUEST",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // UID
                Text(
                  "UID: ${state.currentUser?.id ?? 'N/A'}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Badge
                if (hasPremium) ...[
                  _buildBadge(
                    text: "PREMIUM PASS",
                    icon: Icons.bolt_rounded,
                    bgColor: const Color(0xFF2C1E12),
                    borderColor: const Color(0xFFE5A93C),
                    textColor: const Color(0xFFE5A93C),
                  ),
                ] else if (hasTrial) ...[
                  _buildBadge(
                    text: "FREE TRIAL (${state.trialDaysRemaining}D LEFT)",
                    bgColor: const Color(0xFF1C142A),
                    borderColor: const Color(0xFFFF2D55),
                    textColor: const Color(0xFFFF2D55),
                  ),
                ] else ...[
                  _buildBadge(
                    text: "EXPIRED ACCESS",
                    bgColor: const Color(0xFF1C1C1C),
                    borderColor: Colors.white24,
                    textColor: Colors.white38,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Feature Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                // Icon based on status
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasPremium 
                        ? const Color(0xFF10B981).withOpacity(0.08) 
                        : (hasTrial 
                            ? Colors.blue.withOpacity(0.08) 
                            : const Color(0xFFFF2D55).withOpacity(0.08)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasPremium 
                        ? Icons.check_circle_outline_rounded 
                        : (hasTrial ? Icons.info_outline_rounded : Icons.lock_outline_rounded),
                    color: hasPremium 
                        ? const Color(0xFF10B981) 
                        : (hasTrial ? Colors.blue : const Color(0xFFFF2D55)),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPremium 
                            ? "Unlimited Workstation Access" 
                            : (hasTrial ? "Standard Trial Access" : "Restricted Access Mode"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasPremium 
                            ? "Enjoy unlimited cuts, lossless exports, and cloud backups."
                            : (hasTrial 
                                ? "${state.dailyScansUsed} of ${state.maxDailyScans} daily scans used today."
                                : "Your trial has expired. Upgrade to PRO to resume unlimited cuts."),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Upgrade CTA (trial / expired users only) ────
          if (!hasPremium) GestureDetector(
            onTap: () => launchUrl(Uri.parse("https://www.cfxstudios.in/scp-premium"), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.35), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFFFF2D55), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Upgrade to Premium",
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasTrial
                              ? "Unlock unlimited scans, lossless export & cloud backup."
                              : "Your trial has expired — restore full access now.",
                          style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "GET PRO",
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: state.isDriveConnected 
                        ? const Color(0xFF10B981).withOpacity(0.08) 
                        : Colors.white.withOpacity(0.02),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state.isDriveConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    color: state.isDriveConnected ? const Color(0xFF10B981) : Colors.white24,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Google Drive Backup",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.isDriveConnected 
                            ? "Connected to Google Drive" 
                            : "Backup is offline. Tap to connect.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.isDriveConnected,
                  onChanged: (v) => state.isDriveConnected ? state.disconnectDrive() : state.connectDrive(),
                  activeThumbColor: const Color(0xFF10B981),
                  activeTrackColor: const Color(0xFF10B981).withOpacity(0.2),
                  inactiveThumbColor: Colors.white24,
                  inactiveTrackColor: Colors.white.withOpacity(0.02),
                ),
              ],
            ),
          ),

          if (state.isDriveConnected) ...[
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => state.updateCloudFolderName(v),
              controller: TextEditingController(text: state.cloudFolderName)..selection = TextSelection.collapsed(offset: state.cloudFolderName.length),
              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.015),
                hintText: "CFX_SCP_SYNC",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                ),
                prefixIcon: const Icon(Icons.folder_open_rounded, color: Color(0xFF10B981), size: 16),
              ),
            ),
          ],

          // 4. Device Deregistration (if premium)
          if (hasPremium) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phonelink_erase_rounded,
                      color: Color(0xFFFF2D55),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Device Unbinding",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Deregister this device to use license elsewhere.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final success = await state.deregisterDevice();
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("DEVICE DEREGISTERED SUCCESSFULLY"),
                          backgroundColor: Color(0xFF10B981),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("FAILED TO DEREGISTER DEVICE"),
                          backgroundColor: Color(0xFFFF2D55),
                        ));
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF2D55),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFFFF2D55).withOpacity(0.2)),
                      ),
                    ),
                    child: const Text("UNBIND", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
          
          // 5. Sign Out Button
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => state.logout(),
              icon: const Icon(Icons.exit_to_app_rounded, size: 18),
              label: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    IconData? icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            fontSize: 9,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String sub, VoidCallback onTap, {Color color = Colors.white24}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.15), width: 1),
                ),
                child: Icon(icon, color: color == Colors.white24 ? Colors.white38 : color, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                    const SizedBox(height: 3),
                    Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.04), indent: 68, endIndent: 0),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF2D55), Color(0xFFD81B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.5, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── System (Update Hub) ──────────────────────────
          _buildSectionHeader("SYSTEM", Icons.settings_rounded, Colors.white38),
          const SizedBox(height: 12),
          _buildSettingsCard([
            _buildSettingsTile(
              Icons.system_update_rounded,
              "UPDATE HUB",
              "Check for latest app updates & release notes",
              () {
                state.clearUpdateNotification();
                state.setStatus("UPDATE");
              },
              color: state.hasUpdateNotification ? const Color(0xFFFF2D55) : Colors.white24,
            ),
            _buildSettingsTile(
              Icons.delete_sweep_rounded,
              "CLEAN CACHE",
              "Clear review frames, thumbnails, and captures",
              () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0E17),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2D55))),
                            SizedBox(width: 20),
                            Text("Clearing cache...", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    );
                  },
                );

                try {
                  await CacheManager.clearDetectionCache();
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 14),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "CACHE CLEARED SUCCESSFULLY", 
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF0C0E17),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: const Color(0xFFFF2D55).withOpacity(0.35), width: 1),
                        ),
                        elevation: 6,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: const Color(0xFFFF2D55).withOpacity(0.12), shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, color: Color(0xFFFF2D55), size: 14),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "FAILED TO CLEAR CACHE: $e".toUpperCase(), 
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF0C0E17),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: const Color(0xFFFF2D55).withOpacity(0.35), width: 1),
                        ),
                        elevation: 6,
                      ),
                    );
                  }
                }
              },
              color: const Color(0xFFFF2D55),
            ),
            _buildSettingsTile(
              Icons.bug_report_rounded,
              "REPORT ISSUE",
              "Report bugs or system errors directly to support",
              () => launchUrl(Uri.parse("https://cfxstudios.in//report-issue"), mode: LaunchMode.externalApplication),
              color: const Color(0xFFFFAA00),
            ),
          ]),
          const SizedBox(height: 28),

          // ── Workstation Guide ────────────────────────────
          _buildSectionHeader("WORKSTATION GUIDE", Icons.tune_rounded, const Color(0xFFFF2D55)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            ),
            child: Column(
              children: [
                _buildInstructionItem("1", "Use ACTION (0.32) for fast-paced edits, sports, or reels with high motion."),
                Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.04), indent: 52),
                _buildInstructionItem("2", "Use SENSITIVE (0.15) for cinematic, stable, or tripod shots to catch subtle transitions."),
                Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.04), indent: 52),
                _buildInstructionItem("3", "Use BALANCED (0.23) for standard movies, music videos, and general content."),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Support & Links ──────────────────────────────
          _buildSectionHeader("SUPPORT & LINKS", Icons.support_agent_rounded, const Color(0xFF229ED9)),
          const SizedBox(height: 12),
          _buildSettingsCard([
            _buildSettingsTile(
              Icons.send_rounded,
              "TELEGRAM CHAT",
              "Message @cfxstudios for instant support",
              () => launchUrl(Uri.parse("https://t.me/cfxstudios"), mode: LaunchMode.externalApplication),
              color: const Color(0xFF229ED9),
            ),
            _buildSettingsTile(
              Icons.mail_outline_rounded,
              "EMAIL SUPPORT",
              "dilipparvee@gmail.com",
              () => launchUrl(Uri.parse("mailto:dilipparvee@gmail.com")),
              color: const Color(0xFFFF2D55),
            ),
            _buildSettingsTile(
              Icons.language_rounded,
              "EXPLORE PRODUCTS",
              "Visit our official website cfxstudios.in",
              () => launchUrl(Uri.parse("https://cfxstudios.in"), mode: LaunchMode.externalApplication),
              color: const Color(0xFF10B981),
            ),
          ]),
          const SizedBox(height: 28),

          // ── Developer Tools (admin only) ─────────────────
          if (state.currentUser?.email == 'dilipkumar16398@gmail.com') ...[
            _buildSectionHeader("DEVELOPER TOOLS", Icons.terminal_rounded, const Color(0xFFFFAA00)),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSettingsTile(
                Icons.lock_reset_rounded,
                "RESET ELITE ACCESS",
                "Removes premium license status locally",
                () async {
                  await state.resetEliteAccess();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("ELITE ACCESS RESET"),
                    backgroundColor: Color(0xFFFF2D55),
                  ));
                },
                color: const Color(0xFFFF2D55),
              ),
              _buildSettingsTile(
                Icons.refresh_rounded,
                "CLEAR DAILY USAGE",
                "Resets today's scan usage count",
                () async {
                  await state.resetDailyUsage();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("DAILY USAGE RESET"),
                    backgroundColor: Color(0xFF10B981),
                  ));
                },
                color: const Color(0xFF10B981),
              ),
              _buildSettingsTile(
                Icons.power_settings_new_rounded,
                "SYSTEM CACHE REBOOT",
                "Clears all temporary application cache",
                () async {
                  final Directory tempDir = await getTemporaryDirectory();
                  if (await tempDir.exists()) await tempDir.delete(recursive: true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("SYSTEM REBOOTED"),
                    backgroundColor: Colors.blue,
                  ));
                },
                color: Colors.blue,
              ),
            ]),
            const SizedBox(height: 28),
          ],

          // ── Footer ───────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(width: 32, height: 1, color: Colors.white10),
                const SizedBox(height: 16),
                const Text(
                  "CFX SCP",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 5, color: Colors.white12),
                ),
                const SizedBox(height: 4),
                const Text(
                  "\u00a9 2025 All Rights Reserved",
                  style: TextStyle(fontSize: 9, color: Colors.white12, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PickerButton extends StatefulWidget {

  final Function(String) onVideoSelected;
  const _PickerButton({required this.onVideoSelected});
  @override
  _PickerButtonState createState() => _PickerButtonState();
}

class _PickerButtonState extends State<_PickerButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF2D55), Color(0xFFD81B4B)],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Consumer<AppState>(
        builder: (context, state, child) {
          final bool isDailyLocked = !state.canScan;
          final bool isUiLocked = state.isUiLocked;
          final bool isLocked = isDailyLocked || isUiLocked;
          
          return ElevatedButton.icon(
            onPressed: _isLoading 
                ? null 
                : (isLocked 
                    ? () => AppNavigator.showActivationPortal(context, state) 
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          debugPrint("ENGINE: User clicked SELECT VIDEO");
                          
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.video,
                            allowCompression: false,
                          );
                          
                          if (result != null && result.files.single.path != null) {
                            debugPrint("ENGINE: Video selected: ${result.files.single.path}");
                            widget.onVideoSelected(result.files.single.path!);
                          } else {
                            debugPrint("ENGINE: Picker returned null (User cancelled or no access)");
                          }
                        } catch (e) {
                           debugPrint("ENGINE ERROR: $e");
                           if (mounted) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("IMPORT ERROR"),
                                  content: Text("Your phone blocked the media import engine. Error: $e"),
                                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
                                ),
                              );
                           }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      }),
            icon: _isLoading 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(isLocked ? Icons.lock_rounded : Icons.add_rounded),
            label: Text(
              _isLoading 
                  ? "WAKING SYSTEM..." 
                  : (isUiLocked 
                      ? "TRIAL EXPIRED" 
                      : (isDailyLocked ? "DAILY LIMIT REACHED" : "SELECT VIDEO")), 
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              minimumSize: const Size(240, 64),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        },
      ),
    );
  }
}

class _StudioMasterPlayer extends StatefulWidget {
  final String videoPath;
  final double fps;
  final Function(double) onTimeUpdate;
  final bool showJogControls;
  const _StudioMasterPlayer({
    required this.videoPath, 
    required this.fps, 
    required this.onTimeUpdate,
    this.showJogControls = false,
  });
  @override
  _StudioMasterPlayerState createState() => _StudioMasterPlayerState();
}

class _StudioMasterPlayerState extends State<_StudioMasterPlayer> {
  late VideoPlayerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        _controller.setVolume(0); // Mute by default
        setState(() {});
      });
    _controller.addListener(() => widget.onTimeUpdate(_controller.value.position.inMilliseconds / 1000.0));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _stepFrame(int frames) {
    if (!_controller.value.isInitialized) return;
    // Upgrade to Microsecond Precision (1000x more accurate than milliseconds)
    final double frameDurationUs = 1000000.0 / widget.fps;
    final Duration currentPosition = _controller.value.position;
    final Duration newPosition = currentPosition + Duration(microseconds: (frames * frameDurationUs).toInt());
    _controller.seekTo(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) return const AspectRatio(aspectRatio: 16/9, child: Center(child: CircularProgressIndicator()));
    return Column(
      children: [
        Container(
          height: 380,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
              _EliteControlsOverlay(controller: _controller),
              VideoProgressIndicator(_controller, 
                allowScrubbing: true, 
                colors: const VideoProgressColors(
                  playedColor: Color(0xFFFF2D55),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.black45,
                ),
              ),
            ],
          ),
        ),
        if (widget.showJogControls) ...[
          const SizedBox(height: 16),
          // Jog Dial / Scrubbing Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                _JogButton(label: "-1 F", icon: Icons.arrow_left_rounded, onTap: () => _stepFrame(-1)),
                Expanded(
                  child: _JogDial(onDialMoved: (delta) {
                    if (delta.abs() > 5) {
                      _stepFrame(delta > 0 ? 1 : -1);
                    }
                  }),
                ),
                _JogButton(label: "+1 F", icon: Icons.arrow_right_rounded, onTap: () => _stepFrame(1)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _JogButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _JogButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF080A10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF2D55), size: 20),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _JogDial extends StatefulWidget {
  final Function(double) onDialMoved;
  const _JogDial({required this.onDialMoved});

  @override
  _JogDialState createState() => _JogDialState();
}

class _JogDialState extends State<_JogDial> {
  double _accumulatedDrag = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        _accumulatedDrag += details.delta.dx;
        if (_accumulatedDrag.abs() >= 12.0) { // Every 12 pixels = 1 frame
          widget.onDialMoved(_accumulatedDrag);
          _accumulatedDrag = 0;
        }
      },
      onHorizontalDragEnd: (_) => _accumulatedDrag = 0,
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFFFF2D55).withOpacity(0.05),
              const Color(0xFFFF2D55).withOpacity(0.1),
              const Color(0xFFFF2D55).withOpacity(0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dial Tick Marks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(20, (i) => Container(
                width: 1,
                height: i % 5 == 0 ? 20 : 10,
                color: Colors.white12,
              )),
            ),
            // Center Indicator
            Container(
              width: 2,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55),
                boxShadow: [BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.5), blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EliteControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  const _EliteControlsOverlay({required this.controller});

  @override
  _EliteControlsOverlayState createState() => _EliteControlsOverlayState();
}

class _EliteControlsOverlayState extends State<_EliteControlsOverlay> {
  bool _isVisible = true;

  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isVisible = !_isVisible),
      child: AnimatedOpacity(
        opacity: _isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black26,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ValueListenableBuilder(
                        valueListenable: widget.controller,
                        builder: (context, VideoPlayerValue value, child) {
                          return Text(
                            "${_formatDuration(value.position)} / ${_formatDuration(value.duration)}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        widget.controller.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          widget.controller.setVolume(widget.controller.value.volume == 0 ? 1.0 : 0.0);
                        });
                      },
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlBtn(Icons.replay_5_rounded, () {
                    widget.controller.seekTo(widget.controller.value.position - const Duration(seconds: 5));
                  }),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Color(0xFFFF2D55), shape: BoxShape.circle),
                      child: Icon(
                        widget.controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  _controlBtn(Icons.forward_5_rounded, () {
                    widget.controller.seekTo(widget.controller.value.position + const Duration(seconds: 5));
                  }),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 32),
      onPressed: onTap,
    );
  }
}

/// Optimized Tech-Grid Background with constant RepaintBoundary to eliminate rebuild overhead
class TechGridBackground extends StatelessWidget {
  const TechGridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 16,
        ),
        itemCount: 256, // Cap layout count to prevent infinite cell layouts
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withOpacity(0.006),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

