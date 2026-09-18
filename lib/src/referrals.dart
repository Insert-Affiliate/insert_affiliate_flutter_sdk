import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/affiliate_details.dart';

/// Outcome of `createAffiliateForUser` and `verifyAffiliateCode`.
enum AffiliateEnrolmentStatus {
  /// A new affiliate was created for the user and this device is connected.
  created,

  /// The email already belongs to an affiliate of this app. A 6-digit code was
  /// emailed; pass it to `verifyAffiliateCode` to connect this device.
  verificationRequired,

  /// The code was accepted and this device is connected to the existing affiliate.
  connected,

  /// The request failed. See [AffiliateEnrolmentResult.errorCode].
  error,
}

/// Result of enrolling or verifying an in-app referrer.
class AffiliateEnrolmentResult {
  final AffiliateEnrolmentStatus status;

  /// The referrer's name, short code and link when connected.
  final AffiliateDetails? affiliate;

  /// Server error code, e.g. `PROGRAM_DISABLED`, `AFFILIATE_LIMIT_REACHED`,
  /// `INVALID_CODE`, `TOO_MANY_CODES`, `RATE_LIMITED`, or `NETWORK_ERROR`.
  final String? errorCode;
  final String? errorMessage;

  const AffiliateEnrolmentResult({
    required this.status,
    this.affiliate,
    this.errorCode,
    this.errorMessage,
  });

  const AffiliateEnrolmentResult.error(String code, String message)
      : status = AffiliateEnrolmentStatus.error,
        affiliate = null,
        errorCode = code,
        errorMessage = message;

  bool get isConnected =>
      status == AffiliateEnrolmentStatus.created || status == AffiliateEnrolmentStatus.connected;

  /// Parses a 200 response from `/enrol` or `/verify`.
  factory AffiliateEnrolmentResult.fromJson(Map<String, dynamic> json) {
    final status = _statusFromString(json['status']);
    final affiliateJson = json['affiliate'];
    return AffiliateEnrolmentResult(
      status: status,
      affiliate: affiliateJson is Map<String, dynamic>
          ? AffiliateDetails(
              affiliateName: _string(affiliateJson['affiliateName']),
              affiliateShortCode: _string(affiliateJson['affiliateShortCode']),
              deeplinkUrl: _string(affiliateJson['deeplinkurl']),
            )
          : null,
      errorCode: status == AffiliateEnrolmentStatus.error ? 'INVALID_RESPONSE' : null,
    );
  }

  static AffiliateEnrolmentStatus _statusFromString(Object? value) {
    switch (value) {
      case 'created':
        return AffiliateEnrolmentStatus.created;
      case 'verificationRequired':
        return AffiliateEnrolmentStatus.verificationRequired;
      case 'connected':
        return AffiliateEnrolmentStatus.connected;
      default:
        return AffiliateEnrolmentStatus.error;
    }
  }
}

/// The signed-in referrer's affiliate details and referral stats.
///
/// Values come from the device, so use them for display. Grant anything of
/// real value from your server (the `referral.created` webhook or the Public API).
class MyAffiliateDetails {
  final String affiliateName;
  final String affiliateShortCode;
  final String deeplinkUrl;

  /// What counts as a referral for this app: `install`, `event` or `purchase`.
  final String referralTrigger;

  /// The count for [referralTrigger]. Only goes up.
  final int referralCount;
  final int installCount;
  final int eventCount;
  final int purchaseCount;
  final double totalEarned;
  final double totalPaid;
  final double totalUnpaid;
  final String currency;
  final String dashboardUrl;

  const MyAffiliateDetails({
    required this.affiliateName,
    required this.affiliateShortCode,
    required this.deeplinkUrl,
    required this.referralTrigger,
    required this.referralCount,
    required this.installCount,
    required this.eventCount,
    required this.purchaseCount,
    required this.totalEarned,
    required this.totalPaid,
    required this.totalUnpaid,
    required this.currency,
    required this.dashboardUrl,
  });

