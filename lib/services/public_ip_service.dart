import 'dart:convert';

import 'package:http/http.dart' as http;

class PublicIpResult {
  final String? ip;
  final String? isp;

  const PublicIpResult({this.ip, this.isp});
}

/// Fetches the public IP and ISP/organization name. Meant to be
/// called periodically by the provider rather than on every rebuild,
/// since it's a network round trip against a third-party API.
class PublicIpService {
  // Primary: returns both IP and ISP/org in one call.
  static const String _ipInfoApi = 'https://ipapi.co/json/';

  // Fallback: IP only, used if the primary lookup fails.
  static const String _ipOnlyApi = 'https://api.ipify.org?format=json';

  Future<PublicIpResult> getPublicIpInfo() async {
    try {
      final response = await http
          .get(Uri.parse(_ipInfoApi))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        return PublicIpResult(
          ip: data['ip'] as String?,
          isp: (data['org'] as String?) ?? (data['asn'] as String?),
        );
      }
    } catch (_) {
      // fall through to the fallback lookup below
    }

    return PublicIpResult(ip: await _fallbackIp(), isp: null);
  }

  Future<String?> _fallbackIp() async {
    try {
      final response = await http
          .get(Uri.parse(_ipOnlyApi))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['ip'] as String?;
    } catch (_) {
      return null;
    }
  }
}
