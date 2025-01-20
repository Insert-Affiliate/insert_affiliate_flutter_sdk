import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:io'; // For platform detection

class InsertAffiliateFlutterSDK extends ChangeNotifier {
  final String companyCode;

  InsertAffiliateFlutterSDK({
    required this.companyCode,
  }) {
    _init();
  }

  void _init() async {
    final prefs = await SharedPreferences.getInstance();
    _storeAndReturnShortUniqueDeviceId();
  }

  // MARK: Company Code
  String getCompanyCode() {
    return companyCode;
  }

  // MARK: Short Codes
  bool isShortCode(String link) {
    return RegExp(r'^[a-zA-Z0-9]{10}$').hasMatch(link);
  }

  Future<void> setShortCode(String shortCode) async {
    if (shortCode.isEmpty) {
      errorLog("Short code cannot be empty", "warn");
      return;
    }

    shortCode = shortCode.toUpperCase();

    if (shortCode.length != 10 || !RegExp(r'^[a-zA-Z0-9]{10}$').hasMatch(shortCode)) {
      errorLog("Short code must be exactly 10 characters and contain only letters and numbers", "warn");
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
    final prefs = await SharedPreferences.getInstance();
    final existingUserId = prefs.getString('shortUniqueDeviceID');
    if (existingUserId != null) {
      return existingUserId;
    }
    final userId = _generateUserId();
    await prefs.setString('shortUniqueDeviceID', userId);
    return userId;
  }

  // MARK: Setting Insert Affiliate Link
  Future<void> setInsertAffiliateIdentifier(String referringLink) async {
    if (companyCode.isEmpty) {
      errorLog("Company code cannot be empty", "warn");
      return;
    }

    if (isShortCode(referringLink)) {
      await _storeInsertAffiliateReferringLink(referringLink);
      return;
    }

    final encodedAffiliateLink = Uri.encodeComponent(referringLink);
    final urlString = "http://api.insertaffiliate.com/V1/convert-deep-link-to-short-link?companyId=$companyCode&deepLinkUrl=$encodedAffiliateLink";

    try {
      final response = await http.get(
        Uri.parse(urlString),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final shortLink = jsonResponse['shortLink'];

        if (shortLink != null && shortLink.isNotEmpty) {
          await _storeInsertAffiliateReferringLink(shortLink);
          return;
        } else { // If theres an issue, store what was passed to save for later potential processing/recovery
          await _storeInsertAffiliateReferringLink(referringLink);
        }
      }
    } catch (error) {
      errorLog("Error setting insert affiliate identifier: $error", "error");
    }

    await _storeInsertAffiliateReferringLink(referringLink);
  }

  Future<void> _storeInsertAffiliateReferringLink(String referringLink) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('referring_link', referringLink);
    notifyListeners();
  }

  Future<String?> returnInsertAffiliateIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final referringLink = prefs.getString('referring_link');
    final shortUniqueDeviceID = prefs.getString('shortUniqueDeviceID');
    if (referringLink == null || shortUniqueDeviceID == null) {
      return null;
    }
    return "$referringLink-${shortUniqueDeviceID}";
  }

  // MARK: Event Tracking
  Future<void> trackEvent({required String eventName}) async {
    try {
      final affiliateLink = await returnInsertAffiliateIdentifier();

      if (affiliateLink == null) {
        errorLog(
          "[Insert Affiliate] No affiliate link found. Please save one before tracking events.",
          "warn",
        );
        return;
      }

      final payload = {
        "eventName": eventName,
        "deepLinkParam": affiliateLink,
      };

      final response = await http.post(
        Uri.parse('https://api.insertaffiliate.com/v1/trackEvent'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // ignore: avoid_print
      } else {
        errorLog(
          "[Insert Affiliate] Failed to track event. Status code: ${response.statusCode}, Response: ${response.body}",
          "error",
        );
      }
    } catch (error) {
      errorLog("[Insert Affiliate] Error tracking event: $error", "error");
    }
  }

  // Dispose the subscription to avoid memory leaks
  @override
  void dispose() {
    super.dispose();
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