  factory MyAffiliateDetails.fromJson(Map<String, dynamic> json) {
    return MyAffiliateDetails(
      affiliateName: _string(json['affiliateName']),
      affiliateShortCode: _string(json['affiliateShortCode']),
      deeplinkUrl: _string(json['deeplinkurl']),
      referralTrigger: _string(json['referralTrigger']),
      referralCount: _int(json['referralCount']),
      installCount: _int(json['installCount']),
      eventCount: _int(json['eventCount']),
      purchaseCount: _int(json['purchaseCount']),
      totalEarned: _double(json['totalEarned']),
      totalPaid: _double(json['totalPaid']),
      totalUnpaid: _double(json['totalUnpaid']),
      currency: _string(json['currency'], fallback: 'USD'),
      dashboardUrl: _string(json['dashboardUrl']),
    );
  }
}

/// The app's in-app referral program settings from the Insert Affiliate portal.
/// Text fields are empty when the company has not set them.
class ReferralProgramConfig {
  final bool enabled;
  final String companyName;
  final String referralTrigger;
  final String headline;
  final String rewardText;

  /// Hex colour such as `#6A0DAD`, or empty.
  final String primaryColor;

  const ReferralProgramConfig({
    required this.enabled,
    required this.companyName,
    required this.referralTrigger,
    required this.headline,
    required this.rewardText,
    required this.primaryColor,
  });

  factory ReferralProgramConfig.fromJson(Map<String, dynamic> json) {
    return ReferralProgramConfig(
      enabled: json['enabled'] == true,
      companyName: _string(json['companyName']),
      referralTrigger: _string(json['referralTrigger']),
      headline: _string(json['headline']),
      rewardText: _string(json['rewardText']),
      primaryColor: _string(json['primaryColor']),
    );
  }
}

/// Builds the text shared by `shareReferralLink` and the drop-in screen.
///
/// With a link (`deeplinkUrl` starting with `http`) the default is
/// `"Try {companyName}: <link>"`. Short Code Only apps have no link, so the
/// default is `"Use my code <code> in {companyName}"`. A custom [message] may
/// use `{link}` and `{code}`; without either, the link (or code) is appended.
String buildReferralShareText({
  required String deeplinkUrl,
  required String shortCode,
  required String companyName,
  String? message,
}) {
  final hasLink = deeplinkUrl.startsWith('http');
  final link = hasLink ? deeplinkUrl : shortCode;
  final custom = message?.trim() ?? '';

  if (custom.isNotEmpty) {
    if (custom.contains('{link}') || custom.contains('{code}')) {
      return custom.replaceAll('{link}', link).replaceAll('{code}', shortCode);
    }
    return '$custom $link';
  }

  final name = companyName.trim();
  if (hasLink) {
    return name.isEmpty ? 'Try this app: $deeplinkUrl' : 'Try $name: $deeplinkUrl';
  }
  return name.isEmpty ? 'Use my code $shortCode' : 'Use my code $shortCode in $name';
}

/// HTTP + token storage for in-app referrals. Used through
/// `InsertAffiliateFlutterSDK`; kept separate so it can be tested on its own.
class InsertAffiliateReferrals {
  static const String defaultBaseUrl = 'https://api.insertaffiliate.com';
  static const String _tokenKeyPrefix = 'insert_affiliate_referrer_token_';
  static const String _tokenHeader = 'X-Insert-Affiliate-Token';
  static const String _platform = 'flutter';
  static const Duration _timeout = Duration(seconds: 20);

  final String companyCode;
  final String baseUrl;
  final http.Client? _client;
  final void Function(String message) _verboseLog;

  InsertAffiliateReferrals({
    required this.companyCode,
    this.baseUrl = defaultBaseUrl,
    http.Client? client,
    void Function(String message)? verboseLog,
  })  : _client = client,
        _verboseLog = verboseLog ?? ((_) {});

  String get _tokenKey => '$_tokenKeyPrefix$companyCode';

