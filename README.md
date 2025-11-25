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
);
```

**Parameters:**
- `verboseLogging`: Shows detailed logs for debugging (disable in production)
- `insertLinksEnabled`: Set to `true` if using Insert Links, `false` if using Branch/AppsFlyer
- `insertLinksClipboardEnabled`: Enables clipboard-based attribution for Insert Links
- `attributionTimeout`: How long affiliate attribution lasts in seconds (0 = never expires)

</details>

---

### 2. Configure In-App Purchase Verification

**Insert Affiliate requires a receipt verification method to validate purchases.** Choose **ONE** of the following:

| Method | Best For | Setup Time | Complexity |
|--------|----------|------------|------------|
| [**RevenueCat**](#option-1-revenuecat-recommended) | Most developers, managed infrastructure | ~10 min | Simple |
| [**Iaptic**](#option-2-iaptic) | Custom requirements, direct control | ~15 min | Medium |
| [**App Store Direct**](#option-3-app-store-direct) | No 3rd party fees (iOS) | ~20 min | Medium |
| [**Google Play Direct**](#option-4-google-play-direct) | No 3rd party fees (Android) | ~20 min | Medium |

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

    // Handle affiliate identifier
    handleAffiliateIdentifier();
  }

  void handleAffiliateIdentifier() {
    insertAffiliateSdk.returnInsertAffiliateIdentifier().then((value) {
      if (value != null && value.isNotEmpty) {
        Purchases.setAttributes({"insert_affiliate": value});
      }
    });
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
<summary><h4>Option 2: Iaptic</h4></summary>

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
<summary><h4>Option 3: App Store Direct</h4></summary>

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
<summary><h4>Option 4: Google Play Direct</h4></summary>

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
  insertAffiliateSdk.setInsertAffiliateIdentifierChangeCallback((identifier) {
    if (identifier != null) {
      // For RevenueCat:
      // Purchases.setAttributes({"insert_affiliate": identifier});

      // For Apphud:
      // Apphud.setUserProperty(key: "insert_affiliate", value: identifier, setOnce: false);
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
    insertAffiliateSdk.returnInsertAffiliateIdentifier().then((value) {
      if (value != null) {
        Purchases.setAttributes({"insert_affiliate": value});
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
        Purchases.setAttributes({"insert_affiliate": affiliateId});
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
1. Configure an offer code modifier in your dashboard (e.g., `_oneWeekFree`)
2. SDK automatically fetches and stores the modifier when affiliate identifier is set
3. Use the modifier to construct dynamic product IDs

**Quick Example:**

```dart
String? offerCode = await insertAffiliateSdk.getStoredOfferCode();

final baseProductId = "oneMonthSubscription";
final dynamicProductId = offerCode != null
    ? '$baseProductId$offerCode'  // e.g., "oneMonthSubscription_oneWeekFree"
    : baseProductId;

// Use dynamicProductId when fetching/purchasing products
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

Get notified when the affiliate identifier changes:

```dart
insertAffiliateSdk.setInsertAffiliateIdentifierChangeCallback((identifier) {
  if (identifier != null) {
    print('Affiliate changed: $identifier');

    // Update your IAP platform
    Purchases.setAttributes({"insert_affiliate": identifier});
  }
});
```

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
