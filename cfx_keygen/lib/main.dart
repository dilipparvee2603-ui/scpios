import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCkrXJxUUNJ_13gM-gFopj-jNUdTd8Q9lE",
        appId: "1:900813188636:android:c691dc37a3415fa79539d9",
        messagingSenderId: "900813188636",
        projectId: "cfx-scenepack-creator",
      ),
    );
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }
  runApp(const KeyGenApp());
}

class KeyGenApp extends StatelessWidget {
  const KeyGenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CFX Master Keygen',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030408),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF1F1F),
          surface: Color(0xFF11141b),
        ),
        useMaterial3: true,
      ),
      home: const KeyGenScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class KeyGenScreen extends StatefulWidget {
  const KeyGenScreen({super.key});

  @override
  State<KeyGenScreen> createState() => _KeyGenScreenState();
}

class _KeyGenScreenState extends State<KeyGenScreen> {
  String _generatedCode = "";
  List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('history') ?? '[]';
      setState(() {
        _history = List<Map<String, String>>.from(
            json.decode(historyStr).map((x) => Map<String, String>.from(x)));
      });
    } catch (e) {
      debugPrint("Load History Error: $e");
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', json.encode(_history));
  }

  void _generateRandomKey() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    String key = '';
    for (int i = 0; i < 8; i++) {
      if (i == 4) key += '-';
      key += chars[rand.nextInt(chars.length)];
    }

    setState(() {
      _generatedCode = key;
    });

    // PUSH TO CLOUD
    try {
      await FirebaseFirestore.instance.collection('licenses').doc(key).set({
        'status': 'NEW',
        'deviceId': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
         _history.insert(0, {
          'id': "PRO-CLOUD-KEY",
          'code': key,
          'date': DateTime.now().toString().substring(0, 16)
        });
      });
      _saveHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("KEY SYNCED TO CLOUD ✅")));
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("CLOUD SYNC FAILED: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _shareKey(String key) {
    Share.share("🔥 YOUR CFX PRODUCTION SUITE ELITE KEY:\n\n🔑 $key\n\nSupport: @cfxstudios\nStatus: [AUTHENTICATED]");
  }

  void _copyBoth(String id, String code) {
    final text = "LICENSE KEY: $code";
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("License Key copied!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CFX MASTER KEYGEN",
            style: TextStyle(
                fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.vpn_key_rounded, color: Color(0xFFFF1F1F), size: 48),
                const SizedBox(height: 16),
                const Text("GENERATE CLOUD-BOUND PRO KEY",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _generateRandomKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1F1F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: const Color(0xFFFF1F1F).withOpacity(0.5),
                    ),
                    child: const Text("GENERATE & SYNC NEW KEY",
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
                if (_generatedCode.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1F1F).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: const Color(0xFFFF1F1F).withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Text("ACTIVE CLOUD KEY", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(_generatedCode,
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF1F1F),
                                letterSpacing: 4)),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                 Clipboard.setData(ClipboardData(text: _generatedCode));
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Key copied!")));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(30)
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text("COPY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _shareKey(_generatedCode),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF1F1F).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: const Color(0xFFFF1F1F).withOpacity(0.2))
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.share_rounded, size: 14, color: Color(0xFFFF1F1F)),
                                    SizedBox(width: 8),
                                    Text("SHARE KEY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF1F1F))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Colors.white10),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("CLOUD KEY HISTORY",
                    style: TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                GestureDetector(
                  onTap: () {
                    setState(() => _history.clear());
                    _saveHistory();
                  },
                  child: const Text("WIPE",
                      style: TextStyle(color: Colors.white10, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05))
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SECURE CLOUD KEY", style: TextStyle(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(item['code']!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 2)),
                            const SizedBox(height: 4),
                            Text(item['date']!,
                                style: const TextStyle(
                                    color: Colors.white10, fontSize: 9)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                           Clipboard.setData(ClipboardData(text: item['code']!));
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Key copied!")));
                        },
                        icon: const Icon(Icons.copy_rounded,
                            color: Colors.white10, size: 20),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
