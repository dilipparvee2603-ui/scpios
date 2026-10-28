import 'dart:convert';
import 'package:http/http.dart' as http;

class SupabaseService {
  static const String _url = "https://ekyeqlgtkqquwoxuqjmv.supabase.co";
  static const String _key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVreWVxbGd0a3FxdXdveHVxam12Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3NDkxODMsImV4cCI6MjA5NzMyNTE4M30.Na76-0KscsFkweVwl4m5tcNLnV9XKXoDAimGmLQDN0M";

  static Map<String, String> _headers([String? bearer]) {
    final headers = {
      'apikey': _key,
      'Content-Type': 'application/json',
    };
    if (bearer != null && bearer.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearer';
    }
    return headers;
  }

  // signup
  static Future<Map<String, dynamic>> signUp(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$_url/auth/v1/signup"),
        headers: _headers(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['user'] != null) {
          return {'status': 'ok', 'message': 'Account created successfully! You can now log in.'};
        }
      }
      final error = body['message'] ?? body['msg'] ?? 'Signup failed';
      return {'status': 'error', 'message': error};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$_url/auth/v1/token?grant_type=password"),
        headers: _headers(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'status': 'ok', 'data': body};
      }
      final error = body['error_description'] ?? body['message'] ?? 'Invalid email or password';
      return {'status': 'invalid', 'message': error};
    } catch (e) {
      return {'status': 'invalid', 'message': e.toString()};
    }
  }

  // refresh session
  static Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse("$_url/auth/v1/token?grant_type=refresh_token"),
        headers: _headers(),
        body: jsonEncode({
          'refresh_token': refreshToken,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'status': 'ok', 'data': body};
      }
      return {'status': 'error', 'message': 'Session refresh failed'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // fetch profile
  static Future<Map<String, dynamic>?> getProfile(String userId, String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse("$_url/rest/v1/profiles?id=eq.$userId"),
        headers: _headers(accessToken),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        if (list.isNotEmpty) {
          return list.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      // Offline fallback or error
    }
    return null;
  }

  // create profile (if it does not exist)
  // create profile (if it does not exist)
  static Future<void> createProfile(String userId, String email, String? hwid, String accessToken) async {
    try {
      await http.post(
        Uri.parse("$_url/rest/v1/profiles"),
        headers: {
          ..._headers(accessToken),
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'id': userId,
          'email': email,
          'is_premium': false,
          'hardware_id': hwid,
        }),
      );
    } catch (e) {
      // Ignored
    }
  }

  // update hardware id
  static Future<bool> updateHardwareId(String userId, String? hwid, String accessToken) async {
    try {
      final response = await http.patch(
        Uri.parse("$_url/rest/v1/profiles?id=eq.$userId"),
        headers: _headers(accessToken),
        body: jsonEncode({
          'hardware_id': hwid,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  // check if device has other user registered
  static Future<bool> checkDeviceHasOtherUser(String hwid, String? userId) async {
    try {
      final encodedHwid = Uri.encodeComponent(hwid);
      final response = await http.get(
        Uri.parse("$_url/rest/v1/profiles?hardware_id=eq.$encodedHwid&id=neq.$userId"),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.isNotEmpty;
      }
    } catch (e) {
      // Ignored
    }
    return false;
  }

  // check pending payment requests
  static Future<bool> checkPendingRequests(String userId, String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse("$_url/rest/v1/payment_requests?user_id=eq.$userId&status=eq.pending"),
        headers: _headers(accessToken),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.isNotEmpty;
      }
    } catch (e) {
      // Ignored
    }
    return false;
  }

  // submit transaction
  static Future<Map<String, dynamic>> submitTransaction(String userId, String email, String txId, String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse("$_url/rest/v1/payment_requests"),
        headers: _headers(accessToken),
        body: jsonEncode({
          'user_id': userId,
          'email': email,
          'transaction_id': txId.trim(),
          'status': 'pending',
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'status': 'ok', 'message': 'Payment request submitted successfully.'};
      }
      final body = jsonDecode(response.body);
      final error = body['message'] ?? 'Failed to submit transaction request.';
      return {'status': 'error', 'message': error};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // recover password
  static Future<Map<String, dynamic>> recoverPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$_url/auth/v1/recover"),
        headers: _headers(),
        body: jsonEncode({
          'email': email,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'status': 'ok', 'message': 'Password recovery email sent!'};
      }
      final body = jsonDecode(response.body);
      final error = body['message'] ?? 'Failed to send recovery email';
      return {'status': 'error', 'message': error};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // check if email is temporary/disposable
  static Future<bool> isDisposableEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@')) return false;
    final domain = cleanEmail.split('@').last.trim();
    
    // Top common disposable email domains
    const commonDisposableDomains = {
      '10minutemail.com', 'tempmail.com', 'yopmail.com', 'guerrillamail.com',
      'guerrillamailblock.com', 'guerrillamail.net', 'guerrillamail.org',
      'guerrillamail.biz', 'sharklasers.com', 'grr.la', 'pokemail.net',
      'dispostable.com', 'mailinator.com', 'maildrop.cc', 'getairmail.com',
      'throwawaymail.com', 'tempmailaddress.com', 'boun.cr', 'mailcatch.com',
      'mailnesia.com', 'mintemail.com', 'spambox.us', 'mytrashmail.com',
      'trashmail.com', 'temp-mail.org', 'emailondeck.com', 'crazymailing.com',
      'owlymail.com', 'generator.email', 'tempmail.net'
    };
    
    if (commonDisposableDomains.contains(domain)) {
      return true;
    }
    
    // Dynamic public API check with a 2-second timeout
    try {
      final response = await http.get(
        Uri.parse("https://disposable.debounce.io/?email=$cleanEmail"),
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['disposable'] == 'true' || body['disposable'] == true;
      }
    } catch (_) {
      // Gracefully fallback to allow signup if API is down
    }
    return false;
  }
}
