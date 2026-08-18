import 'package:hive_flutter/hive_flutter.dart';

class OfflineStorage {
  static const String pendingUploadsBox = 'pending_uploads';
  static const String cachedTasksBox = 'cached_tasks';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(pendingUploadsBox);
    await Hive.openBox(cachedTasksBox);
  }

  // --- Task Caching ---
  static Future<void> cacheTasks(String userId, List<Map<String, dynamic>> tasks) async {
    final box = Hive.box(cachedTasksBox);
    await box.put(userId, tasks);
  }

  static List<Map<String, dynamic>> getCachedTasks(String userId) {
    final box = Hive.box(cachedTasksBox);
    final data = box.get(userId);
    if (data == null) return [];
    
    // Hive stores Lists as List<dynamic> so we need to cast them back.
    // Also the map keys might be dynamic.
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // --- Pending Uploads (For Background Sync) ---
  static Future<void> addPendingUpload(String userId, String taskId, String filePath) async {
    final box = Hive.box(pendingUploadsBox);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    await box.put(id, {
      'id': id,
      'user_id': userId,
      'task_id': taskId,
      'file_path': filePath,
      'status': 'pending', // pending, uploading, failed
    });
  }

  static List<Map<String, dynamic>> getPendingUploads() {
    final box = Hive.box(pendingUploadsBox);
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  
  static Future<void> markUploadStatus(String id, String status) async {
    final box = Hive.box(pendingUploadsBox);
    final item = box.get(id);
    if (item != null) {
      item['status'] = status;
      await box.put(id, item);
    }
  }

  static Future<void> removePendingUpload(String id) async {
    final box = Hive.box(pendingUploadsBox);
    await box.delete(id);
  }
}
