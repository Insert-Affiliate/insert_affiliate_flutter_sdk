import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart'; 
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:io'; // For platform detection

class InsertAffiliateFlutterSDK extends ChangeNotifier {
  final List<String> iapSkus;// TODO: move out of app init, not required here probably
  final String companyCode;
  final String iapticAppId;// TODO: move out of app init, not required here probably
  final String iapticAppName;// TODO: move out of app init, not required here probably
  final String iapticPublicKey;// TODO: move out of app init, not required here probably

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  InsertAffiliateFlutterSDK({
    required this.iapSkus,// TODO: move out of app init, not required here probably
    required this.companyCode,
    required this.iapticAppId, // TODO: move out of app init, not required here probably
    required this.iapticAppName,// TODO: move out of app init, not required here probably
    required this.iapticPublicKey,// TODO: move out of app init, not required here probably
  }) {
    _init();
  }

  // TODO: Michael - move the purchases part of the init into the demo app and out of the SDK!
  void _init() async {
    print("_init");
    final purchaseUpdates = InAppPurchase.instance.purchaseStream;
    final prefs = await SharedPreferences.getInstance();

    _storeAndReturnShortUniqueDeviceId();

    // Load the list of processed purchase IDs
    Set<String> processedPurchases = prefs.getStringList('processedPurchases')?.toSet() ?? {};

    _subscription = purchaseUpdates.listen((purchases) async {
      for (var purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased && !processedPurchases.contains(purchase.purchaseID)) {
          validatePurchaseWithIapticAPI(purchase);

          // Mark this purchase as processed
          processedPurchases.add(purchase.purchaseID ?? "");
          await prefs.setStringList('processedPurchases', processedPurchases.toList());
        }
      }
    });
  }

  // MARK: Company Code
  String getCompanyCode() {
    return companyCode;
  }

  // MARK: Short Codes
  bool isShortCode(String link) {
    return link != null && RegExp(r'^[a-zA-Z0-9]{10}$').hasMatch(link);
  }

  Future<void> setShortCode(String shortCode) async {
    print("setShortCode: $shortCode");
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
    print("_storeAndReturnShortUniqueDeviceId");
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
    print("setInsertAffiliateIdentifier: $referringLink");
    if (companyCode.isEmpty) {
      errorLog("Company code cannot be empty", "warn");
      return;
    }

    if (isShortCode(referringLink)) {
      print("setInsertAffiliateIdentifier isShortCode - $referringLink");
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
          print("setInsertAffiliateIdentifier shortLink - $shortLink");
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
    print("_storeInsertAffiliateReferringLink: $referringLink");    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('referring_link', referringLink);
    notifyListeners();
  }

  Future<String?> returnInsertAffiliateIdentifier() async {
    print("returnInsertAffiliateIdentifier");
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
    print("trackEvent: $eventName");
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
        print("[Insert Affiliate] Event tracked successfully");
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
    _subscription?.cancel();
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

  // MARK: Validate with Iaptic API
  Future<void> validatePurchaseWithIapticAPI(PurchaseDetails purchaseDetails) async {
    print("validatePurchaseWithIapticAPI");
    try {
      final receiptData = await SKReceiptManager.retrieveReceiptData();
      var applicationUsername = await returnInsertAffiliateIdentifier();

      // Platform-specific transaction details
      Map<String, dynamic> transactionDetails;

      if (Platform.isIOS) {
        // iOS-specific transaction details
        transactionDetails = {
          'id': iapticAppId,
          'type': 'ios-appstore',
          'appStoreReceipt': receiptData,
        };
      } else if (Platform.isAndroid) {
        // Android-specific transaction details
        transactionDetails = {
          'id': purchaseDetails.purchaseID ?? '',
          'type': 'android-playstore',
          'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
          'receipt': purchaseDetails.verificationData.serverVerificationData,
          'signature': purchaseDetails.verificationData.localVerificationData,
        };
      } else {
        throw UnsupportedError("Unsupported platform");
      }

      // Construct the request body
      final requestBody = {
        'id': iapticAppId,
        'type': 'application',
        'transaction': transactionDetails,
      };

      if (applicationUsername != null) {
        requestBody['additionalData'] = {
          'applicationUsername': applicationUsername,
        };
      }

      final response = await http.post(
        Uri.parse('https://validator.iaptic.com/v1/validate'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$iapticAppName:$iapticPublicKey'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        // ignore: avoid_print
        print("[Insert Affiliate] Validation successful");
      } else {
        // ignore: avoid_print
        print("[Insert Affiliate] Validation failed: ${response.body}");
        errorLog("Validation failed: ${response.body}", "error");
      }
    } catch (error) {
      errorLog("validatePurchaseWithIapticAPI: $error", "error");
    }
  }
}
