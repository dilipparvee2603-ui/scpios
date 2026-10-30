import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ScenePackProject {
  final String id;
  String title;
  final String videoPath;
  String? thumbnailPath;
  double duration;
  double fps;
  double aspectRatio;
  List<Map<String, dynamic>> scenes;
  Set<int> selectedIndices;
  DateTime createdAt;
  DateTime lastModified;
  String toolMode; // 'DETECTION' or 'FRAME_PACK'

  ScenePackProject({
    required this.id,
    required this.title,
    required this.videoPath,
    this.thumbnailPath,
    this.duration = 0.0,
    this.fps = 30.0,
    this.aspectRatio = 16 / 9,
    List<Map<String, dynamic>>? scenes,
    Set<int>? selectedIndices,
    DateTime? createdAt,
    DateTime? lastModified,
    this.toolMode = 'DETECTION',
  })  : scenes = scenes ?? [],
        selectedIndices = selectedIndices ?? {},
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'videoPath': videoPath,
        'thumbnailPath': thumbnailPath,
        'duration': duration,
        'fps': fps,
        'aspectRatio': aspectRatio,
        'scenes': scenes,
        'selectedIndices': selectedIndices.toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
        'toolMode': toolMode,
      };

  factory ScenePackProject.fromJson(Map<String, dynamic> json) {
    return ScenePackProject(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Project',
      videoPath: json['videoPath'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      fps: (json['fps'] as num?)?.toDouble() ?? 30.0,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? (16 / 9),
      scenes: (json['scenes'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      selectedIndices: (json['selectedIndices'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          {},
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'] as String) ?? DateTime.now()
          : DateTime.now(),
      toolMode: json['toolMode'] as String? ?? 'DETECTION',
    );
  }
}

class ProjectManager {
  static const String projectsFolderName = 'scenepack_projects';

  /// Directory inside cache/temp directory where projects live
  static Future<Directory> getProjectsDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final projDir = Directory(path.join(tempDir.path, projectsFolderName));
    if (!await projDir.exists()) {
      await projDir.create(recursive: true);
    }
    return projDir;
  }

  /// Load all projects sorted by lastModified descending
  static Future<List<ScenePackProject>> loadAllProjects() async {
    final List<ScenePackProject> list = [];
    try {
      final dir = await getProjectsDirectory();
      if (!await dir.exists()) return list;

      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content);
            list.add(ScenePackProject.fromJson(json));
          } catch (_) {
            // Ignore corrupted project files
          }
        }
      }
      list.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    } catch (_) {}
    return list;
  }

  /// Save or update a project to the cache directory
  static Future<void> saveProject(ScenePackProject project) async {
    try {
      project.lastModified = DateTime.now();
      final dir = await getProjectsDirectory();
      final file = File(path.join(dir.path, '${project.id}.json'));
      await file.writeAsString(jsonEncode(project.toJson()));
    } catch (_) {}
  }

  /// Delete a single project
  static Future<void> deleteProject(String id) async {
    try {
      final dir = await getProjectsDirectory();
      final file = File(path.join(dir.path, '$id.json'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Clear all saved projects
  static Future<void> clearAllProjects() async {
    try {
      final dir = await getProjectsDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
