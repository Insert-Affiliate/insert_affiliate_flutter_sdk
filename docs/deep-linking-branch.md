# Branch.io Deep Linking Integration

This guide shows how to integrate Insert Affiliate Flutter SDK with Branch.io for deep linking attribution.

## Prerequisites

- [Flutter Branch SDK](https://pub.dev/packages/flutter_branch_sdk) installed and configured
- Create a Branch deep link and provide it to affiliates via the [Insert Affiliate dashboard](https://app.insertaffiliate.com/affiliates)

## Platform Setup

Complete the deep linking setup for Branch by following their official documentation:
- [Flutter Branch SDK Setup Guide](https://pub.dev/packages/flutter_branch_sdk)

This covers:
- iOS: Info.plist configuration and universal links
- Android: AndroidManifest.xml intent filters and App Links

## Integration Examples

Choose the example that matches your IAP verification platform:

### Example with RevenueCat

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Insert Affiliate SDK
  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<Map> _branchStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAsyncDependencies();
  }

  Future<void> _initializeAsyncDependencies() async {
    // Step 1: Initialize RevenueCat
    await Purchases.configure(PurchasesConfiguration("YOUR_REVENUECAT_API_KEY"));

    // Step 2: Handle initial affiliate identifier
    handleAffiliateIdentifier();

    // Step 3: Listen for Branch deep links
    _branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) {
      if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
        final referringLink = data["~referring_link"];
        insertAffiliateSdk.setInsertAffiliateIdentifier(referringLink);

        // Handle affiliate identifier after deep link click
        handleAffiliateIdentifier();
      }
    }, onError: (error) {
      print('Branch session error: ${error.toString()}');
    });
  }

  void handleAffiliateIdentifier() {
    insertAffiliateSdk.returnInsertAffiliateIdentifier().then((value) {
      if (value != null && value.isNotEmpty) {
        Purchases.setAttributes({"insert_affiliate": value});
      }
    });
  }

  @override
  void dispose() {
    _branchStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

### Example with Adapty

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<Map> _branchStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAsyncDependencies();
  }

  Future<void> _initializeAsyncDependencies() async {
    // Initialize Adapty
    await Adapty().activate(
      configuration: AdaptyConfiguration(apiKey: 'YOUR_ADAPTY_PUBLIC_KEY')
        ..withLogLevel(AdaptyLogLevel.verbose),
    );

    // Handle initial affiliate identifier
    await handleAffiliateIdentifier();

    // Listen for Branch deep links
    _branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) async {
      if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
        final referringLink = data["~referring_link"];
        insertAffiliateSdk.setInsertAffiliateIdentifier(referringLink);
        await handleAffiliateIdentifier();
      }
    }, onError: (error) {
      print('Branch session error: ${error.toString()}');
    });
  }

  Future<void> handleAffiliateIdentifier() async {
    final value = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
    if (value != null && value.isNotEmpty) {
      final builder = AdaptyProfileParametersBuilder()
        ..setCustomStringAttribute(value, 'insert_affiliate');
      await Adapty().updateProfile(builder.build());
    }
  }

  @override
  void dispose() {
    _branchStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

### Example with Apphud

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:apphud_sdk/apphud_sdk.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<Map> _branchStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAsyncDependencies();
  }

  Future<void> _initializeAsyncDependencies() async {
    // Initialize Apphud
    await Apphud.start(apiKey: "YOUR_APPHUD_API_KEY");

    // Handle initial affiliate identifier
    handleAffiliateIdentifier();

    // Listen for Branch deep links
    _branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) {
      if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
        final referringLink = data["~referring_link"];
        insertAffiliateSdk.setInsertAffiliateIdentifier(referringLink);
        handleAffiliateIdentifier();
      }
    }, onError: (error) {
      print('Branch session error: ${error.toString()}');
    });
  }

  void handleAffiliateIdentifier() {
    insertAffiliateSdk.returnInsertAffiliateIdentifier().then((value) {
      if (value != null && value.isNotEmpty) {
        Apphud.setUserProperty(key: "insert_affiliate", value: value, setOnce: false);
      }
    });
  }

  @override
  void dispose() {
    _branchStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

### Example with Iaptic

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<Map> _branchStreamSubscription;
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  void initState() {
    super.initState();
    _setupBranchListener();
  }

  void _setupBranchListener() {
    _branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) {
      if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
        final referringLink = data["~referring_link"];
        insertAffiliateSdk.setInsertAffiliateIdentifier(referringLink);
      }
    }, onError: (error) {
      print('Branch session error: ${error.toString()}');
    });
  }

  // Use affiliate identifier when validating purchases with Iaptic
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        final jsonIapPurchase = {
          'transactionReceipt': purchaseDetails.verificationData.localVerificationData,
          'orderId': purchaseDetails.purchaseID,
          'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
          'signature': purchaseDetails.verificationData.localVerificationData,
          'applicationUsername': await insertAffiliateSdk.returnInsertAffiliateIdentifier(),
        };

        await insertAffiliateSdk.validatePurchaseWithIapticAPI(
          jsonIapPurchase,
          "YOUR_IAPTIC_APP_ID",
          "YOUR_IAPTIC_APP_NAME",
          "YOUR_IAPTIC_PUBLIC_KEY"
        );
      }
    }
  }

  @override
  void dispose() {
    _branchStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

### Example with App Store / Google Play Direct

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<Map> _branchStreamSubscription;
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  void initState() {
    super.initState();
    _setupBranchListener();
  }

  void _setupBranchListener() {
    _branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) {
      if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
        final referringLink = data["~referring_link"];
        insertAffiliateSdk.setInsertAffiliateIdentifier(referringLink);
      }
    }, onError: (error) {
      print('Branch session error: ${error.toString()}');
    });
  }

  // iOS App Store Direct: Use appAccountToken
  void _buySubscription(ProductDetails product) async {
    String? appAccountToken;
    if (Platform.isIOS) {
      appAccountToken = await insertAffiliateSdk.returnUserAccountTokenAndStoreExpectedTransaction();
    }

    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: appAccountToken,
    );

    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // Google Play Direct: Store purchase token
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        if (Platform.isAndroid && purchaseDetails is GooglePlayPurchaseDetails) {
          final purchaseToken = purchaseDetails.billingClientPurchase.purchaseToken;
          if (purchaseToken.isNotEmpty) {
            await insertAffiliateSdk.storeExpectedStoreTransaction(purchaseToken);
          }
        }
        InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  @override
  void dispose() {
    _branchStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

## Testing

Test your Branch deep link integration:

```bash
# Android Emulator
adb shell am start -W -a android.intent.action.VIEW -d "https://your-app.app.link/abc123"

# iOS Simulator
xcrun simctl openurl booted "https://your-app.app.link/abc123"
```

## Troubleshooting

**Problem:** `~referring_link` is null
- **Solution:** Ensure Branch SDK is properly initialized before Insert Affiliate SDK
- Verify Branch link is properly configured with your app's URI scheme

**Problem:** Deep link opens browser instead of app
- **Solution:** Check Branch dashboard for associated domains configuration
- Verify your app's entitlements include the Branch link domain (iOS)
- Verify AndroidManifest.xml has correct intent filters (Android)

**Problem:** Deferred deep linking not working
- **Solution:** Make sure you're using `FlutterBranchSdk.listSession()` correctly
- Test with a fresh app install (uninstall/reinstall)

## Next Steps

After completing Branch integration:
1. Test deep link attribution with a test affiliate link
2. Verify affiliate identifier is stored correctly
3. Make a test purchase to confirm tracking works end-to-end

[Back to Main README](../README.md)
