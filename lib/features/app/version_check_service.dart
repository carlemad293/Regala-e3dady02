import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class VersionCheckService {
  static Future<Map<String, dynamic>> checkVersion() async {
    // Bypass version check for web platform since it doesn't contain versions
    if (kIsWeb) {
      return {
        'needsUpdate': false,
        'updateLink': '',
        'currentVersion': 'web',
        'requiredVersion': 'web',
      };
    }

    try {
      // Get current app version from phone
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // Get required version from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_version')
          .doc('version_info')
          .get();

      if (!doc.exists) {
        return {
          'needsUpdate': false,
          'updateLink': '',
          'currentVersion': currentVersion,
          'requiredVersion': currentVersion,
        };
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String requiredVersion = data['current_version'] ?? currentVersion;
      String updateLink = data['update_link'] ?? '';

      // Simple comparison: if current version is less than required version, update needed
      bool needsUpdate = _compareVersions(currentVersion, requiredVersion) < 0;

      return {
        'needsUpdate': needsUpdate,
        'updateLink': updateLink,
        'currentVersion': currentVersion,
        'requiredVersion': requiredVersion,
      };
    } catch (e) {
      print('Error checking version: $e');
      return {
        'needsUpdate': false,
        'updateLink': '',
        'currentVersion': '2.0.0',
        'requiredVersion': '2.0.0',
        'error': e.toString(),
      };
    }
  }

  static int _compareVersions(String version1, String version2) {
    List<int> v1 =
        version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> v2 =
        version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad with zeros if needed
    while (v1.length < v2.length) v1.add(0);
    while (v2.length < v1.length) v2.add(0);

    for (int i = 0; i < v1.length; i++) {
      if (v1[i] < v2[i]) return -1;
      if (v1[i] > v2[i]) return 1;
    }
    return 0;
  }

  static Future<bool> launchUpdateLink(String url) async {
    if (url.isEmpty) return false;

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error launching update link: $e');
    }
    return false;
  }
}
