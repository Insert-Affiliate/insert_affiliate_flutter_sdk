import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:math';
import 'dart:io'; // For platform detection
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef InsertAffiliateIdentifierChangeCallback = void Function(String? identifier, String? offerCode);

/// Source types for affiliate association tracking
enum AffiliateAssociationSource {
  deepLinkIos,       // iOS custom URL scheme (ia-companycode://shortcode)
  deepLinkAndroid,   // Android deep link with ?insertAffiliate= param
  installReferrer,   // Android Play Store install referrer
  clipboardMatch,    // iOS clipboard UUID match from backend
  shortCodeManual,   // Developer called setShortCode()
  referringLink,     // Developer called setInsertAffiliateIdentifier()
}

/// Affiliate details returned from the API
class AffiliateDetails {
  final String affiliateName;
  final String affiliateShortCode;
  final String deeplinkUrl;

  AffiliateDetails({
    required this.affiliateName,
    required this.affiliateShortCode,
    required this.deeplinkUrl,
  });
}

class InsertAffiliateFlutterSDK extends ChangeNotifier {
  final String companyCode;
  bool _verboseLogging = false;

  bool _insertLinksEnabled = false;
  bool _insertLinksClipboardEnabled = false;
  int _attributionTimeout = 0;
  bool _preventAffiliateTransfer = false;
  InsertAffiliateIdentifierChangeCallback? _insertAffiliateIdentifierChangeCallback;
  
  static const String _referrerLinkKey = 'referring_link';

  InsertAffiliateFlutterSDK({
    required this.companyCode,
    bool verboseLogging = false,
    bool insertLinksEnabled = false,
    bool insertLinksClipboardEnabled = false,
    int attributionTimeout = 0,
    bool preventAffiliateTransfer = false,
  }) : _verboseLogging = verboseLogging,
       _insertLinksEnabled = insertLinksEnabled,
       _insertLinksClipboardEnabled = insertLinksClipboardEnabled,
       _attributionTimeout = attributionTimeout,
       _preventAffiliateTransfer = preventAffiliateTransfer {
    _init();
  }

  void _init() async {
    if (_verboseLogging) {
      print('[Insert Affiliate] [VERBOSE] Starting SDK initialization...');
      print('[Insert Affiliate] [VERBOSE] Company code provided: ${companyCode.isNotEmpty ? 'Yes' : 'No'}');
      print('[Insert Affiliate] [VERBOSE] Verbose logging enabled');
      print('[Insert Affiliate] [VERBOSE] Insert links enabled: $_insertLinksEnabled');
      print('[Insert Affiliate] [VERBOSE] Clipboard enabled: $_insertLinksClipboardEnabled');
      print('[Insert Affiliate] [VERBOSE] Attribution timeout: $_attributionTimeout');
      print('[Insert Affiliate] [VERBOSE] Prevent affiliate transfer: $_preventAffiliateTransfer');
    }
    
    // Set the attribution timeout in SharedPreferences if provided
    if (_attributionTimeout > 0) {
      await setAffiliateAttributionTimeout(_attributionTimeout);
    }
    
    await _storeAndReturnShortUniqueDeviceId();
    
    // Initialize deep link functionality if enabled
    if (_insertLinksEnabled) {
      // Capture Android install referrer if on Android
      if (Platform.isAndroid) {
        captureInstallReferrer();
      }
      
      if (Platform.isIOS) {
        try {
          final enhancedSystemInfo = await getEnhancedSystemInfo();
          await sendSystemInfoToBackend(enhancedSystemInfo);
        } catch (error) {
          verboseLog('Error sending system info for clipboard check: $error');
        }
      }
    }
    
    // Report SDK initialization for onboarding verification (fire and forget)
    _reportSdkInitIfNeeded();

    if (_verboseLogging) {
      print('[Insert Affiliate] [VERBOSE] SDK initialization completed');
    }
  }

  /// Reports SDK initialization to the backend for onboarding verification.
  /// Only reports once per install to minimize server load.
  Future<void> _reportSdkInitIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Only report once per install
      final alreadyReported = prefs.getBool('sdk_init_reported') ?? false;
      if (alreadyReported) {
        return;
      }

      if (_verboseLogging) {
        print('[Insert Affiliate] Reporting SDK initialization for onboarding verification...');
      }

