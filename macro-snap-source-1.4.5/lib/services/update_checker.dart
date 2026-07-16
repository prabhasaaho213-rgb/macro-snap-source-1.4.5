import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static const _owner = 'prabhasaaho213-rgb';
  static const _repo = 'MacroSnap';
  static const _currentVersion = 'v1.2.1';

  static Future<bool> hasUpdate() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
        headers: {'User-Agent': 'MacroSnap'},
      );
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body);
      final latest = data['tag_name'] as String? ?? '';
      return latest.compareTo(_currentVersion) > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (!await hasUpdate()) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New update available!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Download',
          onPressed: () async {
            final url = Uri.parse('https://github.com/$_owner/$_repo/releases/latest');
            if (await canLaunchUrl(url)) await launchUrl(url);
          },
        ),
      ),
    );
  }
}