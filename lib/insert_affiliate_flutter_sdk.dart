import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:io'; // For platform detection
import 'package:url_launcher/url_launcher.dart';

class InsertAffiliateFlutterSDK extends ChangeNotifier {
  final String companyCode;
  bool _verboseLogging = false;

  InsertAffiliateFlutterSDK({
    required this.companyCode,
    bool verboseLogging = false,
  }) : _verboseLogging = verboseLogging {
    _init();
  }

  void _init() async {
    if (_verboseLogging) {
      print('[Insert Affiliate] [VERBOSE] Starting SDK initialization...');
      print('[Insert Affiliate] [VERBOSE] Company code provided: ${companyCode.isNotEmpty ? 'Yes' : 'No'}');
      print('[Insert Affiliate] [VERBOSE] Verbose logging enabled');
    }
    
    _storeAndReturnShortUniqueDeviceId();
    
    if (_verboseLogging) {
      print('[Insert Affiliate] [VERBOSE] SDK initialization completed');
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

  Future<void> setShortCode(String shortCode) async {
    if (shortCode.isEmpty) {
      errorLog("Short code cannot be empty", "warn");
      return;
    }

    shortCode = shortCode.toUpperCase();

    if (shortCode.length < 3 || shortCode.length > 25 || !RegExp(r'^[a-zA-Z0-9]{3,25}$').hasMatch(shortCode)) {
      errorLog("Short code must be between 3-25 characters and contain only letters and numbers", "warn");
      return;
    }

    await _storeInsertAffiliateReferringLink(shortCode);

    notifyListeners();
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
      await _storeInsertAffiliateReferringLink(referringLink);
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
          await _storeInsertAffiliateReferringLink(shortLink);
          verboseLog('Short link stored successfully');
          return;
        } else { // If theres an issue, store what was passed to save for later potential processing/recovery
          verboseLog('Unexpected API response, storing original link as fallback');
          await _storeInsertAffiliateReferringLink(referringLink);
        }
      }
    } catch (error) {
      errorLog("Error setting insert affiliate identifier: $error", "error");
      verboseLog('Error in setInsertAffiliateIdentifier: $error');
    }

    verboseLog('Storing original link as fallback');
    await _storeInsertAffiliateReferringLink(referringLink);
  }

  Future<void> _storeInsertAffiliateReferringLink(String referringLink) async {
    print('[Insert Affiliate] Storing affiliate identifier: $referringLink');
    verboseLog('Saving referrer link to SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('referring_link', referringLink);
    verboseLog('Referrer link saved to SharedPreferences successfully');

    verboseLog('Attempting to fetch offer code for stored affiliate identifier...');
    await retrieveAndStoreOfferCode(referringLink);
    notifyListeners();
  }

  Future<String?> returnInsertAffiliateIdentifier() async {
    verboseLog('Getting insert affiliate identifier...');
    final prefs = await SharedPreferences.getInstance();
    final referringLink = prefs.getString('referring_link');
    final shortUniqueDeviceID = prefs.getString('shortUniqueDeviceID');
    
    verboseLog('SharedPreferences - referringLink: ${referringLink ?? 'empty'}, shortUniqueDeviceID: ${shortUniqueDeviceID ?? 'empty'}');
    
    if (referringLink == null || shortUniqueDeviceID == null) {
      verboseLog('No affiliate identifier found in storage');
      return null;
    }
    
    final identifier = "$referringLink-$shortUniqueDeviceID";
    verboseLog('Found identifier: $identifier');
    return identifier;
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

  Future<void> retrieveAndStoreOfferCode(String affiliateLink) async {
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
      } else {
        verboseLog('No valid offer code found to store');
        // Clear stored offer code if none found
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offer_code', '');
        
        // Notify listeners of the change
        notifyListeners();
      }
    } catch (error) {
      errorLog("Error retrieving and storing offer code: $error", "error");
      verboseLog('Error in retrieveAndStoreOfferCode: $error');
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
