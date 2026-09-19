# Insert Affiliate Flutter SDK

![Version](https://img.shields.io/badge/version-1.0.0-brightgreen) ![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue) ![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)

The official Flutter SDK for [Insert Affiliate](https://insertaffiliate.com) - track affiliate-driven in-app purchases and reward your partners automatically.

**What does this SDK do?** It connects your Flutter app to Insert Affiliate's platform, enabling you to track which affiliates drive subscriptions and automatically pay them commissions when users make in-app purchases.

## Table of Contents

- [Quick Start (5 Minutes)](#-quick-start-5-minutes)
- [Essential Setup](#%EF%B8%8F-essential-setup)
  - [1. Initialize the SDK](#1-initialize-the-sdk)
  - [2. Configure In-App Purchase Verification](#2-configure-in-app-purchase-verification)
  - [3. Set Up Deep Linking](#3-set-up-deep-linking)
- [Verify Your Integration](#-verify-your-integration)
- [Advanced Features](#-advanced-features)
- [Troubleshooting](#-troubleshooting)
- [Support](#-support)

---

## 🚀 Quick Start (5 Minutes)

Get up and running with minimal code to validate the SDK works before tackling IAP and deep linking setup.

### Prerequisites

- **Flutter 3.0+**
- **iOS 13.0+** / **Android API 21+**
- **Company Code** from your [Insert Affiliate dashboard](https://app.insertaffiliate.com/settings)

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  insert_affiliate_flutter_sdk: <latest_version>
  shared_preferences: <latest_version>
  http: <latest_version>
```

Then run:
```bash
flutter pub get
```

### Your First Integration

```dart
import 'package:flutter/material.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Insert Affiliate SDK
  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",  // Get from https://app.insertaffiliate.com/settings
    verboseLogging: true,               // Enable for setup debugging
  );

  runApp(MyApp());
}
```

**Expected Console Output:**

```
[Insert Affiliate] SDK initialized with company code: YOUR_COMPANY_CODE
[Insert Affiliate] [VERBOSE] SDK marked as initialized
```

✅ **If you see these logs, the SDK is working!** Now proceed to Essential Setup.

⚠️ **Disable verbose logging in production** by removing the `verboseLogging: true` parameter.

---

## ⚙️ Essential Setup

Complete these three required steps to start tracking affiliate-driven purchases.

### 1. Initialize the SDK

You've already done basic initialization above. Here are additional options:

<details>
<summary><strong>Advanced Initialization Options</strong> (click to expand)</summary>

```dart
insertAffiliateSdk = InsertAffiliateFlutterSDK(
  companyCode: "YOUR_COMPANY_CODE",
  verboseLogging: true,              // Enable detailed debugging logs
  insertLinksEnabled: true,          // Enable Insert Links (built-in deep linking)
  insertLinksClipboardEnabled: true, // Enable clipboard attribution (triggers permission prompt)
  attributionTimeout: 604800,        // 7 days attribution timeout in seconds
  preventAffiliateTransfer: true,    // Protect original affiliate from being overwritten
);
```

**Parameters:**
- `verboseLogging`: Shows detailed logs for debugging (disable in production)
- `insertLinksEnabled`: Set to `true` if using Insert Links, `false` if using Branch/AppsFlyer
- `insertLinksClipboardEnabled`: Enables clipboard-based attribution for Insert Links
- `attributionTimeout`: How long affiliate attribution lasts in seconds (0 = never expires)
- `preventAffiliateTransfer`: When `true`, blocks new affiliates from overwriting existing attribution (default: `false`)

</details>

---

### 2. Configure In-App Purchase Verification

**Insert Affiliate requires a receipt verification method to validate purchases.** Choose **ONE** of the following:

| Method | Best For | Setup Time | Complexity |
|--------|----------|------------|------------|
| [**RevenueCat**](#option-1-revenuecat-recommended) | Most developers, managed infrastructure | ~10 min | Simple |
| [**Adapty**](#option-2-adapty) | Paywall A/B testing, analytics | ~10 min | Simple |
| [**Iaptic**](#option-3-iaptic) | Custom requirements, direct control | ~15 min | Medium |
| [**App Store Direct**](#option-4-app-store-direct) | No 3rd party fees (iOS) | ~20 min | Medium |
| [**Google Play Direct**](#option-5-google-play-direct) | No 3rd party fees (Android) | ~20 min | Medium |

<details open>
<summary><h4>Option 1: RevenueCat (Recommended)</h4></summary>

**Step 1: Code Setup**

Complete the [RevenueCat Flutter SDK installation](https://www.revenuecat.com/docs/getting-started/installation/flutter) first, then:

```dart
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeAsyncDependencies();
  }

  Future<void> _initializeAsyncDependencies() async {
    // Initialize RevenueCat
    await Purchases.configure(PurchasesConfiguration("YOUR_REVENUECAT_API_KEY"));

    // Set up callback to sync affiliate identifier to RevenueCat whenever it changes
    // Note: Use preventAffiliateTransfer in constructor to block affiliate changes in the SDK
    insertAffiliateSdk.setInsertAffiliateIdentifierChangeCallback((identifier, offerCode) async {
      if (identifier == null) return;

      // Ensure subscriber exists by fetching customer info first
      final customerInfo = await Purchases.getCustomerInfo();

      // OPTIONAL: Prevent attribution for existing subscribers
      // Uncomment to ensure affiliates only earn from users they actually brought:
      // if (customerInfo.entitlements.active.isNotEmpty) return; // User already subscribed, don't attribute

      // Get expiry timestamp for insert_timedout
      final expiryTimestamp = await insertAffiliateSdk.getAffiliateExpiryTimestamp();

      // Set RevenueCat attributes
      var attributes = {
        "insert_affiliate": identifier,
        "insert_timedout": expiryTimestamp?.toString() ?? "",  // Expiry timestamp
      };
      if (offerCode != null) {
        attributes["affiliateOfferCode"] = offerCode;
      }

      await Purchases.setAttributes(attributes);
      print('[RevenueCat] Set attributes: $attributes');

      // Sync attributes and refresh offerings for targeting
      await Purchases.syncAttributesAndOfferingsIfNeeded();
    });

    // Check for existing affiliate identifier on app launch
    final existingId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
    if (existingId != null) {
      final expiryTimestamp = await insertAffiliateSdk.getAffiliateExpiryTimestamp();
      await Purchases.setAttributes({
        "insert_affiliate": existingId,
        "insert_timedout": expiryTimestamp?.toString() ?? "",
      });
    }
  }
}
```

**Step 2: Webhook Setup**

1. In RevenueCat, [create a new webhook](https://www.revenuecat.com/docs/integrations/webhooks)
2. Configure webhook settings:
   - **Webhook URL**: `https://api.insertaffiliate.com/v1/api/revenuecat-webhook`
   - **Event Type**: "All events"
3. In your [Insert Affiliate dashboard](https://app.insertaffiliate.com/settings):
   - Set **In-App Purchase Verification** to `RevenueCat`
   - Copy the `RevenueCat Webhook Authentication Header` value
4. Paste the authentication header into RevenueCat's **Authorization header** field

✅ **RevenueCat setup complete!**

</details>

<details>
<summary><h4>Option 2: Adapty</h4></summary>

**Step 1: Install Adapty SDK**

Add to your `pubspec.yaml`:

```yaml
dependencies:
  adapty_flutter: ^3.2.1
```

Then run:
```bash
flutter pub get
```

Complete the [Adapty Flutter SDK installation](https://adapty.io/docs/sdk-installation-flutter) for any additional platform-specific setup.

**Step 2: Code Setup**

```dart
import 'package:flutter/material.dart';
import 'package:adapty_flutter/adapty_flutter.dart';
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
  @override
  void initState() {
    super.initState();
    _initializeSDKs();
  }

  Future<void> _initializeSDKs() async {
    // Initialize Adapty
    await Adapty().activate(
      configuration: AdaptyConfiguration(apiKey: 'YOUR_ADAPTY_PUBLIC_KEY')
        ..withLogLevel(AdaptyLogLevel.verbose),
    );

    // Set up callback for affiliate identifier changes
    insertAffiliateSdk.setInsertAffiliateIdentifierChangeCallback((identifier, offerCode) async {
      if (identifier != null && identifier.isNotEmpty) {
        await _updateAdaptyWithAffiliateId(identifier);
      }
    });

    // Check for existing affiliate identifier
    final existingId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
    if (existingId != null && existingId.isNotEmpty) {
      await _updateAdaptyWithAffiliateId(existingId);
    }
  }

  Future<void> _updateAdaptyWithAffiliateId(String affiliateId) async {
    final builder = AdaptyProfileParametersBuilder()
      ..setCustomStringAttribute(affiliateId, 'insert_affiliate');
    await Adapty().updateProfile(builder.build());
  }
}
```

**Step 3: Ensure Attribution Before Purchase**

```dart
Future<void> _makePurchase(AdaptyPaywallProduct product) async {
  // Always ensure affiliate ID is set before purchase
  final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
  if (affiliateId != null && affiliateId.isNotEmpty) {
    final builder = AdaptyProfileParametersBuilder()
      ..setCustomStringAttribute(affiliateId, 'insert_affiliate');
    await Adapty().updateProfile(builder.build());
  }

  // Now make the purchase
  final result = await Adapty().makePurchase(product: product);
  // Handle result...
}
```

**Step 4: Webhook Setup**

1. In your [Insert Affiliate dashboard](https://app.insertaffiliate.com/settings):
   - Set **In-App Purchase Verification** to `Adapty`
   - Copy the **Adapty Webhook URL**
   - Copy the **Adapty Webhook Authorization Header** value

2. In the [Adapty Dashboard](https://app.adapty.io/integrations):
   - Navigate to **Integrations** → **Webhooks**
   - Set **Production URL** to the webhook URL from Insert Affiliate
   - Set **Sandbox URL** to the same webhook URL
   - Paste the authorization header value into **Authorization header value**
   - Enable these options:
     - **Exclude historical events**
     - **Send attribution**
     - **Send trial price**
     - **Send user attributes**
   - Save the configuration

**Step 5: Verify Integration**

To confirm the affiliate identifier is set correctly:
1. Go to [app.adapty.io/profiles/users](https://app.adapty.io/profiles/users)
2. Find the test user who made a purchase
3. Look for `insert_affiliate` in **Custom attributes** with format: `{SHORT_CODE}-{UUID}`

✅ **Adapty setup complete!**

</details>

<details>
<summary><h4>Option 3: Iaptic</h4></summary>

**Step 1: Code Setup**

Complete the [In App Purchase Flutter Library](https://pub.dev/packages/in_app_purchase) setup first:

```dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

class _MyAppState extends State<MyApp> {
  final InAppPurchase _iap = InAppPurchase.instance;

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
}
```

**Step 2: Webhook Setup**

1. In [Insert Affiliate settings](https://app.insertaffiliate.com/settings):
   - Set verification method to `Iaptic`
   - Copy the `Iaptic Webhook URL` and `Iaptic Webhook Sandbox URL`
2. In [Iaptic Settings](https://www.iaptic.com/settings):
   - Paste the Webhook URLs into corresponding fields
   - Click **Save Settings**
3. Complete [Iaptic App Store Server Notifications setup](https://www.iaptic.com/documentation/setup/ios-subscription-status-url)
4. Complete [Iaptic Google Play Notifications setup](https://www.iaptic.com/documentation/setup/connect-with-google-publisher-api)

✅ **Iaptic setup complete!**

</details>

<details>
<summary><h4>Option 4: App Store Direct</h4></summary>

**Step 1:** Visit [our docs](https://docs.insertaffiliate.com/direct-store-purchase-integration#1-apple-app-store-server-notifications) and complete the App Store Server Notifications setup.

**Step 2: Implementing Purchases**

```dart
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

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
```

✅ **App Store Direct setup complete!**

</details>

<details>
<summary><h4>Option 5: Google Play Direct</h4></summary>

**Step 1:** Visit [our docs](https://docs.insertaffiliate.com/direct-google-play-store-purchase-integration) and complete the RTDN setup.

**Step 2: Implementing Purchases**

```dart
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

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
```

✅ **Google Play Direct setup complete!**

</details>

---

### 3. Set Up Deep Linking

**Deep linking lets affiliates share unique links that track users to your app.** Choose **ONE** deep linking provider:

| Provider | Best For | Complexity | Setup Guide |
|----------|----------|------------|-------------|
| [**Insert Links**](#option-1-insert-links) | Simple setup, no 3rd party | Simple | [View](#option-1-insert-links) |
| [**Branch.io**](#option-2-branchio) | Robust attribution, deferred deep linking | Medium | [View](#option-2-branchio) |
| [**AppsFlyer**](#option-3-appsflyer) | Enterprise analytics, comprehensive attribution | Medium | [View](#option-3-appsflyer) |

<details open>
<summary><h4>Option 1: Insert Links</h4></summary>

Insert Links is Insert Affiliate's built-in deep linking solution.

**Step 1:** Complete the [Insert Links setup](https://docs.insertaffiliate.com/insert-links) in the dashboard.

**Step 2: Initialize with Insert Links enabled**

```dart
insertAffiliateSdk = InsertAffiliateFlutterSDK(
  companyCode: "YOUR_COMPANY_CODE",
  verboseLogging: true,
  insertLinksEnabled: true,
  insertLinksClipboardEnabled: true,
);
```

**Step 3: Set up deep link handling with app_links**

Add to `pubspec.yaml`:
```yaml
dependencies:
  app_links: ^6.3.2
```

```dart
import 'package:app_links/app_links.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "YOUR_COMPANY_CODE",
    insertLinksEnabled: true,
    insertLinksClipboardEnabled: true,
  );

  // Set up callback for affiliate identifier changes
  insertAffiliateSdk.setInsertAffiliateIdentifierChangeCallback((identifier, offerCode) async {
    if (identifier != null) {
      // For RevenueCat:
      // var attrs = {"insert_affiliate": identifier, "insert_timedout": ""};
      // if (offerCode != null) attrs["affiliateOfferCode"] = offerCode;
      // await Purchases.setAttributes(attrs);
      // await Purchases.syncAttributesAndOfferingsIfNeeded();

      // For Adapty:
      // final builder = AdaptyProfileParametersBuilder()
      //   ..setCustomStringAttribute(identifier, 'insert_affiliate');
      // await Adapty().updateProfile(builder.build());

      // For Apphud:
      // await Apphud.setUserProperty(key: "insert_affiliate", value: identifier, setOnce: false);
    }
  });

  // Set up deep link listener
  _setupDeepLinkListener();

  runApp(MyApp());
}

void _setupDeepLinkListener() async {
  final appLinks = AppLinks();

  // Check for initial link
  final initialLink = await appLinks.getInitialLink();
  if (initialLink != null) {
    await insertAffiliateSdk.handleDeepLink(initialLink.toString());
  }

  // Listen for incoming links
  appLinks.uriLinkStream.listen((Uri uri) async {
    await insertAffiliateSdk.handleDeepLink(uri.toString());
  });
}
```

#### Universal Links (Optional, Recommended)

Universal Links provide a better user experience than custom URL schemes. When a user taps an Insert Link and already has your app installed, iOS opens the app directly — without loading the browser.

**Prerequisites:**
- Enter your **Apple Team ID** and **iOS Bundle Identifier** in the Insert Affiliate dashboard settings

**Step 1: Add Associated Domains in Xcode**

Go to your app target → **Signing & Capabilities** → **+ Capability** → **Associated Domains**.

Add:
```
applinks:insertaffiliate.link
```

If you have a custom domain (e.g. `links.yourcompany.com`), also add:
```
applinks:links.yourcompany.com
```

**Step 2: Disable Flutter's built-in deep link handling**

Add this to your `ios/Runner/Info.plist` to prevent Flutter's engine from trying to route Universal Link URLs (which causes Safari to open after the SDK handles the link):

```xml
<key>FlutterDeepLinkingEnabled</key>
<false/>
```

**Step 3: Handle Universal Links in your app**

The `app_links` package used above already handles Universal Links — both `getInitialLink()` and `uriLinkStream` receive Universal Link URLs. The SDK's `handleDeepLink()` method routes them to the correct handler automatically. No additional code changes needed.

> **Note:** Universal Links won't trigger if you type the URL directly into Safari's address bar — tap it from **Notes or Messages** for a real test.

**Testing Universal Links:**

```bash
# iOS Simulator
xcrun simctl openurl booted "https://insertaffiliate.link/YOUR_COMPANY_CODE/TEST_SHORT_CODE"

# Real device (get UDID from: xcrun devicectl list devices)
xcrun devicectl device process launch -d YOUR_DEVICE_UDID com.apple.mobilesafari "https://insertaffiliate.link/YOUR_COMPANY_CODE/TEST_SHORT_CODE"
```

#### Android App Links (Optional, Recommended)

Android App Links provide a better user experience than custom URL schemes. When a user taps an Insert Link and already has your app installed, Android opens the app directly — without loading the browser or showing a disambiguation dialog.

**Prerequisites:**
- Enter your **Android Bundle Identifier** (package name) and **SHA-256 Certificate Fingerprints** in the Insert Affiliate dashboard settings

**Step 1: Add intent filter to AndroidManifest.xml**

Add this inside your main `<activity>` tag in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="insertaffiliate.link" />
</intent-filter>
```

If you have a custom domain, add another intent filter with your domain.

**Step 2: Set launch mode**

Add `android:launchMode="singleTop"` to your main activity to prevent it being recreated when an App Link is tapped:

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop"
    ...>
```

> No additional code changes needed — the `app_links` package already receives App Link URLs and the SDK routes them to the correct handler automatically.

✅ **Insert Links setup complete!**

</details>

<details>
<summary><h4>Option 2: Branch.io</h4></summary>

**Key Integration Steps:**
1. Install and configure [Flutter Branch SDK](https://pub.dev/packages/flutter_branch_sdk)
2. Listen for Branch deep link events with `FlutterBranchSdk.listSession()`
3. Extract `~referring_link` from Branch callback
4. Pass to Insert Affiliate SDK using `setInsertAffiliateIdentifier()`

```dart
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

_branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) {
  if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
    insertAffiliateSdk.setInsertAffiliateIdentifier(data["~referring_link"]);

    // For RevenueCat: Update attributes
    insertAffiliateSdk.returnInsertAffiliateIdentifier().then((value) async {
      if (value != null) {
        await Purchases.setAttributes({"insert_affiliate": value});
        await Purchases.syncAttributesAndOfferingsIfNeeded();
      }
    });
  }
});
```

📖 **[View complete Branch.io integration guide →](docs/deep-linking-branch.md)**

</details>

<details>
<summary><h4>Option 3: AppsFlyer</h4></summary>

**Key Integration Steps:**
1. Install and configure [AppsFlyer Flutter SDK](https://pub.dev/packages/appsflyer_sdk)
2. Listen for `onDeepLinking` and `onInstallConversionData` callbacks
3. Pass deep link value to Insert Affiliate SDK using `setInsertAffiliateIdentifier()`

```dart
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

_appsflyerSdk.onDeepLinking((deepLinkResult) async {
  if (deepLinkResult.status == Status.FOUND) {
    final deepLinkValue = deepLinkResult.deepLink?.deepLinkValue;
    if (deepLinkValue != null) {
      await insertAffiliateSdk.setInsertAffiliateIdentifier(deepLinkValue);

      // For RevenueCat: Update attributes
      final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
      if (affiliateId != null) {
        await Purchases.setAttributes({"insert_affiliate": affiliateId});
        await Purchases.syncAttributesAndOfferingsIfNeeded();
      }
    }
  }
});
```

📖 **[View complete AppsFlyer integration guide →](docs/deep-linking-appsflyer.md)**

</details>

---

## ✅ Verify Your Integration

### Integration Checklist

- [ ] **SDK Initializes**: Check console for `SDK initialized with company code` log
- [ ] **Affiliate Identifier Stored**: Click a test affiliate link and verify identifier is stored
- [ ] **Purchase Tracked**: Make a test purchase and verify it appears in Insert Affiliate dashboard

### Testing Commands

```bash
# Test deep link (Android Emulator)
adb shell am start -W -a android.intent.action.VIEW -d "https://your-deep-link-url/abc123"

# Test deep link (iOS Simulator)
xcrun simctl openurl booted "https://your-deep-link-url/abc123"
```

### Check Stored Affiliate Identifier

```dart
final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
print('Current affiliate ID: $affiliateId');
```

### Common Setup Issues

| Issue | Solution |
|-------|----------|
| "Company code is not set" | Ensure SDK is initialized before calling other methods |
| "No affiliate identifier found" | User must click an affiliate link before making a purchase |
| Deep link opens browser instead of app | Verify URL schemes in Info.plist (iOS) and AndroidManifest.xml (Android) |
| Purchase not tracked | Check webhook configuration in IAP verification platform |

---

## 🔧 Advanced Features

<details>
<summary><h3>Event Tracking (Beta)</h3></summary>

Track custom events beyond purchases to incentivize affiliates for specific actions.

```dart
ElevatedButton(
  onPressed: () {
    insertAffiliateSdk.trackEvent(eventName: "user_signup")
      .then((_) => print('Event tracked successfully!'))
      .catchError((error) => print('Error: $error'));
  },
  child: Text("Track Signup"),
);
```

**Use Cases:**
- Pay affiliates for signups instead of purchases
- Track trial starts, content unlocks, or other conversions

</details>

<details>
<summary><h3>Short Codes</h3></summary>

Short codes are unique, 3-25 character alphanumeric identifiers that affiliates can share.

**Validate and Store Short Code:**

```dart
final isValid = await insertAffiliateSdk.setShortCode('SAVE20');

if (isValid) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Success'),
      content: Text('Affiliate code applied!'),
    ),
  );
} else {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Error'),
      content: Text('Invalid affiliate code'),
    ),
  );
}
```

**Get Affiliate Details Without Setting:**

```dart
final details = await insertAffiliateSdk.getAffiliateDetails('SAVE20');

if (details != null) {
  print('Affiliate Name: ${details.affiliateName}');
  print('Short Code: ${details.affiliateShortCode}');
  print('Deep Link: ${details.deeplinkUrl}');
}
```

Learn more: [Short Codes Documentation](https://docs.insertaffiliate.com/short-codes)

</details>

<details>
<summary><h3>Dynamic Offer Codes / Discounts</h3></summary>

Automatically apply discounts or trials when users come from specific affiliates.

**How It Works:**
1. Configure an offer code modifier in your dashboard (e.g., `oneWeekFree`)
2. SDK automatically fetches and stores the modifier when affiliate identifier is set
3. The `affiliateOfferCode` attribute is set in RevenueCat for targeting

#### Option 1: RevenueCat Targeting (Recommended)

Use RevenueCat's targeting feature to automatically show different offerings based on the `affiliateOfferCode` attribute. No manual product ID construction needed.

**Step 1:** Create offerings in RevenueCat (e.g., `default` and `oneWeekFree`)

**Step 2:** Configure targeting rules in RevenueCat:
- Condition: `affiliateOfferCode` is any of `oneWeekFree`
- Show Offering: Select your promotional offering

**Step 3:** Just use `offerings.current` in your app:

```dart
final offerings = await Purchases.getOfferings();
final packages = offerings.current?.availablePackages ?? [];
// RevenueCat targeting automatically shows the right offering!
```

#### Option 2: Manual Product ID Construction (Alternative)

If not using RevenueCat targeting, you can manually construct product IDs:

```dart
String? offerCode = await insertAffiliateSdk.getStoredOfferCode();

final baseProductId = "oneMonthSubscription";
final dynamicProductId = offerCode != null
    ? '${baseProductId}_$offerCode'  // e.g., "oneMonthSubscription_oneWeekFree"
    : baseProductId;
```

📖 **[View complete Dynamic Offer Codes guide →](docs/dynamic-offer-codes.md)**

</details>

<details>
<summary><h3>Attribution Timeout Control</h3></summary>

Control how long affiliate attribution remains active.

**Set Timeout During Initialization:**

```dart
insertAffiliateSdk = InsertAffiliateFlutterSDK(
  companyCode: "YOUR_COMPANY_CODE",
  attributionTimeout: 604800, // 7 days in seconds
);
```

**Runtime Updates:**

```dart
// Set 7-day timeout
await insertAffiliateSdk.setAffiliateAttributionTimeout(604800);

// Disable timeout (never expires)
await insertAffiliateSdk.setAffiliateAttributionTimeout(0);

// Check if attribution is still valid
final isValid = await insertAffiliateSdk.isAffiliateAttributionValid();

// Get when attribution was stored
final storedDate = await insertAffiliateSdk.getAffiliateStoredDate();
```

**Common Timeout Values:**
- 1 day: `86400`
- 7 days: `604800` (recommended)
- 30 days: `2592000`
- No timeout: `0` (default)

**Bypass Timeout for Testing:**

```dart
// Get identifier even if attribution has expired
final identifier = await insertAffiliateSdk.returnInsertAffiliateIdentifier(ignoreTimeout: true);
```

</details>

<details>
<summary><h3>Affiliate Change Callback</h3></summary>

Get notified when the affiliate identifier changes. The callback now includes both the identifier and the offer code:

```dart
insertAffiliateSdk.setInsertAffiliateIdentifierChangeCallback((identifier, offerCode) async {
  if (identifier != null) {
    print('Affiliate changed: $identifier, offer code: $offerCode');

    // Update your IAP platform with both identifier and offer code
    var attributes = {"insert_affiliate": identifier, "insert_timedout": ""};
    if (offerCode != null) {
      attributes["affiliateOfferCode"] = offerCode;
    }
    await Purchases.setAttributes(attributes);
    await Purchases.syncAttributesAndOfferingsIfNeeded();
  }
});
```

</details>

### Prevent Affiliate Transfer

Protect the original affiliate from being overwritten by subsequent affiliate links:

```dart
insertAffiliateSdk = InsertAffiliateFlutterSDK(
  companyCode: "YOUR_COMPANY_CODE",
  preventAffiliateTransfer: true,  // Protect original affiliate
);
```

When enabled, if a user already has an affiliate identifier stored, any new affiliate links will be blocked. This ensures the original affiliate who referred the user gets credit for any future purchases.

Learn more: [Prevent Affiliate Transfer Documentation](https://docs.insertaffiliate.com/prevent-affiliate-transfer)

<details>
<summary><h3>Get Affiliate Expiry Timestamp</h3></summary>

Get the Unix timestamp (in milliseconds) when the current affiliate attribution expires:

```dart
final expiryTimestamp = await insertAffiliateSdk.getAffiliateExpiryTimestamp();

if (expiryTimestamp != null) {
  final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
  print('Attribution expires at: $expiryDate');

  // Check if expired
  if (DateTime.now().millisecondsSinceEpoch > expiryTimestamp) {
    print('Attribution has expired');
  }
}
```

Returns `null` if no attribution date is stored or if timeout is disabled.

</details>

<details>
<summary><h3>In-App Referrals (Refer a Friend)</h3></summary>

Turn your own users into affiliates from inside your app. Each referrer is a normal Insert Affiliate affiliate (same dashboard, commission and payouts), and your app can read how many referrals they have made to reward them.

Switch the program on in the Insert Affiliate dashboard first. Enrolment is refused while it is off.

**Drop-in screen:**

```dart
await insertAffiliateSdk.showReferAFriend(
  context,
  options: ReferAFriendOptions(
    email: currentUser.email, // prefill with your logged-in user
    name: currentUser.name,
    appUserId: revenueCatAppUserId, // optional, for automatic rewards (see below)
    shareMessage: 'Get a free week of MyApp: {link}', // optional, supports {link} and {code}
    primaryColor: Colors.teal,  // optional, overrides the dashboard colour
    headline: 'Invite friends', // optional, overrides the dashboard copy
    rewardText: 'Earn a free week for every friend who subscribes.',
    onClose: () => refreshRewards(),
  ),
);
```

The screen handles every step: loading, the "Get my link" form, the 6-digit email code when the email is already an affiliate, and the enrolled view with the code, link, Copy and Share buttons, referral count, amount earned and an "Open my dashboard" link. When the referrer has been granted rewards it also shows "Free premium until {date}" (while that date is in the future) a "Your rewards" list of the codes this phone can redeem, each with a Redeem button: App Store offer codes on iOS, Google Play promo codes on Android. You can also push or embed `ReferAFriendScreen(sdk: insertAffiliateSdk, options: ...)` yourself.

Headline, reward text and colour come from your options first, then your dashboard settings, then the defaults ("Refer a friend", `#6A0DAD`), so you can change the wording without an app release. `fontFamily` and `cornerRadius` are also available.

**Headless methods (build your own UI):**

```dart
// Make the user a referrer. appUserId and playPurchaseToken are optional (see Automatic rewards below).
final result = await insertAffiliateSdk.createAffiliateForUser(
  'jane@example.com',
  'Jane',
  appUserId: revenueCatAppUserId,
);

switch (result.status) {
  case AffiliateEnrolmentStatus.created:
    print('Share this: ${result.affiliate?.deeplinkUrl}');
    break;
  case AffiliateEnrolmentStatus.verificationRequired:
    // The email is already an affiliate. We emailed them a 6-digit code.
    final verified = await insertAffiliateSdk.verifyAffiliateCode('jane@example.com', codeFromUser);
    break;
  case AffiliateEnrolmentStatus.error:
    print('${result.errorCode}: ${result.errorMessage}');
    break;
  default:
    break;
}

// Referral stats (null when this device is not connected)
final me = await insertAffiliateSdk.getMyAffiliateDetails();
if (me != null) {
  print('${me.referralCount} referrals, earned ${me.totalEarned} ${me.currency}');
  print('${me.rewardsGranted} rewards, premium until ${me.premiumUntil}');
  for (final reward in me.rewardCodes) {
    print('${reward.store} ${reward.code}: ${reward.redeemUrl}'); // newest first
  }
}

// The user subscribed or logged in after joining: save their account so waiting rewards are granted
await insertAffiliateSdk.setReferrerAccount(appUserId: revenueCatAppUserId);

final isReferrer = await insertAffiliateSdk.isUserAnAffiliate(); // local check, no network
final config = await insertAffiliateSdk.getReferralProgramConfig(); // dashboard settings
await insertAffiliateSdk.shareReferralLink(message: 'Join me on MyApp: {link}'); // system share sheet
await insertAffiliateSdk.signOutAffiliate(); // call when your user logs out
```

| Method | Returns |
|---|---|
| `createAffiliateForUser(email, name, {appUserId, playPurchaseToken})` | `AffiliateEnrolmentResult` with status `created`, `verificationRequired` or `error` |
| `verifyAffiliateCode(email, code, {name, appUserId, playPurchaseToken})` | `AffiliateEnrolmentResult` with status `connected`, `created` or `error` |
| `setReferrerAccount({appUserId, playPurchaseToken})` | `bool`, false when not connected or the request fails |
| `getMyAffiliateDetails()` | `MyAffiliateDetails?`: name, short code, link, `referralCount`, `installCount`, `eventCount`, `purchaseCount`, `totalEarned`, `totalPaid`, `totalUnpaid`, `currency`, `dashboardUrl`, `rewardsGranted`, `premiumUntil` (`DateTime?`), `rewardCodes` (`List<ReferralRewardCode>` with `code`, `redeemUrl`, `store` (`'app_store'` or `'google_play'`), `isAppStore`, `isGooglePlay`, `grantedAt`) |
| `isUserAnAffiliate()` | `bool` |
| `signOutAffiliate()` | clears this device's referrer connection |
| `getReferralProgramConfig()` | `ReferralProgramConfig?`: `enabled`, `companyName`, `referralTrigger`, `headline`, `rewardText`, `primaryColor` |
| `shareReferralLink({message, sharePositionOrigin})` | `bool`, false when not connected |
| `showReferAFriend(context, {options})` | shows the drop-in screen |

Error codes: `PROGRAM_DISABLED`, `AFFILIATE_LIMIT_REACHED`, `INVALID_EMAIL`, `INVALID_CODE`, `TOO_MANY_CODES`, `RATE_LIMITED`, `NETWORK_ERROR`.

`referralCount` is the count for what your dashboard counts as a referral (install, a tracked event, or a purchase). It only goes up, so you can compare it with what you have already rewarded and grant the difference.

**How the device stays connected:** enrolling stores a private token for your company code in the SDK's app storage (the token is never logged). If the app is deleted, or the user moves to a new phone, calling `createAffiliateForUser` again with the same email sends them a code to reconnect. Their affiliate account and earnings are untouched.

**Rewarding referrers:** values on the device are for display. A modified device can fake them, so grant anything of real value (credits, premium time) from your server using the `referral.created` webhook or the Public API. For free premium time, use Apple/Google offer codes or RevenueCat promotional entitlements.

**Automatic rewards:** when referrer rewards are set up in the dashboard (RevenueCat, Adapty, App Store offer codes or Google Play), Insert Affiliate grants them for you. To know who to reward, pass the referrer's `appUserId` (RevenueCat app user id or Adapty customer user id) and/or `playPurchaseToken` (their own Google Play subscription purchase token) to `createAffiliateForUser` / `verifyAffiliateCode`. The drop-in screen takes the same values as `appUserId` / `playPurchaseToken` options: it sends them when the user enrols, and calls `setReferrerAccount` for you when it opens for a user who is already enrolled. If the user subscribes or logs in later, call `setReferrerAccount` then; any rewards that were waiting are granted. The SDK also sends its device id so a user cannot refer themselves. Reward codes appear in `rewardCodes`. Each has a `store`: `'app_store'` for an App Store offer code (iOS only) or `'google_play'` for a Google Play promo code (Android only, `redeemUrl` is `https://play.google.com/redeem?code=...`). Codes from older servers have no store and are read as `'app_store'`. The drop-in screen lists only the codes the phone can redeem; `rewardCodesForPlatform(codes, platform: defaultTargetPlatform, isWeb: kIsWeb)` does the same filtering for your own UI.

**Store rules:** the SDK uses the system share sheet only and never reads Contacts. Never gate app features behind sharing, and never reward ratings or reviews.

This feature adds the [`share_plus`](https://pub.dev/packages/share_plus) dependency for the system share sheet.

</details>

---

## 🔍 Troubleshooting

### Initialization Issues

**Error:** "Company code is not set"
- **Cause:** SDK not initialized or method called before initialization
- **Solution:** Initialize SDK in `main()` before `runApp()`

### Deep Linking Issues

**Problem:** Deep link opens browser instead of app
- **Cause:** Missing or incorrect URL scheme configuration
- **Solution:**
  - iOS: Add URL scheme to Info.plist and configure associated domains
  - Android: Add intent filters to AndroidManifest.xml

**Problem:** "No affiliate identifier found"
- **Cause:** User hasn't clicked an affiliate link yet
- **Solution:** Test with simulator/emulator using `adb shell` or `xcrun simctl openurl`

### Purchase Tracking Issues

**Problem:** Purchases not appearing in dashboard
- **Cause:** Webhook not configured or affiliate identifier not passed to IAP platform
- **Solution:**
  - Verify webhook URL and authorization headers
  - For RevenueCat: Confirm `insert_affiliate` attribute is set before purchase
  - Enable verbose logging and check console for errors

### Verbose Logging

Enable detailed logs during development:

```dart
insertAffiliateSdk = InsertAffiliateFlutterSDK(
  companyCode: "YOUR_COMPANY_CODE",
  verboseLogging: true,
);
```

---

## 📚 Support

- **Documentation**: [docs.insertaffiliate.com](https://docs.insertaffiliate.com)
- **Branch.io Guide**: [docs/deep-linking-branch.md](docs/deep-linking-branch.md)
- **AppsFlyer Guide**: [docs/deep-linking-appsflyer.md](docs/deep-linking-appsflyer.md)
- **Offer Codes Guide**: [docs/dynamic-offer-codes.md](docs/dynamic-offer-codes.md)
- **Dashboard**: [app.insertaffiliate.com](https://app.insertaffiliate.com)
- **Issues**: [GitHub Issues](https://github.com/Insert-Affiliate/insert_affiliate_flutter_sdk/issues)

---

**Need help?** Check our [documentation](https://docs.insertaffiliate.com) or [contact support](https://app.insertaffiliate.com/help).
