import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';
import '../config/theme.dart';

class UpdateService {
  final Dio _dio = Dio();

  Future<void> checkForUpdate(BuildContext context, {bool showNoUpdate = false}) async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      final response = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.checkUpdate}',
        queryParameters: {'version': currentVersion},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        bool hasUpdate = data['has_update'] ?? false;

        if (hasUpdate) {
          String newVersion = data['version'];
          String updateUrl = data['update_url'];
          String notes = data['notes'] ?? 'New version available.';
          bool isMandatory = data['mandatory'] ?? false;

          if (context.mounted) {
            _showUpdateDialog(context, newVersion, updateUrl, notes, isMandatory);
          }
        } else if (showNoUpdate) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('App is up to date ✓')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Update check error: $e');
    }
  }

  void _showUpdateDialog(
    BuildContext context,
    String version,
    String url,
    String notes,
    bool mandatory,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: AppTheme.primaryNavy),
            const SizedBox(width: 10),
            const Text('Update Available', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version $version is now available.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(notes, style: const TextStyle(color: AppTheme.textSecondary)),
            if (mandatory) ...[
              const SizedBox(height: 15),
              const Text(
                'This update is required to continue using the app.',
                style: TextStyle(
                  color: AppTheme.errorRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!mandatory)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('LATER', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleUpdate(context, url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('UPDATE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate(BuildContext context, String url) async {
    if (url.toLowerCase().endsWith('.apk')) {
      await _downloadAndInstallApk(context, url);
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _downloadAndInstallApk(BuildContext context, String url) async {
    // Check and request "Install Unknown Apps" permission on Android 8.0+
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final reqStatus = await Permission.requestInstallPackages.request();
        if (!reqStatus.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Installation permission is required to update the app.'),
                backgroundColor: AppTheme.errorRed,
              ),
            );
          }
          return;
        }
      }
    }

    // ValueNotifier to track download progress (0.0 → 1.0)
    final progressNotifier = ValueNotifier<double>(0.0);
    bool dialogPopped = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateProgressDialog(progressNotifier: progressNotifier),
    );

    HttpClient? client;
    try {
      final tempDir = Platform.isAndroid
          ? (await getExternalStorageDirectory()) ?? await getTemporaryDirectory()
          : await getTemporaryDirectory();
      final filePath = '${tempDir.path}/dabaindia_update.apk';

      // Delete old file if exists
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      // Use HttpClient for robust download to avoid dio stream hanging issues
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception("Server returned status code ${response.statusCode}");
      }

      final fileSink = file.openWrite();
      int downloaded = 0;
      final total = response.contentLength;

      await response.forEach((chunk) {
        fileSink.add(chunk);
        downloaded += chunk.length;
        if (total > 0) {
          progressNotifier.value = downloaded / total;
        }
      });

      await fileSink.flush();
      await fileSink.close();
      client.close();
      client = null;

      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogPopped = true;
      }

      // Small delay to let the dialog close transition complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Trigger APK install
      final result = await OpenFile.open(
        filePath,
        type: "application/vnd.android.package-archive",
      );
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e) {
      client?.close();
      if (context.mounted) {
        if (!dialogPopped) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      progressNotifier.dispose();
    }
  }
}

/// Progress dialog with real-time download percentage
class UpdateProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progressNotifier;

  const UpdateProgressDialog({super.key, required this.progressNotifier});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, progress, _) {
          final percent = (progress * 100).toStringAsFixed(0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, color: AppTheme.primaryNavy, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Downloading Update',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please wait, do not close the app.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: AppTheme.primaryNavy.withOpacity(0.1),
                  color: AppTheme.primaryNavy,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                progress > 0 ? '$percent% complete' : 'Connecting...',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryNavy,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
