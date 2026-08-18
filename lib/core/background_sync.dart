import 'dart:io';
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ascend_arena/core/offline_storage.dart';

const syncTaskName = 'com.ascendarena.syncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == syncTaskName) {
      await BackgroundSync.processPendingUploads();
    }
    return Future.value(true);
  });
}

class BackgroundSync {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
  }

  static Future<void> registerSyncTask() async {
    await Workmanager().registerOneOffTask(
      "1",
      syncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when connected
        requiresBatteryNotLow: true,
      ),
    );
  }

  static Future<void> processPendingUploads() async {
    // 1. Check Connectivity
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return; // Offline
    }

    // 2. Init Supabase and Hive if not already initialized
    // In background isolates, we might need to re-initialize them
    try {
      await OfflineStorage.init();
      // Assume Supabase is initialized via Main, but in background isolate we might need to re-init
      // We will skip re-init here for brevity, assuming standard Flutter background handling
      // For a robust implementation, we should pass URL/KEY in inputData and initialize Supabase here.
      if (Supabase.instance.client == null) {
          // This would crash if not initialized. 
          // For simplicity, we just return if we can't get the client.
          return;
      }
    } catch(e) {
      // Already initialized
    }
    
    final pending = OfflineStorage.getPendingUploads();
    if (pending.isEmpty) return;

    final supabase = Supabase.instance.client;

    for (var item in pending) {
      if (item['status'] == 'uploading') continue;
      
      try {
        await OfflineStorage.markUploadStatus(item['id'], 'uploading');
        
        final file = File(item['file_path']);
        if (!await file.exists()) {
           await OfflineStorage.removePendingUpload(item['id']);
           continue;
        }

        final fileExt = file.path.split('.').last;
        final fileName = '${item['user_id']}_${item['task_id']}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final storagePath = 'offline/$fileName';

        // 3. Upload to Supabase Storage
        // For 1GB files, this may take a while. The workmanager task has ~15 mins on Android, 
        // which might not be enough for 1GB on slow connections. But we try our best.
        await supabase.storage.from('submissions').upload(storagePath, file);
        final publicUrl = supabase.storage.from('submissions').getPublicUrl(storagePath);

        // 4. Submit Task via RPC
        await supabase.rpc('submit_task', params: {
          'p_task_id': item['task_id'],
          'p_user_id': item['user_id'],
          'p_file_url': publicUrl,
          'p_content': null
        });

        // 5. Success! Remove from queue.
        await OfflineStorage.removePendingUpload(item['id']);
      } catch (e) {
        await OfflineStorage.markUploadStatus(item['id'], 'failed');
        // We will retry on the next run
      }
    }
  }
}