      final response = await http.post(
        Uri.parse('https://api.insertaffiliate.com/V1/onboarding/sdk-init'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'companyId': companyCode}),
      );

      if (response.statusCode == 200) {
        await prefs.setBool('sdk_init_reported', true);
        if (_verboseLogging) {
          print('[Insert Affiliate] SDK initialization reported successfully');
        }
      } else if (_verboseLogging) {
        print('[Insert Affiliate] SDK initialization report failed with status: ${response.statusCode}');
      }
    } catch (error) {
      // Silently fail - this is non-critical telemetry
      if (_verboseLogging) {
        print('[Insert Affiliate] SDK initialization report error: $error');
      }
    }
  }

  /// Reports a new affiliate association to the backend for tracking.
  /// Only reports each unique affiliateIdentifier once to prevent duplicates.
  Future<void> _reportAffiliateAssociationIfNeeded(
    String affiliateIdentifier,
    AffiliateAssociationSource source,
  ) async {
    try {
      if (companyCode.isEmpty) {
        verboseLog('Cannot report affiliate association: no company code available');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Get the set of already-reported affiliate identifiers
      final reportedAssociationsJson = prefs.getString('reported_affiliate_associations');
      final List<String> reportedAssociations = reportedAssociationsJson != null
          ? List<String>.from(jsonDecode(reportedAssociationsJson))
          : [];

      // Check if this affiliate identifier has already been reported
      if (reportedAssociations.contains(affiliateIdentifier)) {
        verboseLog('Affiliate association already reported for: $affiliateIdentifier, skipping');
        return;
      }

      // Map enum to string for API
      final sourceString = _sourceToString(source);
      verboseLog('Reporting new affiliate association: $affiliateIdentifier (source: $sourceString)');

      final response = await http.post(
        Uri.parse('https://api.insertaffiliate.com/V1/onboarding/affiliate-associated'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'companyId': companyCode,
          'affiliateIdentifier': affiliateIdentifier,
          'source': sourceString,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        // Add to reported set and persist
        reportedAssociations.add(affiliateIdentifier);
        await prefs.setString('reported_affiliate_associations', jsonEncode(reportedAssociations));
        verboseLog('Affiliate association reported successfully for: $affiliateIdentifier');
      } else {
        verboseLog('Affiliate association report failed with status: ${response.statusCode}');
      }
    } catch (error) {
      // Silently fail - this is non-critical telemetry
      verboseLog('Affiliate association report error: $error');
    }
  }

  String _sourceToString(AffiliateAssociationSource source) {
    switch (source) {
      case AffiliateAssociationSource.deepLinkIos:
        return 'deep_link_ios';
      case AffiliateAssociationSource.deepLinkAndroid:
        return 'deep_link_android';
      case AffiliateAssociationSource.installReferrer:
        return 'install_referrer';
      case AffiliateAssociationSource.clipboardMatch:
        return 'clipboard_match';
      case AffiliateAssociationSource.shortCodeManual:
        return 'short_code_manual';
      case AffiliateAssociationSource.referringLink:
        return 'referring_link';
    }
  }

  // MARK: Company Code
  String getCompanyCode() {
    return companyCode;
  }

  // MARK: Short Codes
  bool isShortCode(String link) {
    return RegExp(r'^[a-zA-Z0-9]{3,25}$').hasMatch(link);
  }

  /// Validates and sets a short code for affiliate tracking
  /// Returns true if the short code exists and was successfully validated and stored, false otherwise
  Future<bool> setShortCode(String shortCode) async {
    if (shortCode.isEmpty) {
      errorLog("Short code cannot be empty", "warn");
      return false;
    }

    shortCode = shortCode.toUpperCase();

    if (shortCode.length < 3 || shortCode.length > 25 || !RegExp(r'^[a-zA-Z0-9]{3,25}$').hasMatch(shortCode)) {
      errorLog("Short code must be between 3-25 characters and contain only letters and numbers", "warn");
      return false;
    }

    // Validate that the short code exists in the system
    final affiliateDetails = await getAffiliateDetails(shortCode);
    if (affiliateDetails == null) {
      print('[Insert Affiliate] Error: Short code \'$shortCode\' does not exist or validation failed.');
      return false;
    }

    print('[Insert Affiliate] Short code validated successfully for affiliate: ${affiliateDetails.affiliateName}');

    // If validation passes, set the Insert Affiliate Identifier
    await storeInsertAffiliateIdentifier(link: shortCode, source: AffiliateAssociationSource.shortCodeManual);

    notifyListeners();
    return true;
  }

  /// Retrieves detailed information about an affiliate by their short code or deep link
  /// This method queries the API and does not store or set the affiliate identifier
  /// Returns AffiliateDetails if found, null otherwise
  Future<AffiliateDetails?> getAffiliateDetails(String affiliateCode) async {
    if (companyCode.isEmpty) {
      print('[Insert Affiliate] Company code is not set. Please initialize the SDK with a valid company code.');
      return null;
    }

    // Strip UUID from code if present (e.g., "ABC123-uuid" becomes "ABC123")
    final cleanCode = affiliateCode.split('-').first;

    const urlString = 'https://api.insertaffiliate.com/V1/checkAffiliateExists';

    try {
      final payload = {
        'companyId': companyCode,
        'affiliateCode': cleanCode,
      };

      verboseLog('Checking if affiliate exists: $cleanCode');

      final response = await http.post(
        Uri.parse(urlString),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      verboseLog('API response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        if (response.body.isNotEmpty) {
          verboseLog('API Error (${response.statusCode}): ${response.body}');
        }
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final exists = json['exists'] as bool?;

      if (exists != true) {
        verboseLog('Affiliate does not exist');
        return null;
      }

      final affiliate = json['affiliate'] as Map<String, dynamic>?;
      if (affiliate == null) {
        verboseLog('Failed to parse affiliate details from response');
        return null;
      }

      final affiliateName = affiliate['affiliateName'] as String?;
      final affiliateShortCode = affiliate['affiliateShortCode'] as String?;
      final deeplinkUrl = affiliate['deeplinkurl'] as String?;

      if (affiliateName == null || affiliateShortCode == null || deeplinkUrl == null) {
        verboseLog('Missing required fields in affiliate response');
        return null;
      }

      verboseLog('Successfully retrieved affiliate details for: $affiliateName');

      return AffiliateDetails(
        affiliateName: affiliateName,
        affiliateShortCode: affiliateShortCode,
        deeplinkUrl: deeplinkUrl,
      );
    } catch (error) {
      errorLog('Error fetching affiliate details: $error', 'error');
      verboseLog('Error fetching affiliate details: $error');
      return null;
    }
  }

  // MARK: Device UUID
  String _generateUserId() {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(6, (index) => characters[random.nextInt(characters.length)]).join();
  }

  Future<String> _storeAndReturnShortUniqueDeviceId() async {
    verboseLog('Getting or generating user ID...');
    final prefs = await SharedPreferences.getInstance();
    final existingUserId = prefs.getString('shortUniqueDeviceID');
    if (existingUserId != null) {
      verboseLog('Found existing user ID: $existingUserId');
      return existingUserId;
    }
    verboseLog('No existing user ID found, generating new one...');
    final userId = _generateUserId();
    await prefs.setString('shortUniqueDeviceID', userId);
    verboseLog('Generated and saved new user ID: $userId');
    return userId;
  }

  // MARK: Setting Insert Affiliate Link
  Future<void> setInsertAffiliateIdentifier(String referringLink) async {
    print('[Insert Affiliate] Setting affiliate identifier.');
    verboseLog('Input referringLink: $referringLink');

    if (companyCode.isEmpty) {
      errorLog("Company code cannot be empty", "warn");
      verboseLog('Company code missing, cannot proceed with API call');
      return;
    }

    verboseLog('Checking if referring link is already a short code...');
    if (isShortCode(referringLink)) {
      print('[Insert Affiliate] Referring link is already a short code.');
      verboseLog('Link is already a short code, storing directly');
      await storeInsertAffiliateIdentifier(link: referringLink, source: AffiliateAssociationSource.referringLink);
      return;
    }

    verboseLog('Link is not a short code, will convert via API');
    verboseLog('Encoding referring link for API call...');
    final encodedAffiliateLink = Uri.encodeComponent(referringLink);
    final urlString = "http://api.insertaffiliate.com/V1/convert-deep-link-to-short-link?companyId=$companyCode&deepLinkUrl=$encodedAffiliateLink";
    
    verboseLog('Making API request to convert deep link to short code...');

    try {
      final response = await http.get(
        Uri.parse(urlString),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      verboseLog('API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final shortLink = jsonResponse['shortLink'];

        if (shortLink != null && shortLink.isNotEmpty) {
          print('[Insert Affiliate] Short link received: $shortLink');
          verboseLog('Successfully converted to short link: $shortLink');
          verboseLog('Storing short link...');
          await storeInsertAffiliateIdentifier(link: shortLink, source: AffiliateAssociationSource.referringLink);
          verboseLog('Short link stored successfully');
          return;
        } else { // If theres an issue, store what was passed to save for later potential processing/recovery
          verboseLog('Unexpected API response, storing original link as fallback');
          await storeInsertAffiliateIdentifier(link: referringLink, source: AffiliateAssociationSource.referringLink);
        }
      }
    } catch (error) {
      errorLog("Error setting insert affiliate identifier: $error", "error");
      verboseLog('Error in setInsertAffiliateIdentifier: $error');
    }

    verboseLog('Storing original link as fallback');
    await storeInsertAffiliateIdentifier(link: referringLink, source: AffiliateAssociationSource.referringLink);
  }

  Future<String?> returnInsertAffiliateIdentifier({bool ignoreTimeout = false}) async {
    verboseLog('Getting insert affiliate identifier...');
    final prefs = await SharedPreferences.getInstance();
    final referringLink = prefs.getString('referring_link');
    final shortUniqueDeviceID = prefs.getString('shortUniqueDeviceID');
    
    verboseLog('SharedPreferences - referringLink: ${referringLink ?? 'empty'}, shortUniqueDeviceID: ${shortUniqueDeviceID ?? 'empty'}');
    
    if (referringLink == null || shortUniqueDeviceID == null) {
      verboseLog('No affiliate identifier found in storage');
      return null;
    }
    
    // Check attribution validity unless ignoreTimeout is true
    if (!ignoreTimeout && !await isAffiliateAttributionValid()) {
      verboseLog('Affiliate attribution has expired');
      return null;
    }
    
    final identifier = "$referringLink-$shortUniqueDeviceID";
    verboseLog('Found identifier: $identifier');
    return identifier;
  }

  /// Checks if the affiliate attribution is still valid based on the timeout period.
  /// Returns true if attribution is valid or no timeout is set, false if expired.
  Future<bool> isAffiliateAttributionValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get the stored attribution date
      final storedDateString = prefs.getString('affiliate_attribution_date');
      if (storedDateString == null) {
        verboseLog('No attribution date found, considering valid for backward compatibility');
        return true; // For backward compatibility, consider valid if no date is stored
      }
      
      // Get the timeout period (default to 0 = disabled if not set)
      final timeoutSeconds = prefs.getInt('affiliate_attribution_timeout_seconds') ?? 0;
      if (timeoutSeconds <= 0) {
        verboseLog('Attribution timeout disabled (timeout seconds <= 0)');
        return true; // If timeout is disabled, always valid
      }
      
      final storedDate = DateTime.parse(storedDateString);
      final now = DateTime.now();
      final secondsSinceAttribution = now.difference(storedDate).inSeconds;
      
      final isValid = secondsSinceAttribution <= timeoutSeconds;
      verboseLog('Attribution check: stored=${storedDate.toIso8601String()}, '
                'timeout=${timeoutSeconds}s, secondsSince=${secondsSinceAttribution}s, valid=$isValid');
      
      return isValid;
    } catch (error) {
      verboseLog('Error checking attribution validity: $error');
      return true; // Default to valid on error for backward compatibility
    }
  }

  /// Returns the date when the affiliate attribution was stored.
  /// Returns null if no attribution date is found.
  Future<DateTime?> getAffiliateStoredDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDateString = prefs.getString('affiliate_attribution_date');
      
      if (storedDateString != null) {
        final storedDate = DateTime.parse(storedDateString);
        verboseLog('Retrieved affiliate stored date: ${storedDate.toIso8601String()}');
        return storedDate;
      } else {
        verboseLog('No affiliate stored date found');
        return null;
      }
    } catch (error) {
      verboseLog('Error retrieving affiliate stored date: $error');
      return null;
    }
  }

  /// Sets the timeout period in seconds for affiliate attribution.
  /// Set to 0 or negative value to disable timeout (attribution never expires).
  Future<void> setAffiliateAttributionTimeout(int timeoutSeconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('affiliate_attribution_timeout_seconds', timeoutSeconds);
      verboseLog('Attribution timeout set to $timeoutSeconds seconds');
    } catch (error) {
      verboseLog('Error setting attribution timeout: $error');
    }
  }

  /// Gets the current timeout period in seconds for affiliate attribution.
  /// Returns the default of 0 (disabled) if not explicitly set.
  Future<int> getAffiliateAttributionTimeout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeoutSeconds = prefs.getInt('affiliate_attribution_timeout_seconds') ?? 0;
      verboseLog('Current attribution timeout: $timeoutSeconds seconds');
      return timeoutSeconds;
    } catch (error) {
      verboseLog('Error getting attribution timeout: $error');
      return 0; // Default fallback (disabled)
    }
  }

  /// Returns the Unix timestamp (in milliseconds) when the current affiliate attribution expires.
  /// Returns null if no attribution date is stored or if timeout is disabled (0).
  Future<int?> getAffiliateExpiryTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get the stored attribution date
      final storedDateString = prefs.getString('affiliate_attribution_date');
      if (storedDateString == null) {
        verboseLog('No attribution date found, cannot calculate expiry timestamp');
        return null;
      }

      // Get the timeout period (default to 0 = disabled if not set)
      final timeoutSeconds = prefs.getInt('affiliate_attribution_timeout_seconds') ?? 0;
      if (timeoutSeconds <= 0) {
        verboseLog('Attribution timeout disabled, no expiry timestamp');
        return null;
      }

      final storedDate = DateTime.parse(storedDateString);
      final expiryTimestamp = storedDate.millisecondsSinceEpoch + (timeoutSeconds * 1000);

      verboseLog('Affiliate expiry timestamp: $expiryTimestamp (stored: ${storedDate.toIso8601String()}, timeout: ${timeoutSeconds}s)');
      return expiryTimestamp;
    } catch (error) {
      verboseLog('Error getting affiliate expiry timestamp: $error');
      return null;
    }
  }

  Future<void> storeExpectedStoreTransaction(String purchaseToken) async {
    try {
      verboseLog('Storing expected store transaction with token: $purchaseToken');
      
      // 1. Ensure companyCode exists
      if (companyCode.isEmpty) {
        errorLog("[Insert Affiliate] Company code is not set. Please initialize the SDK with a valid company code.", "error");
        verboseLog('Cannot store transaction: no company code available');
        return;
      }

      // 2. Retrieve shortCode (affiliate ID)
      final shortCode = await returnInsertAffiliateIdentifier();
      if (shortCode == null) {
        errorLog("[Insert Affiliate] No affiliate identifier found. Please set one before tracking events.", "error");
        verboseLog('Cannot store transaction: no affiliate identifier available');
        return;
      }

      verboseLog('Company code: $companyCode, Short code: $shortCode');

      // 3. Build the JSON payload
      final payload = {
        'UUID': purchaseToken,
        'companyCode': companyCode,
        'shortCode': shortCode,
        'storedDate': DateTime.now().toIso8601String(),
      };

      print("[Insert Affiliate] Storing expected transaction: $payload");
      verboseLog('Making API call to store expected transaction...');

      // 4. Send the request to the Insert Affiliate API
      final response = await http.post(
        Uri.parse("https://api.insertaffiliate.com/v1/api/app-store-webhook/create-expected-transaction"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      verboseLog('API response status: ${response.statusCode}');

      // 5. Handle response
      if (response.statusCode == 200) {
        print("[Insert Affiliate] Expected transaction stored successfully.");
        verboseLog('Expected transaction stored successfully on server');
      } else {
        print("[Insert Affiliate] Failed to store expected transaction. "
          "Status code: ${response.statusCode}, Response: ${response.body}");
        verboseLog('API error response: ${response.body}');
      }
    } catch (error) {
      errorLog("[Insert Affiliate] Error storing expected transaction: $error", "error");
      verboseLog('Network error storing transaction: $error');
    }
  }

  Future<String?> returnUserAccountTokenAndStoreExpectedTransaction() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Step 1: Get or create user account token
      String? userAccountToken = prefs.getString('user_account_token');
      if (userAccountToken == null) {
        userAccountToken = _generateUUID();
        await prefs.setString('user_account_token', userAccountToken);
      }

      // Step 2: Get insert affiliate identifier (referrer + user ID)
      final shortCode = await returnInsertAffiliateIdentifier();
      if (shortCode == null) {
        errorLog("[Insert Affiliate] No affiliate stored - not saving expected transaction.");
        return null;
      }

      // Step 3: Build payload
      final payload = {
        'UUID': userAccountToken,
        'companyCode': companyCode,
        'shortCode': shortCode,
        'storedDate': DateTime.now().toIso8601String(),
      };

      // Step 4: Send to API
      final response = await http.post(
        Uri.parse("https://api.insertaffiliate.com/v1/api/app-store-webhook/create-expected-transaction"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print("[Insert Affiliate] Expected transaction stored successfully.");
        return userAccountToken;
      } else {
        print("[Insert Affiliate] Failed to store expected transaction. Status code: ${response.statusCode}, Body: ${response.body}");
        return null;
      }
    } catch (error) {
      errorLog("[Insert Affiliate] Error storing expected transaction: $error", "error");
      return null;
    }
  }

  String _generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (Match match) {
        final r = Random().nextInt(16);
        final v = match[0] == 'x' ? r : (r & 0x3) | 0x8;
        return v.toRadixString(16);
      },
    );
  }

  // MARK: Event Tracking
  Future<void> trackEvent({required String eventName}) async {
    try {
      verboseLog('Tracking event: $eventName');
      
      if (companyCode.isEmpty) {
        errorLog("[Insert Affiliate] Company code is not set. Please initialize the SDK with a valid company code.", "error");
        verboseLog('Cannot track event: no company code available');
        return;
      }

      print('track event called with - companyCode: $companyCode');

      final affiliateLink = await returnInsertAffiliateIdentifier();

      if (affiliateLink == null) {
        errorLog(
          "[Insert Affiliate] No affiliate link found. Please save one before tracking events.",
          "warn",
        );
        verboseLog('Cannot track event: no affiliate identifier available');
        return;
      }

      verboseLog('Deep link param: $affiliateLink');

      final payload = {
        "eventName": eventName,
        "deepLinkParam": affiliateLink,
        "companyId": companyCode,
      };

      verboseLog('Track event payload: ${jsonEncode(payload)}');
      verboseLog('Making API call to track event...');

      final response = await http.post(
        Uri.parse('https://api.insertaffiliate.com/v1/trackEvent'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      verboseLog('Track event API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[Insert Affiliate] Event tracked successfully');
        verboseLog('Event tracked successfully on server');
      } else {
        errorLog(
          "[Insert Affiliate] Failed to track event. Status code: ${response.statusCode}, Response: ${response.body}",
          "error",
        );
        verboseLog('Track event API error: status ${response.statusCode}, response: ${response.body}');
      }
    } catch (error) {
      errorLog("[Insert Affiliate] Error tracking event: $error", "error");
      verboseLog('Network error tracking event: $error');
    }
  }

  // MARK: Offer Codes
  Future<String?> fetchOfferCode(String affiliateLink) async {
    try {
      if (companyCode.isEmpty) {
        verboseLog('Cannot fetch offer code: no company code available');
        return null;
      }

      String platformType = 'ios';
      // Check if its iOS or Android here
      if (!Platform.isIOS) {
        verboseLog('Platform is not iOS, setting platform type to android');
        platformType = 'android';
      } else {
        verboseLog('Platform is iOS, setting platform type to ios');
      }

      final encodedAffiliateLink = Uri.encodeComponent(affiliateLink);
      final url = "https://api.insertaffiliate.com/v1/affiliateReturnOfferCode/$companyCode/$encodedAffiliateLink?platformType=$platformType";
      
      verboseLog('Starting to fetch offer code from: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final offerCode = response.body;
        
        // Check for specific error strings from API
        if (offerCode.contains("errorofferCodeNotFound") ||
            offerCode.contains("errorAffiliateoffercodenotfoundinanycompany") ||
            offerCode.contains("errorAffiliateoffercodenotfoundinanycompanyAffiliatelinkwas") ||
            offerCode.contains("Routenotfound")) {
          print("[Insert Affiliate] Offer code not found or invalid: $offerCode");
          verboseLog("Offer code not found or invalid: $offerCode");
          return null;
        }
        
        final cleanedOfferCode = _cleanOfferCode(offerCode);
        verboseLog('Successfully fetched and cleaned offer code: $cleanedOfferCode');
        return cleanedOfferCode;
      } else {
        errorLog("Failed to fetch offer code. Status code: ${response.statusCode}, Response: ${response.body}", "error");
        verboseLog('Failed to fetch offer code. Status code: ${response.statusCode}, Response: ${response.body}');
        return null;
      }
    } catch (error) {
      errorLog("Error fetching offer code: $error", "error");
      verboseLog('Error fetching offer code: $error');
      return null;
    }
  }

  Future<String?> retrieveAndStoreOfferCode(String affiliateLink) async {
    try {
      verboseLog('Attempting to retrieve and store offer code for: $affiliateLink');

      final offerCode = await fetchOfferCode(affiliateLink);

      if (offerCode != null && offerCode.isNotEmpty) {
        // Store in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offer_code', offerCode);

        // Notify listeners of the change
        notifyListeners();

        verboseLog('Successfully stored offer code: $offerCode');
        print('[Insert Affiliate] Offer code retrieved and stored successfully');
        return offerCode;
      } else {
        verboseLog('No valid offer code found to store');
        // Clear stored offer code if none found
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offer_code', '');

        // Notify listeners of the change
        notifyListeners();
        return null;
      }
    } catch (error) {
      errorLog("Error retrieving and storing offer code: $error", "error");
      verboseLog('Error in retrieveAndStoreOfferCode: $error');
      return null;
    }
  }

  Future<String?> getStoredOfferCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offerCode = prefs.getString('offer_code');
      return (offerCode != null && offerCode.isNotEmpty) ? offerCode : null;
    } catch (error) {
      errorLog("Error getting stored offer code: $error", "error");
      return null;
    }
  }

  String _cleanOfferCode(String offerCode) {
    // Remove special characters, keep only alphanumeric, underscores, and dashes
    return offerCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  }

  // MARK: Callback Management
  void setInsertAffiliateIdentifierChangeCallback(InsertAffiliateIdentifierChangeCallback? callback) {
    _insertAffiliateIdentifierChangeCallback = callback;
  }


  // MARK: Platform Routing
  Future<bool> handleDeepLink(String url) async {
    verboseLog('Platform detection: Platform.OS = ${Platform.operatingSystem}');
    if (Platform.isIOS) {
      verboseLog('Routing to iOS handler (handleInsertLinks)');
      return await handleInsertLinks(url);
    } else if (Platform.isAndroid) {
      verboseLog('Routing to Android handler (handleInsertLinkAndroid)');
      return await handleInsertLinkAndroid(url);
    }
    verboseLog('Unrecognized platform: ${Platform.operatingSystem}');
    return false;
  }

  // MARK: Public API for handling Insert Links
  Future<bool> handleInsertLinks(String url) async {
    if (url.isEmpty) {
      verboseLog('Invalid URL provided to handleInsertLinks');
      return false;
    }

    if (!_insertLinksEnabled) {
      verboseLog('Deep links are disabled, not handling URL');
      return false;
    }

    final urlObj = parseURL(url);

    // Handle custom URL schemes (ia-companycode://shortcode)
    if (urlObj['protocol']?.startsWith('ia-') == true) {
      return await handleCustomURLScheme(url, urlObj['protocol']!);
    }

    // Universal links handling would go here for future implementation
    return false;
  }

  // MARK: URL Parsing Utility
  Map<String, String> parseURL(String url) {
    try {
      final uri = Uri.parse(url);
      return {
        'protocol': '${uri.scheme}:',
        'hostname': uri.host,
        'href': url,
      };
    } catch (error) {
      return {
        'protocol': '',
        'hostname': '',
        'href': url,
      };
    }
  }

  // MARK: Android Deep Link Handler
  Future<bool> handleInsertLinkAndroid(String url) async {
    if (!_insertLinksEnabled) {
      verboseLog('Deep links disabled, not handling Android URL');
      return false;
    }

    verboseLog('Processing Android deep link: $url');

    final uri = Uri.parse(url);
    final insertAffiliate = uri.queryParameters['insertAffiliate'];

    if (insertAffiliate != null && insertAffiliate.isNotEmpty) {
      verboseLog('Found insertAffiliate parameter: $insertAffiliate');
      await storeInsertAffiliateIdentifier(link: insertAffiliate, source: AffiliateAssociationSource.deepLinkAndroid);
      return true;
    } else {
      verboseLog('No insertAffiliate parameter found in Android deep link');
      return false;
    }
  }

  // MARK: iOS Custom URL Scheme Handler
  Future<bool> handleCustomURLScheme(String url, String protocol) async {
    final scheme = protocol.replaceAll(':', '');

    if (!scheme.startsWith('ia-')) {
      return false;
    }

    // Extract company code from scheme (remove "ia-" prefix)
    final companyCode = scheme.substring(3);

    final shortCode = parseShortCodeFromURLString(url);
    if (shortCode == null) {
      print('[Insert Affiliate] Failed to parse short code from deep link: $url');
      return false;
    }

    // Convert short code to uppercase for consistency
    final upperCaseShortCode = shortCode.toUpperCase();
    
    verboseLog('Custom URL scheme detected - Company: $companyCode, Short code: $upperCaseShortCode');

    // Validate company code matches initialized one
    final activeCompanyCode = await getActiveCompanyCode();
    if (activeCompanyCode != null && companyCode.toLowerCase() != activeCompanyCode.toLowerCase()) {
      verboseLog('Warning: URL company code ($companyCode) doesn\'t match initialized company code ($activeCompanyCode)');
    }

    // Store the short code as the referring link
    await storeInsertAffiliateIdentifier(link: upperCaseShortCode, source: AffiliateAssociationSource.deepLinkIos);

    // Collect and send enhanced system info to backend
    try {
      final enhancedSystemInfo = await getEnhancedSystemInfo();
      await sendSystemInfoToBackend(enhancedSystemInfo);
    } catch (error) {
      verboseLog('Error sending system info for deep link: $error');
    }

    return true;
  }

  // MARK: URL Parsing Utilities

  /// Parse shortcode from query parameter (new format: scheme://insert-affiliate?code=SHORTCODE)
  String? parseShortCodeFromQuery(String url) {
    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        verboseLog('Found short code in query parameter: $code');
        return code;
      }
      return null;
    } catch (error) {
      verboseLog('Error parsing short code from query: $error');
      return null;
    }
  }

  String? parseShortCodeFromURLString(String url) {
    try {
      // First try to extract from query parameter (new format: scheme://insert-affiliate?code=SHORTCODE)
      final queryCode = parseShortCodeFromQuery(url);
      if (queryCode != null) {
        print('[Insert Affiliate] Found short code in query parameter: $queryCode');
        return queryCode;
      }

      // Fall back to path format (legacy: scheme://SHORTCODE)
      final match = RegExp(r'^[^:]+://(.+)').firstMatch(url);
      if (match != null) {
        var shortCode = match.group(1)!;
        // Remove leading slash if present
        shortCode = shortCode.startsWith('/') ? shortCode.substring(1) : shortCode;
        // If the path is 'insert-affiliate' (from new format without code param), return null
        if (shortCode.toLowerCase() == 'insert-affiliate' || shortCode.toLowerCase().startsWith('insert-affiliate?')) {
          return null;
        }
        print('[Insert Affiliate] Found short code in URL path (legacy format): $shortCode');
        return shortCode;
      }
      return null;
    } catch (error) {
      verboseLog('Error parsing short code from URL string: $error');
      return null;
    }
  }

  Future<String?> getActiveCompanyCode() async {
    return companyCode.isNotEmpty ? companyCode : null;
  }

  // MARK: Android Install Referrer
  Future<bool> captureInstallReferrer({int retryCount = 0}) async {
    if (!_insertLinksEnabled || !Platform.isAndroid) {
      verboseLog('Install referrer: disabled or not Android platform');
      return false;
    }

    verboseLog('Starting install referrer capture... (attempt ${retryCount + 1})');

    try {
      // Use Android install referrer API with 10 second timeout
      final referrerDetails = await AndroidPlayInstallReferrer.installReferrer.timeout(
        const Duration(seconds: 10)
      );

      if (referrerDetails.installReferrer != null && referrerDetails.installReferrer!.isNotEmpty) {
        verboseLog('Raw install referrer data: ${referrerDetails.installReferrer}');
        final success = await processInstallReferrerData(referrerDetails.installReferrer!);
        verboseLog(success ? 'Install referrer processed successfully' : 'No insertAffiliate parameter found');
        return success;
      }

      verboseLog('No install referrer data found');
      return false;

    } catch (error) {
      final errorMessage = error.toString();
      verboseLog('Error capturing install referrer (attempt ${retryCount + 1}): $errorMessage');

      // Retry logic for specific errors
      const maxRetries = 3;
      final isRetryableError = errorMessage.contains('SERVICE_UNAVAILABLE') ||
                              errorMessage.contains('DEVELOPER_ERROR') ||
                              errorMessage.contains('timed out') ||
                              errorMessage.contains('SERVICE_DISCONNECTED');

      if (isRetryableError && retryCount < maxRetries) {
        final retryDelay = Duration(milliseconds: math.min(1000 * math.pow(2, retryCount).toInt(), 10000));
        verboseLog('Retrying install referrer capture in ${retryDelay.inMilliseconds}ms...');

        Timer(retryDelay, () => captureInstallReferrer(retryCount: retryCount + 1));
        return false;
      } else {
        verboseLog('Install referrer capture failed after ${retryCount + 1} attempts');
        return false;
      }
    }
  }

  Future<bool> processInstallReferrerData(String rawReferrer) async {
    verboseLog('Processing install referrer data...');

    if (rawReferrer.isEmpty) {
      verboseLog('No referrer data provided');
      return false;
    }

    verboseLog('Raw referrer data: $rawReferrer');

    // Parse insertAffiliate parameter
    String? insertAffiliate;
    if (rawReferrer.contains('insertAffiliate=')) {
      final params = rawReferrer.split('&');
      for (final param in params) {
        if (param.startsWith('insertAffiliate=')) {
          insertAffiliate = param.substring('insertAffiliate='.length);
          break;
        }
      }
    }

    verboseLog('Extracted insertAffiliate parameter: $insertAffiliate');

    if (insertAffiliate != null && insertAffiliate.isNotEmpty) {
      verboseLog('Found insertAffiliate parameter, setting as affiliate identifier: $insertAffiliate');
      await storeInsertAffiliateIdentifier(link: insertAffiliate, source: AffiliateAssociationSource.installReferrer);
      return true;
    } else {
      verboseLog('No insertAffiliate parameter found in referrer data');
      return false;
    }
  }

  // MARK: Clipboard Utilities (iOS)
  Future<String?> getClipboardUUID() async {
    if (!_insertLinksClipboardEnabled) {
      return null;
    }

    verboseLog('Getting clipboard UUID');

    try {
      final clipboardData = await Clipboard.getData('text/plain');
      final clipboardString = clipboardData?.text;

      if (clipboardString == null || clipboardString.isEmpty) {
        verboseLog('No clipboard string found or access denied');
        return null;
      }

      final trimmedString = clipboardString.trim();

      if (isValidUUID(trimmedString)) {
        verboseLog('Valid clipboard UUID found: $trimmedString');
        return trimmedString;
      }

      verboseLog('Invalid clipboard UUID found: $trimmedString');
      return null;
    } catch (error) {
      verboseLog('Clipboard access error: $error');
      return null;
    }
  }

  bool isValidUUID(String string) {
    if (string.length != 36) return false;

    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
    return uuidRegex.hasMatch(string);
  }

  // MARK: Enhanced System Info Collection
  Future<Map<String, dynamic>> getEnhancedSystemInfo() async {
    verboseLog('Collecting enhanced system information...');

    final systemInfo = await getSystemInfo();

    try {
      // Add timestamp
      final now = DateTime.now();
      systemInfo['requestTime'] = now.toIso8601String();
      systemInfo['requestTimestamp'] = now.millisecondsSinceEpoch;

      // Add user agent
      final systemName = systemInfo['systemName'];
      final systemVersion = systemInfo['systemVersion'];
      final model = systemInfo['model'];
      systemInfo['userAgent'] = '$model; $systemName $systemVersion';

      // Screen dimensions
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final screenSize = view.physicalSize / view.devicePixelRatio;

      systemInfo['screenWidth'] = screenSize.width.floor();
      systemInfo['screenHeight'] = screenSize.height.floor();
      systemInfo['screenAvailWidth'] = screenSize.width.floor();
      systemInfo['screenAvailHeight'] = screenSize.height.floor();
      systemInfo['devicePixelRatio'] = view.devicePixelRatio;
      systemInfo['screenColorDepth'] = 24;
      systemInfo['screenPixelDepth'] = 24;

      // Hardware concurrency (estimate)
      systemInfo['hardwareConcurrency'] = Platform.numberOfProcessors;
      systemInfo['maxTouchPoints'] = 5;

      // Inner/outer dimensions
      systemInfo['screenInnerWidth'] = screenSize.width.floor();
      systemInfo['screenInnerHeight'] = screenSize.height.floor();
      systemInfo['screenOuterWidth'] = screenSize.width.floor();
      systemInfo['screenOuterHeight'] = screenSize.height.floor();

      // Clipboard UUID if available
      final clipboardUUID = await getClipboardUUID();
      if (clipboardUUID != null) {
        systemInfo['clipboardID'] = clipboardUUID;
        verboseLog('Found valid clipboard UUID: $clipboardUUID');
      } else {
        verboseLog(_insertLinksClipboardEnabled ?
          'Clipboard UUID not available' :
          'Clipboard access is disabled');
      }

      // Language and locale
      final locale = Platform.localeName;
      final parts = locale.split('_');
      systemInfo['language'] = parts.isNotEmpty ? parts[0] : 'en';
      systemInfo['country'] = parts.length > 1 ? parts[1] : null;
      systemInfo['languages'] = [locale, parts.isNotEmpty ? parts[0] : 'en'];

      // Timezone
      final now2 = DateTime.now();
      systemInfo['timezoneOffset'] = now2.timeZoneOffset.inMinutes;
      systemInfo['timezone'] = now2.timeZoneName;

      // Platform info
      systemInfo['browserVersion'] = systemInfo['systemVersion'];
      systemInfo['platform'] = systemInfo['systemName'];
      systemInfo['os'] = systemInfo['systemName'];
      systemInfo['osVersion'] = systemInfo['systemVersion'];
      systemInfo['deviceType'] = 'mobile';

      // Network info
      final networkInfo = await getNetworkInfo();
      final pathInfo = await getNetworkPathInfo();

      systemInfo['networkInfo'] = networkInfo;
      systemInfo['networkPath'] = pathInfo;

      // Connection info
      final connection = <String, dynamic>{};
      connection['type'] = networkInfo['connectionType'] ?? 'unknown';
      connection['isExpensive'] = networkInfo['isExpensive'] ?? false;
      connection['isConstrained'] = networkInfo['isConstrained'] ?? false;
      connection['status'] = networkInfo['status'] ?? 'unknown';
      connection['interfaces'] = networkInfo['availableInterfaces'] ?? [];
      connection['supportsIPv4'] = pathInfo['supportsIPv4'] ?? true;
      connection['supportsIPv6'] = pathInfo['supportsIPv6'] ?? false;
      connection['supportsDNS'] = pathInfo['supportsDNS'] ?? true;

      // Legacy fields
      connection['downlink'] = networkInfo['connectionType'] == 'wifi' ? 100 : 10;
      connection['effectiveType'] = networkInfo['connectionType'] == 'wifi' ? '4g' : '3g';
      connection['rtt'] = networkInfo['connectionType'] == 'wifi' ? 20 : 100;
      connection['saveData'] = networkInfo['isConstrained'] ?? false;

      systemInfo['connection'] = connection;

      verboseLog('Enhanced system info collected: ${jsonEncode(systemInfo)}');
      return systemInfo;
    } catch (error) {
      verboseLog('Error collecting enhanced system info: $error');
      return systemInfo;
    }
  }

  Future<Map<String, dynamic>> getSystemInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    
    Map<String, dynamic> systemInfo = {
      'appName': packageInfo.appName,
      'packageName': packageInfo.packageName,
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
    };

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      systemInfo.addAll({
        'systemName': 'iOS',
        'systemVersion': iosInfo.systemVersion,
        'model': iosInfo.model,
        'localizedModel': iosInfo.localizedModel,
        'name': iosInfo.name,
        'identifierForVendor': iosInfo.identifierForVendor,
        'isPhysicalDevice': iosInfo.isPhysicalDevice,
      });
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      systemInfo.addAll({
        'systemName': 'Android',
        'systemVersion': androidInfo.version.release,
        'model': androidInfo.model,
        'manufacturer': androidInfo.manufacturer,
        'brand': androidInfo.brand,
        'product': androidInfo.product,
        'device': androidInfo.device,
        'androidId': androidInfo.id,
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
      });
    }

    return systemInfo;
  }

  Future<Map<String, dynamic>> getNetworkInfo() async {
    final connectionInfo = <String, dynamic>{
      'connectionType': 'unknown',
      'interfaceTypes': <String>[],
      'isExpensive': false,
      'isConstrained': false,
      'status': 'disconnected',
      'availableInterfaces': <String>[],
    };

    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final connectivityResult = connectivityResults.isNotEmpty ? connectivityResults.first : ConnectivityResult.none;

      connectionInfo['status'] = connectivityResult != ConnectivityResult.none ? 'connected' : 'disconnected';
      connectionInfo['connectionType'] = _mapConnectivityResult(connectivityResult);

      if (connectivityResult != ConnectivityResult.none) {
        connectionInfo['interfaceTypes'] = connectivityResults.map(_mapConnectivityResult).toList();
        connectionInfo['availableInterfaces'] = connectivityResults.map(_mapConnectivityResult).toList();
      }
    } catch (error) {
      verboseLog('Network info fetch failed: $error');
    }

    return connectionInfo;
  }

  String _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi: return 'wifi';
      case ConnectivityResult.mobile: return 'cellular';
      case ConnectivityResult.ethernet: return 'ethernet';
      case ConnectivityResult.none: return 'none';
      default: return 'unknown';
    }
  }

  Future<Map<String, dynamic>> getNetworkPathInfo() async {
    return {
      'supportsIPv4': true,
      'supportsIPv6': false,
      'supportsDNS': true,
    };
  }

  // MARK: Backend API Integration
  Future<void> sendSystemInfoToBackend(Map<String, dynamic> systemInfo) async {
    if (_verboseLogging) {
      print('[Insert Affiliate] Sending system info to backend...');
    }

    try {
      const apiUrlString = 'https://insertaffiliate.link/V1/appDeepLinkEvents';
      verboseLog('Sending request to: $apiUrlString');

      final response = await http.post(
        Uri.parse(apiUrlString),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(systemInfo),
      );

      verboseLog('System info response status: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        verboseLog('System info response: ${response.body}');
      }

      // Parse backend response and persist matched short code if present
      if (response.body.isNotEmpty) {
        try {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          final matchFound = responseData['matchFound'] ?? false;
          if (matchFound && responseData['matched_affiliate_shortCode'] != null) {
            final matchedShortCode = responseData['matched_affiliate_shortCode'] as String;
            if (matchedShortCode.isNotEmpty) {
              verboseLog('Storing matched short code from backend: $matchedShortCode');
              await storeInsertAffiliateIdentifier(link: matchedShortCode, source: AffiliateAssociationSource.clipboardMatch);
            }
          }
        } catch (parseError) {
          verboseLog('Error parsing backend response: $parseError');
        }
      }

      if (response.statusCode >= 200 && response.statusCode <= 299) {
        verboseLog('System info sent successfully');
      } else {
        verboseLog('Failed to send system info with status code: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          verboseLog('Error response: ${response.body}');
        }
      }
    } catch (error) {
      verboseLog('Error sending system info: $error');
    }
  }

  // MARK: Updated Store Method with Callback
  Future<void> storeInsertAffiliateIdentifier({
    required String link,
    required AffiliateAssociationSource source,
  }) async {
    print('[Insert Affiliate] Storing affiliate identifier: $link (source: ${_sourceToString(source)})');
    verboseLog('Updating state with referrer link: $link');
    final prefs = await SharedPreferences.getInstance();
    verboseLog('Saving referrer link to storage...');

    // Check if the referrer link is different from what's already stored
    final existingLink = prefs.getString(_referrerLinkKey);
    final isNewOrDifferent = existingLink != link;

    if (!isNewOrDifferent) {
      verboseLog('Link $link is already stored, skipping duplicate storage');
      return;
    }

    // Check if transfer prevention is enabled and an existing affiliate is present
    if (_preventAffiliateTransfer && existingLink != null && existingLink.isNotEmpty) {
      verboseLog('Transfer blocked: existing affiliate "$existingLink" protected from being replaced by "$link"');
      print('[Insert Affiliate] Transfer blocked: existing affiliate "$existingLink" protected from being replaced by "$link"');
      return;
    }

    await prefs.setString(_referrerLinkKey, link);

    // Store the attribution date for new affiliate identifier
    final attributionDate = DateTime.now().toIso8601String();
    await prefs.setString('affiliate_attribution_date', attributionDate);
    verboseLog('New affiliate identifier stored with fresh attribution date');

    verboseLog('Referrer link saved to storage successfully');

    // Automatically fetch and store offer code
    verboseLog('Attempting to fetch offer code for stored affiliate identifier...');
    final offerCode = await retrieveAndStoreOfferCode(link);

    // Trigger callback with both the current affiliate identifier and offer code
    if (_insertAffiliateIdentifierChangeCallback != null) {
      final currentIdentifier = await returnInsertAffiliateIdentifier(ignoreTimeout: true);
      verboseLog('Triggering callback with identifier: $currentIdentifier, offerCode: $offerCode');
      _insertAffiliateIdentifierChangeCallback!(currentIdentifier, offerCode);
    }

    // Report this new affiliate association to the backend (fire and forget)
    final fullIdentifier = await returnInsertAffiliateIdentifier(ignoreTimeout: true);
    if (fullIdentifier != null) {
      _reportAffiliateAssociationIfNeeded(fullIdentifier, source);
    }
  }

  // Dispose the subscription to avoid memory leaks
  @override
  void dispose() {
    super.dispose();
  }

  // Helper function for verbose logging
  void verboseLog(String message) {
    if (_verboseLogging) {
      print('[Insert Affiliate] [VERBOSE] $message');
    }
  }

  // Function to log errors and warnings
  void errorLog(String message, [String type = "log"]) {
    switch (type) {
      case "error":
        // ignore: avoid_print
        print("[Insert Affiliate] ERROR: $message"); // Using high level for errors
        break;
      case "warn":
        // ignore: avoid_print
        print("[Insert Affiliate] WARN: $message");  // Medium level for warnings
        break;
      default:
        // ignore: avoid_print
        print("[Insert Affiliate] LOG: $message");
        break;
    }
  }

  Future<bool> validatePurchaseWithIapticAPI(
    Map<String, dynamic> jsonIapPurchase,
    String iapticAppId,
    String iapticAppName,
    String iapticPublicKey
  ) async {
    try {
      // Step 1: Base request body
      final Map<String, dynamic> baseRequestBody = {
        'id': iapticAppId,
        'type': 'application',
      };

      // Step 2: Construct platform-specific transaction details
      Map<String, dynamic> transaction;

      if (Platform.isIOS) {
        transaction = {
          'id': iapticAppId,
          'type': 'ios-appstore',
          'appStoreReceipt': jsonIapPurchase['transactionReceipt'],
        };
      } else if (Platform.isAndroid) {
        // Decode Android receipt
        final receiptJson = jsonDecode(utf8.decode(base64.decode(jsonIapPurchase['transactionReceipt'] ?? "")));
        transaction = {
          'id': receiptJson['orderId'], // Extracted orderId
          'type': 'android-playstore',
          'purchaseToken': receiptJson['purchaseToken'], // Extracted purchase token
          'receipt': jsonIapPurchase['transactionReceipt'], // Full receipt (Base64)
          'signature': receiptJson['signature'], // Receipt signature
        };
      } else {
        throw UnsupportedError("Unsupported platform");
      }

      // Step 3: Build the full request body
      final Map<String, dynamic> requestBody = {
        ...baseRequestBody,
        'transaction': transaction,
      };

      // Step 4: Add additional data if available
      final String? insertAffiliateApplicationUsername = await returnInsertAffiliateIdentifier();
      if (insertAffiliateApplicationUsername != null) {
        requestBody['additionalData'] = {
          'applicationUsername': '$insertAffiliateApplicationUsername',
        };
      }

      // Step 5: Send validation request to the server
      final response = await http.post(
        Uri.parse('https://validator.iaptic.com/v1/validate'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$iapticAppName:$iapticPublicKey'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Step 6: Handle server response
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (error) {
      return false;
    }
  }
}
