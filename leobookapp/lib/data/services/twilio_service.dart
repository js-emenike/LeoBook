// twilio_service.dart: Direct Twilio REST API integration for WhatsApp notifications.
// Part of LeoBook App — Services
//
// Classes: TwilioService

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class TwilioService {
  /// Sends a WhatsApp notification to the user's phone number about a new device login.
  static Future<void> sendDeviceLoginNotification(String userPhone) async {
    try {
      final accountSid = dotenv.env['TWILIO_ACCOUNT_SID'] ?? '';
      final authToken = dotenv.env['TWILIO_AUTH_TOKEN'] ?? '';
      final fromNumber = dotenv.env['TWILIO_WHATSAPP_NUMBER'] ?? '';

      if (accountSid.isEmpty || authToken.isEmpty || fromNumber.isEmpty) {
        debugPrint('[TwilioService] Missing credentials in .env.');
        return;
      }

      // Format the recipient phone number for Twilio's WhatsApp sandbox
      String toWhatsApp = userPhone;
      if (!toWhatsApp.startsWith('whatsapp:')) {
        toWhatsApp = 'whatsapp:$userPhone';
      }

      // Extract device info
      String deviceName = 'Unknown Device';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (kIsWeb) {
          final webBrowserInfo = await deviceInfo.webBrowserInfo;
          deviceName = 'Web Browser (${webBrowserInfo.browserName.name})';
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceName = '${androidInfo.brand} ${androidInfo.model}';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceName = iosInfo.utsname.machine;
        } else {
          deviceName = defaultTargetPlatform.name;
        }
      } catch (_) {}

      // Get IP Address
      String ipAddress = 'Unknown IP';
      try {
        final ipResponse = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 3));
        if (ipResponse.statusCode == 200) {
          final data = json.decode(ipResponse.body);
          ipAddress = data['ip'] ?? 'Unknown IP';
        }
      } catch (_) {}

      final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');
      
      final client = http.Client();
      final request = http.Request('POST', url);
      
      // Basic Authentication
      request.headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}';
      
      // Form Data
      request.bodyFields = {
        'From': fromNumber,
        'To': toWhatsApp,
        'Body': '🔒 Security Alert: A new device just signed into your LeoBook account.\n\n📱 Device: $deviceName\n🌐 IP: $ipAddress\n\nIf this was not you, please secure your account immediately.',
      };

      final response = await client.send(request);
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 201) {
        debugPrint('[TwilioService] WhatsApp notification sent successfully.');
      } else {
        debugPrint('[TwilioService] Failed to send notification: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      debugPrint('[TwilioService] Error sending notification: $e');
    }
  }
}
