import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class VersionCheckService {
  static Future<Map<String, dynamic>> checkVersion() async {
    // Bypass version check for web platform since it doesn't contain versions
    if (kIsWeb) {
      return {
        'needsUpdate': false,
        'updateLink': '',
        'currentVersion': 'web',
        'requiredVersion': 'web',
        'platform': 'web',
      };
    }

    try {
      // Get current app version from phone
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      String buildNumber = packageInfo.buildNumber;

      // Combine version and build number for more accurate comparison
      String fullCurrentVersion = '$currentVersion+$buildNumber';

      print('Current app version: $fullCurrentVersion');
      print('Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');

      // Get required version from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_version')
          .doc('version_info')
          .get();

      if (!doc.exists) {
        print('No version info found in Firestore, using current version');
        return {
          'needsUpdate': false,
          'updateLink': '',
          'currentVersion': currentVersion,
          'requiredVersion': currentVersion,
          'platform': Platform.isIOS ? 'ios' : 'android',
        };
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Get platform-specific version requirements
      String requiredVersion;
      String updateLink;

      if (Platform.isIOS) {
        requiredVersion =
            data['ios_version'] ?? data['current_version'] ?? currentVersion;
        updateLink = data['ios_update_link'] ?? data['update_link'] ?? '';
      } else {
        requiredVersion = data['android_version'] ??
            data['current_version'] ??
            currentVersion;
        updateLink = data['android_update_link'] ?? data['update_link'] ?? '';
      }

      print('Required version: $requiredVersion');
      print('Update link: $updateLink');

      // Improved version comparison
      bool needsUpdate = _compareVersions(currentVersion, requiredVersion) < 0;

      return {
        'needsUpdate': needsUpdate,
        'updateLink': updateLink,
        'currentVersion': currentVersion,
        'requiredVersion': requiredVersion,
        'platform': Platform.isIOS ? 'ios' : 'android',
      };
    } catch (e) {
      print('Error checking version: $e');
      // Return a safe fallback that won't block the app
      return {
        'needsUpdate': false,
        'updateLink': '',
        'currentVersion': '2.0.0',
        'requiredVersion': '2.0.0',
        'platform': Platform.isIOS ? 'ios' : 'android',
        'error': e.toString(),
      };
    }
  }

  static int _compareVersions(String version1, String version2) {
    try {
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
    } catch (e) {
      print('Error comparing versions: $e');
      return 0; // If comparison fails, assume no update needed
    }
  }

  static Future<bool> launchUpdateLink(String url) async {
    if (url.isEmpty) return false;

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Cannot launch URL: $url');
      }
    } catch (e) {
      print('Error launching update link: $e');
    }
    return false;
  }

  // Helper method to get platform-specific update links
  static Future<Map<String, String>> getPlatformUpdateLinks() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_version')
          .doc('version_info')
          .get();

      if (!doc.exists) {
        return {
          'ios': '',
          'android': '',
        };
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return {
        'ios': data['ios_update_link'] ?? data['update_link'] ?? '',
        'android': data['android_update_link'] ?? data['update_link'] ?? '',
      };
    } catch (e) {
      print('Error getting platform update links: $e');
      return {
        'ios': '',
        'android': '',
      };
    }
  }
}
