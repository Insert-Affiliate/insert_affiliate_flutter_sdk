# AppsFlyer Deep Linking Integration

This guide shows how to integrate Insert Affiliate Flutter SDK with AppsFlyer for deep linking attribution.

## Prerequisites

- [AppsFlyer Flutter SDK](https://pub.dev/packages/appsflyer_sdk) installed and configured
- Create an AppsFlyer OneLink and provide it to affiliates via the [Insert Affiliate dashboard](https://app.insertaffiliate.com/affiliates)
- AppsFlyer Dev Key from your AppsFlyer dashboard
- iOS App ID and Android package name configured in AppsFlyer

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  insert_affiliate_flutter_sdk: <latest_version>
  appsflyer_sdk: ^6.14.4
```

## Platform Configuration

### Android Setup

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="com.android.vending.INSTALL_REFERRER" />

<activity android:name=".MainActivity" android:exported="true">
    <!-- OneLink deep linking -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="YOUR_SUBDOMAIN.onelink.me" />
    </intent-filter>
</activity>

<!-- AppsFlyer metadata -->
<application>
    <meta-data android:name="com.appsflyer.ApiKey" android:value="YOUR_APPSFLYER_DEV_KEY" />
</application>
```

### iOS Setup

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>YOUR_CUSTOM_SCHEME</string></array>
    </dict>
</array>
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:YOUR_SUBDOMAIN.onelink.me</string>
</array>
```

## Integration Examples

Choose the example that matches your IAP verification platform:

### Example with RevenueCat

```dart
import 'package:flutter/material.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;
late AppsflyerSdk _appsflyerSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AppsFlyer SDK
  final AppsFlyerOptions appsFlyerOptions = AppsFlyerOptions(
    afDevKey: "YOUR_APPSFLYER_DEV_KEY",
    appId: "YOUR_IOS_APP_ID", // iOS App ID (numbers only)
    showDebug: true,
  );
  _appsflyerSdk = AppsflyerSdk(appsFlyerOptions);

  // Initialize Insert Affiliate SDK
  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeAppsFlyer();
  }

  Future<void> _initializeAppsFlyer() async {
    // Initialize RevenueCat
    await Purchases.configure(PurchasesConfiguration("YOUR_REVENUECAT_API_KEY"));

    // Initialize AppsFlyer
    await _appsflyerSdk.initSdk(
      registerConversionDataCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    // Handle deep links
    _appsflyerSdk.onDeepLinking((deepLinkResult) async {
      if (deepLinkResult.status == Status.FOUND) {
        final deepLinkValue = deepLinkResult.deepLink?.deepLinkValue;
        if (deepLinkValue != null && deepLinkValue.isNotEmpty) {
          await insertAffiliateSdk.setInsertAffiliateIdentifier(deepLinkValue);

          // Set RevenueCat attributes
          final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
          if (affiliateId != null) {
            await Purchases.setAttributes({"insert_affiliate": affiliateId});
            await Purchases.syncAttributesAndOfferingsIfNeeded();
          }
        }
      }
    });

    // Handle install conversion data (deferred deep linking)
    _appsflyerSdk.onInstallConversionData((installConversionData) async {
      if (installConversionData?['af_status'] == 'Non-organic') {
        final affiliateLink = installConversionData?['media_source'] ??
                             installConversionData?['campaign'];
        if (affiliateLink != null) {
          await insertAffiliateSdk.setInsertAffiliateIdentifier(affiliateLink);

          final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
          if (affiliateId != null) {
            await Purchases.setAttributes({"insert_affiliate": affiliateId});
            await Purchases.syncAttributesAndOfferingsIfNeeded();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

### Example with Adapty

```dart
import 'package:flutter/material.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;
late AppsflyerSdk _appsflyerSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppsFlyerOptions appsFlyerOptions = AppsFlyerOptions(
    afDevKey: "YOUR_APPSFLYER_DEV_KEY",
    appId: "YOUR_IOS_APP_ID",
    showDebug: true,
  );
  _appsflyerSdk = AppsflyerSdk(appsFlyerOptions);

  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeAppsFlyer();
  }

  Future<void> _initializeAppsFlyer() async {
    // Initialize Adapty
    await Adapty().activate(
      configuration: AdaptyConfiguration(apiKey: 'YOUR_ADAPTY_PUBLIC_KEY')
        ..withLogLevel(AdaptyLogLevel.verbose),
    );

    await _appsflyerSdk.initSdk(
      registerConversionDataCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    _appsflyerSdk.onDeepLinking((deepLinkResult) async {
      if (deepLinkResult.status == Status.FOUND) {
        final deepLinkValue = deepLinkResult.deepLink?.deepLinkValue;
        if (deepLinkValue != null && deepLinkValue.isNotEmpty) {
          await insertAffiliateSdk.setInsertAffiliateIdentifier(deepLinkValue);

          final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
          if (affiliateId != null) {
            final builder = AdaptyProfileParametersBuilder()
              ..setCustomStringAttribute(affiliateId, 'insert_affiliate');
            await Adapty().updateProfile(builder.build());
          }
        }
      }
    });

    _appsflyerSdk.onInstallConversionData((installConversionData) async {
      if (installConversionData?['af_status'] == 'Non-organic') {
        final affiliateLink = installConversionData?['media_source'] ??
                             installConversionData?['campaign'];
        if (affiliateLink != null) {
          await insertAffiliateSdk.setInsertAffiliateIdentifier(affiliateLink);

          final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
          if (affiliateId != null) {
            final builder = AdaptyProfileParametersBuilder()
              ..setCustomStringAttribute(affiliateId, 'insert_affiliate');
            await Adapty().updateProfile(builder.build());
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

### Example with Apphud

```dart
import 'package:flutter/material.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:apphud_sdk/apphud_sdk.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;
late AppsflyerSdk _appsflyerSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppsFlyerOptions appsFlyerOptions = AppsFlyerOptions(
    afDevKey: "YOUR_APPSFLYER_DEV_KEY",
    appId: "YOUR_IOS_APP_ID",
    showDebug: true,
  );
  _appsflyerSdk = AppsflyerSdk(appsFlyerOptions);

  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeAppsFlyer();
  }

  Future<void> _initializeAppsFlyer() async {
    await Apphud.start(apiKey: "YOUR_APPHUD_API_KEY");

    await _appsflyerSdk.initSdk(
      registerConversionDataCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    _appsflyerSdk.onDeepLinking((deepLinkResult) async {
      if (deepLinkResult.status == Status.FOUND) {
        final deepLinkValue = deepLinkResult.deepLink?.deepLinkValue;
        if (deepLinkValue != null && deepLinkValue.isNotEmpty) {
          await insertAffiliateSdk.setInsertAffiliateIdentifier(deepLinkValue);

          final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
          if (affiliateId != null) {
            Apphud.setUserProperty(key: "insert_affiliate", value: affiliateId, setOnce: false);
          }
        }
      }
    });

    _appsflyerSdk.onInstallConversionData((installConversionData) async {
      if (installConversionData?['af_status'] == 'Non-organic') {
        final affiliateLink = installConversionData?['media_source'] ??
                             installConversionData?['campaign'];
        if (affiliateLink != null) {
          await insertAffiliateSdk.setInsertAffiliateIdentifier(affiliateLink);

          final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
          if (affiliateId != null) {
            Apphud.setUserProperty(key: "insert_affiliate", value: affiliateId, setOnce: false);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

### Example with App Store / Google Play Direct

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;
late AppsflyerSdk _appsflyerSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppsFlyerOptions appsFlyerOptions = AppsFlyerOptions(
    afDevKey: "YOUR_APPSFLYER_DEV_KEY",
    appId: "YOUR_IOS_APP_ID",
    showDebug: true,
  );
  _appsflyerSdk = AppsflyerSdk(appsFlyerOptions);

  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
  );

  runApp(MyApp());
}

class _MyAppState extends State<MyApp> {
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  void initState() {
    super.initState();
    _initializeAppsFlyer();
  }

  Future<void> _initializeAppsFlyer() async {
    await _appsflyerSdk.initSdk(
      registerConversionDataCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    _appsflyerSdk.onDeepLinking((deepLinkResult) async {
      if (deepLinkResult.status == Status.FOUND) {
        final deepLinkValue = deepLinkResult.deepLink?.deepLinkValue;
        if (deepLinkValue != null && deepLinkValue.isNotEmpty) {
          await insertAffiliateSdk.setInsertAffiliateIdentifier(deepLinkValue);
        }
      }
    });

    _appsflyerSdk.onInstallConversionData((installConversionData) async {
      if (installConversionData?['af_status'] == 'Non-organic') {
        final affiliateLink = installConversionData?['media_source'] ??
                             installConversionData?['campaign'];
        if (affiliateLink != null) {
          await insertAffiliateSdk.setInsertAffiliateIdentifier(affiliateLink);
        }
      }
    });
  }

  // iOS App Store Direct
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

  // Google Play Direct
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
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
```

## Deep Link Callback Types

AppsFlyer provides two types of deep link callbacks:

| Callback | When It Fires | Use Case |
|----------|---------------|----------|
| `onDeepLinking` | App opened via deep link (app installed) | Direct attribution |
| `onInstallConversionData` | First app launch after install | Deferred deep linking |

For comprehensive affiliate tracking, listen to both callbacks as shown in the examples.

## Configuration Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `YOUR_APPSFLYER_DEV_KEY` | Your AppsFlyer Dev Key | From AppsFlyer dashboard |
| `YOUR_IOS_APP_ID` | iOS App ID (numbers only) | `123456789` |
| `YOUR_SUBDOMAIN` | OneLink subdomain | `yourapp` (from yourapp.onelink.me) |
| `YOUR_CUSTOM_SCHEME` | Custom URL scheme | `myapp` |

## Testing

Test your AppsFlyer deep link integration:

```bash
# Android Emulator
adb shell am start -W -a android.intent.action.VIEW -d "https://YOUR_SUBDOMAIN.onelink.me/LINK_ID/test"

# iOS Simulator
xcrun simctl openurl booted "https://YOUR_SUBDOMAIN.onelink.me/LINK_ID/test"
```

Check logs:
```bash
flutter logs | grep -E "(AppsFlyer|Insert Affiliate)"
```

## Troubleshooting

**Problem:** App opens store instead of app
- **Solution:** Verify package name/bundle ID and certificate fingerprints in AppsFlyer OneLink settings

**Problem:** No attribution data
- **Solution:** Ensure AppsFlyer SDK initialization occurs before setting up callbacks

**Problem:** Deep links not working
- **Solution:** Check intent-filter/URL scheme configuration in manifest/plist

**Problem:** `deepLinkValue` is null
- **Solution:** Log the full `deepLinkResult` to see available fields; the data structure may vary

## Next Steps

After completing AppsFlyer integration:
1. Test deep link attribution with a test affiliate link
2. Verify affiliate identifier is stored correctly
3. Make a test purchase to confirm tracking works end-to-end

[Back to Main README](../README.md)