  Uri _uri(String path) => Uri.parse('$baseUrl/V1/sdk/affiliate$path');

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    final uri = _uri(path);
    final headers = {'Content-Type': 'application/json'};
    final encoded = jsonEncode(body);
    final request = _client != null
        ? _client.post(uri, headers: headers, body: encoded)
        : http.post(uri, headers: headers, body: encoded);
    return request.timeout(_timeout);
  }

  Future<http.Response> _get(String path, {Map<String, String>? headers}) {
    final uri = _uri(path);
    final request = _client != null ? _client.get(uri, headers: headers) : http.get(uri, headers: headers);
    return request.timeout(_timeout);
  }

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<void> _storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> hasToken() async => (await _readToken()) != null;

  Future<AffiliateEnrolmentResult> enrol(String email, String name) {
    return _enrolOrVerify('/enrol', {
      'companyId': companyCode,
      'email': email.trim(),
      'name': name.trim(),
      'platform': _platform,
    });
  }

  Future<AffiliateEnrolmentResult> verify(String email, String code, {String? name}) {
    return _enrolOrVerify('/verify', {
      'companyId': companyCode,
      'email': email.trim(),
      'code': code.trim(),
      'name': (name ?? '').trim(),
      'platform': _platform,
    });
  }

  Future<AffiliateEnrolmentResult> _enrolOrVerify(String path, Map<String, dynamic> body) async {
    if (companyCode.isEmpty) {
      return const AffiliateEnrolmentResult.error(
        'INVALID_COMPANY_ID',
        'Company code is not set. Please initialize the SDK with a valid company code.',
      );
    }
    try {
      _verboseLog('Referrals: POST $path');
      final response = await _post(path, body);
      _verboseLog('Referrals: $path response status: ${response.statusCode}');
      final json = _decodeObject(response.body);

      if (response.statusCode != 200) {
        return AffiliateEnrolmentResult.error(
          _string(json?['code'], fallback: 'HTTP_${response.statusCode}'),
          _string(json?['error'], fallback: 'Request failed with status ${response.statusCode}.'),
        );
      }
      if (json == null) {
        return const AffiliateEnrolmentResult.error('INVALID_RESPONSE', 'Unexpected response from server.');
      }

      final result = AffiliateEnrolmentResult.fromJson(json);
      if (result.isConnected) {
        final token = json['token'];
        if (token is! String || token.isEmpty) {
          return const AffiliateEnrolmentResult.error('INVALID_RESPONSE', 'Unexpected response from server.');
        }
        await _storeToken(token);
        _verboseLog('Referrals: device connected as referrer');
      }
      return result;
    } catch (error) {
      _verboseLog('Referrals: $path network error: $error');
      return const AffiliateEnrolmentResult.error('NETWORK_ERROR', 'Could not reach the server. Please try again.');
    }
  }

  /// Returns null when not enrolled, when the token is no longer valid (it is
  /// then cleared), or on a network error (the token is kept).
  Future<MyAffiliateDetails?> me() async {
    final token = await _readToken();
    if (token == null) {
      _verboseLog('Referrals: no referrer token stored');
      return null;
    }
    try {
      final response = await _get('/me', headers: {_tokenHeader: token});
      _verboseLog('Referrals: /me response status: ${response.statusCode}');
      if (response.statusCode == 401 || response.statusCode == 404) {
        await clearToken();
        _verboseLog('Referrals: referrer token rejected, cleared');
        return null;
      }
      if (response.statusCode != 200) return null;
      final json = _decodeObject(response.body);
      return json == null ? null : MyAffiliateDetails.fromJson(json);
    } catch (error) {
      _verboseLog('Referrals: /me network error: $error');
      return null;
    }
  }

  Future<ReferralProgramConfig?> config() async {
    if (companyCode.isEmpty) return null;
    try {
      final response = await _get('/config/${Uri.encodeComponent(companyCode)}');
      _verboseLog('Referrals: /config response status: ${response.statusCode}');
      if (response.statusCode != 200) return null;
      final json = _decodeObject(response.body);
      return json == null ? null : ReferralProgramConfig.fromJson(json);
    } catch (error) {
      _verboseLog('Referrals: /config network error: $error');
      return null;
    }
  }
}

Map<String, dynamic>? _decodeObject(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String && value.isNotEmpty ? value : fallback;

int _int(Object? value) => value is num ? value.toInt() : 0;

double _double(Object? value) => value is num ? value.toDouble() : 0;
