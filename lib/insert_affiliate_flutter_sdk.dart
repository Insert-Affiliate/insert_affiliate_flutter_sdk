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
  final List<String> iapSkus;
  final String iapticAppId;
  final String iapticAppName;
  final String iapticPublicKey;
  static const String _insertAffiliateLinkKey = 'insert_affiliate_link';

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  InsertAffiliateFlutterSDK({
    required this.iapSkus,
    required this.iapticAppId,
    required this.iapticAppName,
    required this.iapticPublicKey,
  }) {
    _initializePurchaseListener();
  }

  String _generateUserId() {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(6, (index) => characters[random.nextInt(characters.length)]).join();
  }

  Future<void> saveInsertAffiliateLink(String referrerLink) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _generateUserId();
    final insertAffiliateLink = "$referrerLink/$userId";

    await prefs.setString(_insertAffiliateLinkKey, insertAffiliateLink);

    notifyListeners();
  }

  // Function to retrieve stored insertAffiliateLink, returns null if not found
  Future<String?> retrieveInsertAffiliateLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_insertAffiliateLinkKey);
  }

  // Initialize the purchase listener
  void _initializePurchaseListener() async {
    final purchaseUpdates = InAppPurchase.instance.purchaseStream;
    final prefs = await SharedPreferences.getInstance();

    // Load the list of processed purchase IDs
    Set<String> processedPurchases = prefs.getStringList('processedPurchases')?.toSet() ?? {};

    _subscription = purchaseUpdates.listen((purchases) async {
      for (var purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased && !processedPurchases.contains(purchase.purchaseID)) {
          handlePurchaseValidation(purchase);

          // Mark this purchase as processed
          processedPurchases.add(purchase.purchaseID ?? "");
          await prefs.setStringList('processedPurchases', processedPurchases.toList());
        }
      }
    });
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

  Future<void> handlePurchaseValidation(PurchaseDetails purchaseDetails) async {
    try {
      final receiptData = await SKReceiptManager.retrieveReceiptData();
      var applicationUsername = await retrieveInsertAffiliateLink();

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
      errorLog("handlePurchaseValidation: $error", "error");
    }
  }
}
