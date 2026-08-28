import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gemini_service.dart';

class ReferralService {
  static String get _baseUrl => GeminiService.serverUrl;

  static Future<String> getMyCode() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    if (phone == null) throw Exception('Not logged in');
    final resp = await http.get(Uri.parse('$_baseUrl/referral/my-code/$phone'));
    if (resp.statusCode != 200) throw Exception('Failed to get referral code');
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['referral_code'] as String;
  }

  static Future<String> generateCode() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    if (phone == null) throw Exception('Not logged in');
    final resp = await http.post(
      Uri.parse('$_baseUrl/referral/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to generate code');
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['referral_code'] as String;
  }

  static Future<String> applyCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    if (phone == null) throw Exception('Not logged in');
    final resp = await http.post(
      Uri.parse('$_baseUrl/referral/apply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['error'] as String? ?? 'Failed to apply code');
    }
    return 'free_month';
  }
}