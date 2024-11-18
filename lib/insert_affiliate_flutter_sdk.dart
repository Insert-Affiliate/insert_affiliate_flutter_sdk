import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

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
          _logPurchaseComplete(purchase);

          handlePurchaseValidation(purchase);

          // Mark this purchase as processed
          processedPurchases.add(purchase.purchaseID ?? "");
          await prefs.setStringList('processedPurchases', processedPurchases.toList());
        }
      }
    });
  }

  // Log purchase completion
  void _logPurchaseComplete(PurchaseDetails purchase) async {
    print("[Insert Affiliate] New purchase complete: ${purchase.productID}");
    final prefs = await SharedPreferences.getInstance();

    print("[Insert Affiliate] retrieveInsertAffiliateLink: ${retrieveInsertAffiliateLink()}");
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
        print("[Insert Affiliate] ERROR: $message"); // Using high level for errors
        break;
      case "warn":
        print("[Insert Affiliate] WARN: $message");  // Medium level for warnings
        break;
      default:
        print("[Insert Affiliate] LOG: $message");
        break;
    }
  }

  Future<void> handlePurchaseValidation(PurchaseDetails purchaseDetails) async {
    try {
      final receiptData = await SKReceiptManager.retrieveReceiptData();
      var applicationUsername = await retrieveInsertAffiliateLink();

      print("[Insert Affiliate] Application username on handlePurchaseValidation: $applicationUsername");

      if (receiptData == null) {
        errorLog("[Insert Affiliate] Receipt data is empty. Ensure purchases are processed correctly.", "error");
        throw Exception('Receipt data is empty. Ensure purchases are processed correctly.');
      }

      final requestBody = {
        'id': iapticAppId,
        'type': 'application',
        'transaction': {
          'id': iapticAppId,
          'type': 'ios-appstore',
          'appStoreReceipt': receiptData,
        },
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
        print(response.body);
        print("[Insert Affiliate] Validation successful");
      } else {
        print("[Insert Affiliate] Validation failed: ${response.body}");
        errorLog("Validation failed: ${response.body}", "error");
      }
    } catch (error) {
      errorLog("handlePurchaseValidation: $error", "error");
    }
  }
}
