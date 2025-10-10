# Insert Affiliate Flutter SDK

## Overview

The **Insert Affiliate Flutter SDK** is designed for Flutter applications, providing seamless integration with the [Insert Affiliate platform](https://insertaffiliate.com). The Insert Affiliate Flutter SDK simplifies affiliate marketing for iOS apps with in-app-purchases, allowing developers to create a seamless user experience for affiliate tracking and monetisation.

### Features

- **Unique Device ID**: Creates a unique ID to anonymously associate purchases with users for tracking purposes.
- **Affiliate Identifier Management**: Set and retrieve the affiliate identifier based on user-specific links.
- **In-App Purchase (IAP) Initialisation**: Easily reinitialise in-app purchases with the option to validate using an affiliate identifier.

## Getting Started
To get started with the Insert Affiliate Flutter SDK:

1. [Install the SDK via pubspec.yaml](#installation)
2. [Initialise the SDK in your Main Dart File](#basic-usage)
3. [Set up in-app purchases (Required)](#in-app-purchase-setup-required)
4. [Set up deep linking (Required)](#deep-link-setup-required)
5. [Use additional features like event tracking based on your app's requirements.](#additional-features)


## Installation

Include the following dependencies in your pubspec.yaml file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  insert_affiliate_flutter_sdk: <latest_version>
  shared_preferences: <latest_version>
  http: <latest_version>
```

Run ```$ flutter pub get``` in your terminal from the project root to fetch the required packages.


## Basic Usage
### Import the SDKs

Import the SDK in your Main Dart file:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';
```

### Initialisation in Main.dart
To ensure proper initialisation of the **Insert Affiliate Flutter SDK**, you should initialise the InsertAffiliateFlutterSDK early in your app's lifecycle, typically within `Main.dart`.


```dart
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
    // Ensure Flutter is initialized before running any async code
    WidgetsFlutterBinding.ensureInitialized();

    // Important: Your Deep Linking Platform (i.e. Branch.io) and receipt verification platform if using a third party like RevenueCat / Iaptic, must be initialised before the Insert Affiliate SDK.

    // Initialise Insert Affiliate SDK
    insertAffiliateSdk = InsertAffiliateFlutterSDK(
        companyCode: "{{ your_company_code }}",
    ); 

    runApp(MyApp());
}
```
- Replace `{{ your_company_code }}` with the unique company code associated with your Insert Affiliate account. You can find this code in your dashboard under [Settings](http://app.insertaffiliate.com/settings).

### Verbose Logging (Optional)

For debugging and troubleshooting, you can enable verbose logging to get detailed insights into the SDK's operations:

```dart
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialise Insert Affiliate SDK with verbose logging enabled
    insertAffiliateSdk = InsertAffiliateFlutterSDK(
        companyCode: "{{ your_company_code }}",
        verboseLogging: true,  // Enable detailed debugging logs
    ); 

    runApp(MyApp());
}
```

**When verbose logging is enabled, you'll see detailed logs with the `[Insert Affiliate] [VERBOSE]` prefix that show debugging logs**
This can be used to quickly identify configuration or setup issues

⚠️ **Important**: Disable verbose logging in production builds to avoid exposing sensitive debugging information and to optimize performance.

### Insert Link and Clipboard Control (BETA)
We are currently beta testing our in-house deep linking provider, Insert Links, which generates links for use with your affiliates.

For larger projects where accuracy is critical, we recommend using established third-party deep linking platforms to generate the links you use within Insert Affiliate - such as Appsflyer or Branch.io, as described in the rest of this README.

If you encounter any issues while using Insert Links, please raise an issue on this GitHub repository or contact us directly at michael@insertaffiliate.com


#### Insert Link Initialization

```dart
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialise Insert Affiliate SDK with deep link support
    insertAffiliateSdk = InsertAffiliateFlutterSDK(
        companyCode: "{{ your_company_code }}",
        verboseLogging: true,  // Enable detailed debugging logs
        insertLinksEnabled: true,  // Enable deep link processing
        insertLinksClipboardEnabled: true, // Enable clipboard access for improved attribution (triggers permission prompt)
        attributionTimeout: 2592000, // Set attribution timeout to 30 days in seconds (0 = disabled, default)
    ); 

    runApp(MyApp());
}
```

**When to use `insertLinksEnabled`:**
- Set to `true` (default: `false`) if you are using Insert Affiliate's built-in deep link and universal link handling (Insert Links)
- Set to `false` if you are using an external provider for deep links

**When to use `insertLinksClipboardEnabled`:**
- Set to `true` (default: `false`) if you are using Insert Affiliate's built-in deep links (Insert Links) **and** would like to improve the effectiveness of our deep links through the clipboard
- **Important caveat**: This will trigger a system prompt asking the user for permission to access the clipboard when the SDK initializes


## In-App Purchase Setup [Required]
Insert Affiliate requires a Receipt Verification platform to validate in-app purchases. You must choose **one** of our supported partners:
- [RevenueCat](https://www.revenuecat.com/)
- [Iaptic](https://www.iaptic.com/account)
- [App Store Direct Integration](#option-3-app-store-direct-integration)
- [Google Play Store Direct Integration](#option-4-google-play-store-direct-integration)

### Option 1: RevenueCat Integration

#### Code Setup
1. **Install RevenueCat SDK** - First, follow the [RevenueCat SDK installation](https://www.revenuecat.com/docs/getting-started/installation/flutter) to set up in-app purchases and subscriptions.

2. **Modify Initialisation Code** - Update the file where you initialise your deep linking (e.g., Branch.io) and RevenueCat to include a call to ```insertAffiliateSdk.returnInsertAffiliateIdentifier()```. This ensures that the Insert Affiliate identifier is passed to RevenueCat every time the app starts or a deep link is clicked.

3. **Implementation Example**

```dart
import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

class _MyAppState extends State<MyApp> {
    @override
    void initState() {
        super.initState();
        _initializeAsyncDependencies();
    }
    
    
    Future<void> _initializeAsyncDependencies() async {
        // Step 1: Initialize RevenueCat
        await _initializeRevenueCat();
        
        // Step 2: Handle initial affiliate identifier
        handleAffiliateIdentifier();
        
        // Step 3: Listen for deep links (Branch.io example)
        _branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) {
            if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
                final referringLink = data["~referring_link"];
                insertAffiliateSdk.setInsertAffiliateIdentifier(referringLink);
                
                // Handle affiliate identifier after deep link click
                handleAffiliateIdentifier();
            }
        }, onError: (error) {
            print('listSession error: ${error.toString()}');
        });
    }
    
    void handleAffiliateIdentifier() {
        insertAffiliateSdk.returnInsertAffiliateIdentifier().then((value) {
            if (value != null && value.isNotEmpty) {
                Purchases.setAttributes({"insert_affiliate" : value});
            }
        });
    }
}

```

#### Webhook Setup

Next, you must setup a webhook to allow us to communicate directly with RevenueCat to track affiliate purchases.

1. Go to RevenueCat and [create a new webhook](https://www.revenuecat.com/docs/integrations/webhooks)

2. Configure the webhook with these settings:
   - Webhook URL: `https://api.insertaffiliate.com/v1/api/revenuecat-webhook`
   - Authorization header: Use the value from your Insert Affiliate dashboard (you'll get this in step 4)
   - Set "Event Type" to "All events"

3. In your [Insert Affiliate dashboard settings](https://app.insertaffiliate.com/settings):
   - Navigate to the verification settings
   - Set the in-app purchase verification method to `RevenueCat`

4. Back in your Insert Affiliate dashboard:
   - Locate the `RevenueCat Webhook Authentication Header` value
   - Copy this value
   - Paste it as the Authorization header value in your RevenueCat webhook configuration

### Option 2: Iaptic Integration
#### 1. Code Setup
First, complete the [In App Purchase Flutter Library](https://pub.dev/packages/in_app_purchase) setup. Then modify your ```main.dart``` file:


```dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

class _MyAppState extends State<MyApp> {
    final InAppPurchase _iap = InAppPurchase.instance;
  
    @override
    void initState() {
        super.initState();
        _purchaseStream.listen((List<PurchaseDetails> purchaseDetailsList) {
          _listenToPurchaseUpdated(purchaseDetailsList);
        });
    }
    
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
                
                final isValid = await insertAffiliateSdk.validatePurchaseWithIapticAPI(
                    jsonIapPurchase,
                    "{{ your_iaptic_app_id }}",
                    "{{ your_iaptic_app_name }}",
                    "{{ your_iaptic_public_key }}"
                );
            
                // Optional: Handle the result of `isValid` if needed
            }
        }
    }
}
```

Replace the following:
- `{{ your_iaptic_app_id }}` with your [Iaptic App ID](https://www.iaptic.com/account)
- `{{ your_iaptic_app_name }}` with your [Iaptic App Name](https://www.iaptic.com/account)
- `{{ your_iaptic_public_key }}` with your [Iaptic Public Key](https://www.iaptic.com/settings)

#### 2. Webhook Setup

1. Open the [Insert Affiliate settings](https://app.insertaffiliate.com/settings):
  - Navigate to the Verification Settings section
  - Set the In-App Purchase Verification method to `Iaptic`
  - Copy the `Iaptic Webhook URL` and the `Iaptic Webhook Sandbox URL`- you'll need it in the next step.
2. Go to the [Iaptic Settings](https://www.iaptic.com/settings)
- Paste the copied `Iaptic Webhook URL` into the `Webhook URL` field
- Paste the copied `Iaptic Webhook Sandbox URL` into the `Sandbox Webhook URL` field
- Click **Save Settings**.
3. Check that you have completed the [Iaptic setup for the App Store Server Notifications](https://www.iaptic.com/documentation/setup/ios-subscription-status-url)
4. Check that you have completed the [Iaptic setup for the Google Play Notifications URL](https://www.iaptic.com/documentation/setup/connect-with-google-publisher-api)

### Option 3: App Store Direct Integration

Our direct App Store integration is currently in beta and currently supports subscriptions only. **Consumables and one-off purchases are not yet supported** due to App Store server-to-server notification limitations.

We plan to release support for consumables and one-off purchases soon. In the meantime, you can use a receipt verification platform from the other integration options.

#### Apple App Store Notification Setup
To proceed, visit [our docs](https://docs.insertaffiliate.com/direct-store-purchase-integration#1-apple-app-store-server-notifications) and complete the required setup steps to set up App Store Server to Server Notifications.

#### Implementing Purchases

##### 1. Import Required Modules  

Ensure you import the necessary dependencies, including `Platform` and `useDeepLinkIapProvider` from the SDK.  

```dart
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';
```

##### 2. Handle the Purchase
When a user taps your purchase button, retrieve the appAccountToken using the Insert Affiliate SDK (iOS only), then pass it to the PurchaseParam when initiating the subscription. This links the purchase to the user account for affiliate tracking.

```dart
void _buySubscription(ProductDetails product) async {
    String? appAccountToken;
    if (Platform.isIOS) {
        appAccountToken = await insertAffiliateSdk.returnUserAccountTokenAndStoreExpectedTransaction();
    }
    
    final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: appAccountToken, // Will be null on Android and if null if no Insert Affiliate identifier is set from the user entering a short code or clicking an affiliate's link
    );

    _iap.buyNonConsumable(purchaseParam: purchaseParam);
}
```

### Option 4: Google Play Store Direct Integration
We now support direct Google Play Store integration (currently in beta). This enables real-time purchase tracking via Google Play’s Real-Time Developer Notifications (RTDN).


#### Real Time Developer Notifications (RTDN) Setup

Visit [our docs](https://docs.insertaffiliate.com/direct-google-play-store-purchase-integration) and complete the required set up steps for Google Play's Real Time Developer Notifications.

#### Implementing Purchases

##### 1. Import Required Modules  


```dart
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';
```

##### 2. Handle the Purchase
Inside your purchase stream listener, ensure you track Android purchases by storing the purchaseToken:

```dart
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
        if (_processedPurchases.contains(purchaseDetails.purchaseID)) return;

        if (purchaseDetails.status == PurchaseStatus.purchased) {
            if (Platform.isAndroid && purchaseDetails is GooglePlayPurchaseDetails) {
                final purchaseToken = purchaseDetails.billingClientPurchase.purchaseToken;

                if (purchaseToken.isNotEmpty) {
                    await insertAffiliateSdk.storeExpectedStoreTransaction(purchaseToken);
                }
            }
            _processedPurchases.add(purchaseDetails.purchaseID ?? "");
            InAppPurchase.instance.completePurchase(purchaseDetails);
        }
    }
}  
```


## Deep Link Setup [Required]
Insert Affiliate requires a Deep Linking platform to create links for your affiliates. Our platform works with **any** deep linking provider, and you only need to follow these steps:
1. **Create a deep link** in your chosen third-party platform and pass it to our dashboard when an affiliate signs up. 
2. **Handle deep link clicks** in your app by passing the clicked link:
  ```flutter
  insertAffiliateSdk.setInsertAffiliateIdentifier(data["~referring_link"]);
  ```

### Deep Linking with Insert Links
Insert Links by Insert Affiliate supports deferred deep linking into your app. This allows you to track affiliate attribution when end users are referred to your app by clicking on one of your affiliates Insert Links.

#### Initial Setup
1. Before you can use Insert Links, you must complete the setup steps in [our docs](https://docs.insertaffiliate.com/insert-links)

2. **Initialization** of the Insert Affiliate SDK with Insert Links
You must enable *insertLinksEnabled* when [initialising our SDK](https://github.com/Insert-Affiliate/insert_affiliate_flutter_sdk?tab=readme-ov-file#insert-link-initialization)

3. **Handle Insert Links** in your Flutter App
The SDK provides a single `handleInsertLinks` method that automatically detects and handles different URL types. 

#### Flutter App Integration

For Flutter apps, you can handle Insert Links using the `app_links` package, which properly handles deep links when the app returns from background. This is the recommended approach for reliable deep link handling.

##### Example Using app_links (Recommended for Deep Link Handling)

**1. Add app_links dependency to pubspec.yaml:**

```yaml
dependencies:
  app_links: ^6.3.2  # Add this line
```

**2. Import app_links in your main.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SDK
  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "your_company_code",
    verboseLogging: true,
    insertLinksEnabled: true,
    insertLinksClipboardEnabled: true,
  );

  // Set up callback for affiliate identifier changes
  insertAffiliateSdk.setInsertAffiliateIdentifierChangeCallback((identifier) {
    if (identifier != null) {
      // *** Required if using RevenueCat *** //
      // Purchases.setAttributes({"insert_affiliate": identifier});
      // *** End of RevenueCat section *** //

      // *** Required if using Apphud *** //
      // Apphud.setUserProperty(key: "insert_affiliate", value: identifier, setOnce: false);
      // *** End of Apphud Section *** //

      // *** Required only if you're using Iaptic ** //
      // InAppPurchase.initialize(
      //   iapProducts: iapProductsArray,
      //   validatorUrlString: "https://validator.iaptic.com/v3/validate?appName={{ your_iaptic_app_name }}&apiKey={{ your_iaptic_app_key_goes_here }}",
      //   applicationUsername: identifier
      // );
      // *** End of Iaptic Section ** //
    }
  });

  // CRITICAL: Set up deep link listener for background returns
  _setupDeepLinkListener();

  runApp(MyApp());
}

void _setupDeepLinkListener() {
  final appLinks = AppLinks();

  // Listen for incoming links when app returns from background
  appLinks.uriLinkStream.listen((Uri uri) {
    print('Deep link received: $uri');
    await insertAffiliateSdk.handleDeepLink(uri.toString());
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insert Affiliate App',
      home: HomePage(),
    );
  }
}

```

**Debugging Deep Links:** Enable [verbose logging](#verbose-logging-optional) during development to see visual confirmation when deep links are processed successfully. This shows detailed logs with the extracted user code, affiliate email, and company information.

#### Retrieving Affiliate Information
After handling a deep link, you can retrieve the affiliate information:

```dart
// Get the affiliate identifier
final affiliateIdentifier = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
if (affiliateIdentifier != null) {
  print('Affiliate ID: $affiliateIdentifier');
}
```


### Deep Linking with Branch.io
To set up deep linking with Branch.io, follow these steps:

1. Create a deep link in Branch and pass it to our dashboard when an affiliate signs up.
    - Example: [Create Affiliate](https://docs.insertaffiliate.com/create-affiliate).
2. Modify Your Deep Link Handling in `Main.dart`
    - After setting up your Branch integration, add the following code to initialise the Insert Affiliate SDK in your iOS app:

#### Modify Your Deep Link listSession Listener function in `Main.dart`


```dart
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;

class _MyAppState extends State<MyApp> {
    
    late StreamSubscription<Map> _branchStreamSubscription;
    
    @override
    void initState() {
        super.initState();
        
        _branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) {
            if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
                insertAffiliateSdk.setInsertAffiliateIdentifier(data["~referring_link"]);
            }
        }, onError: (error) {
            print('Branch session error: ${error.toString()}');
        });
     }
}
```

### Using the SDK with AppsFlyer (Flutter)

To set up deep linking with AppsFlyer, follow these steps:

1. Create a [OneLink](https://support.appsflyer.com/hc/en-us/articles/208874366-Create-a-OneLink-link-for-your-campaigns) in AppsFlyer and pass it to our dashboard when an affiliate signs up.
   - Example: [Create Affiliate](https://docs.insertaffiliate.com/create-affiliate).
2. Initialize AppsFlyer SDK and set up deep link handling in your app.

#### Prerequisites

- AppsFlyer Dev Key from your AppsFlyer dashboard
- iOS App ID and Android package name configured in AppsFlyer

#### Install & Configure Dependencies

1. **Add AppsFlyer SDK** to your `pubspec.yaml`:

```yaml
dependencies:
  insert_affiliate_flutter_sdk: <latest_version>
  appsflyer_sdk: ^6.14.4
```

2. **Configure manifest** for OneLink deep linking in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Add these permissions at the top of the AndroidManifest.xml file -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="com.android.vending.INSTALL_REFERRER" />

<activity android:name=".MainActivity" android:exported="true">
    <!-- OneLink deep linking -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="{{ONELINK_SUBDOMAIN}}.onelink.me" />
    </intent-filter>
</activity>
<!-- Add AppsFlyer metadata -->
<application>
    <meta-data android:name="com.appsflyer.ApiKey" android:value="{{APPSFLYER_DEV_KEY}}" />
</application>
```

3. **Configure iOS** in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>{{SCHEME}}</string></array>
    </dict>
</array>
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:{{ONELINK_SUBDOMAIN}}.onelink.me</string>
</array>
<!-- Add this permission for clipboard access (required for insertLinksClipboardEnabled) -->
<key>NSPasteboardGeneralUseDescription</key>
<string>This app needs clipboard access to detect affiliate links</string>
```

#### Initialize AppsFlyer and the SDK

```dart
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

late final InsertAffiliateFlutterSDK insertAffiliateSdk;
late AppsflyerSdk _appsflyerSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AppsFlyer SDK
  final AppsFlyerOptions appsFlyerOptions = AppsFlyerOptions(
    afDevKey: "{{APPSFLYER_DEV_KEY}}",
    appId: "{{AF_APP_ID}}", // iOS App ID
    showDebug: true,
  );

  _appsflyerSdk = AppsflyerSdk(appsFlyerOptions);

  // Initialize Insert Affiliate SDK
  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "{{ your_company_code }}",
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
          
          // For RevenueCat: Set attributes
          final affiliateId = await insertAffiliateSdk.returnInsertAffiliateIdentifier();
          if (affiliateId != null) {
            Purchases.setAttributes({"insert_affiliate": affiliateId});
          }
        }
      }
    });

    // Handle install conversion data
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
}
```

#### In-App Purchase Integration

For **iOS App Store Direct**: The SDK automatically handles app account tokens during purchase.

For **Google Play Direct**, add purchase token tracking:

```dart
// In your purchase stream listener
if (Platform.isAndroid && purchaseDetails is GooglePlayPurchaseDetails) {
  final purchaseToken = purchaseDetails.billingClientPurchase.purchaseToken;
  await insertAffiliateSdk.storeExpectedStoreTransaction(purchaseToken);
}
```

#### Verifying the Integration

**Test deep link:**
```bash
# Android
adb shell am start -a android.intent.action.VIEW -d "https://{{ONELINK_SUBDOMAIN}}.onelink.me/{{LINK_ID}}/test"

# iOS (Simulator)
xcrun simctl openurl booted "https://{{ONELINK_SUBDOMAIN}}.onelink.me/{{LINK_ID}}/test"
```

**Check logs:**
```bash
flutter logs | grep -E "(AppsFlyer|Insert Affiliate)"
```

#### Troubleshooting

- **App opens store instead of app**: Verify package name/bundle ID and certificate fingerprints in AppsFlyer OneLink settings
- **No attribution data**: Ensure AppsFlyer SDK initialization occurs before setting up callbacks
- **Deep links not working**: Check intent-filter/URL scheme configuration

| Placeholder | Example/Note |
|-------------|--------------|
| `{{APPSFLYER_DEV_KEY}}` | Your AppsFlyer Dev Key |
| `{{AF_APP_ID}}` | iOS App ID (numbers only) |
| `{{ONELINK_SUBDOMAIN}}` | e.g., yourapp (from yourapp.onelink.me) |
| `{{SCHEME}}` | Custom scheme if applicable (e.g., myapp) |
```

## Additional Features

### 1. Event Tracking (Beta)

The **InsertAffiliateFlutter SDK** now includes a beta feature for event tracking. Use event tracking to log key user actions such as signups, purchases, or referrals. This is useful for:
- Understanding user behaviour.
- Measuring the effectiveness of marketing campaigns.
- Incentivising affiliates for designated actions being taken by the end users, rather than just in app purchases (i.e. pay an affilaite for each signup).

At this stage, we cannot guarantee that this feature is fully resistant to tampering or manipulation.

#### Using `trackEvent`

To track an event, use the `trackEvent` function. Make sure to set an affiliate identifier first; otherwise, event tracking won’t work. Here’s an example:

```dart
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

ElevatedButton(
  onPressed: () {
    insertAffiliateSdk.trackEvent(eventName: "yourEventIdentifier")
      .then((_) => print('Event tracked successfully!'))
      .catchError((error) => print('Error tracking event: $error'));
  },d
  child: Text("Track Test Event"),
);
```

### 2. Short Codes (Beta)

### What are Short Codes?

Short codes are unique, 3 to 25 character alphanumeric identifiers that affiliates can use to promote products or subscriptions. These codes are ideal for influencers or partners, making them easier to share than long URLs.

**Example Use Case**: An influencer promotes a subscription with the short code "JOIN123456" within their TikTok video's description. When users enter this code within your app during sign-up or before purchase, the app tracks the subscription back to the influencer for commission payouts.

For more information, visit the [Insert Affiliate Short Codes Documentation](https://docs.insertaffiliate.com/short-codes).

```dart
late final InsertAffiliateFlutterSDK insertAffiliateSdk;

insertAffiliateSdk.setShortCode("B2SC6VRSKQ")
```

### Setting a Short Code

Use the `setShortCode` method to associate a short code with an affiliate. This is ideal for scenarios where users enter the code via an input field, pop-up, or similar UI element.

Short codes must meet the following criteria:
- Between **3 and 25 characters long**.
- Contain only **letters and numbers** (alphanumeric characters).
- Replace {{ user_entered_short_code }} with the short code the user enters through your chosen input method, i.e. an input field / pop up element


#### Example Integration
Below is an example SwiftUI implementation where users can enter a short code, which will be validated and associated with the affiliate's account:

```dart
late final InsertAffiliateFlutterSDK insertAffiliateSdk;

ElevatedButton(
    onPressed: () => insertAffiliateSdk.setShortCode("B2SC6VRSKQ"),
    child: Text("Set Short Code"),
)
```

### 3. Discounts for Users → Offer Codes / Dynamic Product IDs

The SDK allows you to apply dynamic modifiers to in-app purchases based on whether the app was installed via an affiliate. These modifiers can be used to swap the default product ID for a discounted or trial-based one - similar to applying an offer code.

#### How It Works

When a user clicks an affiliate link or enters a short code of an affiliate with a linked offer (set up in the **Insert Affiliate Dashboard**), the SDK auto-populates offer code data with a relevant modifier (e.g., `_oneWeekFree`). You can append this to your base product ID to dynamically display the correct subscription.

#### Basic Usage

##### 1. Automatic Offer Code Fetching
If an affiliate short code is stored, the SDK automatically fetches and saves the associated offer code modifier when:
- An affiliate identifier is set via `setInsertAffiliateIdentifier()`
- A short code is set via `setShortCode()`

##### 2. Access the Stored Offer Code
The offer code modifier can be retrieved using:

```dart
String? offerCode = await insertAffiliateSdk.getStoredOfferCode();
```

#### Setup Requirements

##### Insert Affiliate Dashboard Configuration
1. Go to your Insert Affiliate dashboard at [app.insertaffiliate.com/affiliates](https://app.insertaffiliate.com/affiliates)
2. Select the affiliate you want to configure
3. Click "View" to access the affiliate's settings
4. Assign an iOS IAP Modifier to the affiliate (e.g., `_oneWeekFree`, `_threeMonthsFree`)
5. Assign an Android IAP Modifier to the affiliate (e.g., `-oneweekfree`, `-threemonthsfree`)
6. Save the settings

Once configured, when users click that affiliate's links or enter their short codes, your app will automatically receive the modifier and can load the appropriate discounted product.

#### App Store Connect Configuration
1. Create both a base and a promotional product:
   - Base product: `oneMonthSubscription`
   - Promo product: `oneMonthSubscription_oneWeekFree`
2. Ensure **both** products are approved and available for sale.

#### Google Play Console Configuration
There are multiple ways you can configure your products in Google Play Console:

1. **Multiple Products Approach**: Create both a base and a promotional product:
   - Base product: `oneMonthSubscription`
   - Promo product: `oneMonthSubscription-oneweekfree`

2. **Single Product with Multiple Base Plans**: Create one product with multiple base plans, one with an offer attached

3. **Developer Triggered Offers**: Have one base product and apply the offer through developer-triggered offers

4. **Base Product with Intro Offers**: Have one base product that includes an introductory offer

Any of these approaches are suitable and work with the SDK. The important part is that your product naming follows the pattern where the offer code modifier can be appended to identify the promotional version.

**If using the Multiple Products Approach:**
- Ensure **both** products are activated and available for purchase.
- Generate a release to at least **Internal Testing** to make the products available in your current app build

**Product Naming Pattern:**
- Follow the pattern: `{baseProductId}{OfferCode}`
- Example: `oneMonthSubscription` + `_oneWeekFree` = `oneMonthSubscription_oneWeekFree`

---

#### RevenueCat Integration Example

For apps using RevenueCat, you can dynamically construct offering identifiers:

```dart
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

class PurchaseHandler extends StatefulWidget {
  @override
  _PurchaseHandlerState createState() => _PurchaseHandlerState();
}

class _PurchaseHandlerState extends State<PurchaseHandler> {
  List<Package> availablePackages = [];
  String? offerCode;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchSubscriptions();
  }

  Future<void> fetchSubscriptions() async {
    setState(() => loading = true);
    
    try {
      // Get stored offer code
      offerCode = await insertAffiliateSdk.getStoredOfferCode();
      
      final offerings = await Purchases.getOfferings();
      List<Package> packagesToUse = [];

      if (offerCode != null && offerCode!.isNotEmpty) {
        // Construct modified product IDs from base products
        final basePackages = offerings.current?.availablePackages ?? [];

        for (final basePackage in basePackages) {
          final baseProductId = basePackage.storeProduct.identifier;
          final modifiedProductId = '$baseProductId$offerCode';

          // Search all offerings for the modified product
          bool foundModified = false;
          
          for (final offering in offerings.all.values) {
            final modifiedPackage = offering.availablePackages.firstWhere(
              (pkg) => pkg.storeProduct.identifier == modifiedProductId,
              orElse: () => null,
            );

            if (modifiedPackage != null) {
              packagesToUse.add(modifiedPackage);
              foundModified = true;
              break;
            }
          }

          // Fallback to base product if no modified version
          if (!foundModified) {
            packagesToUse.add(basePackage);
          }
        }
      } else {
        packagesToUse = offerings.current?.availablePackages ?? [];
      }

      setState(() {
        availablePackages = packagesToUse;
        loading = false;
      });
    } catch (error) {
      print('Error fetching subscriptions: $error');
      setState(() => loading = false);
    }
  }

  Future<void> handlePurchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
    } catch (error) {
      print('Purchase failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (offerCode != null && offerCode!.isNotEmpty)
          Container(
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🎉 Special Offer Applied: $offerCode',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        
        if (loading)
          CircularProgressIndicator()
        else
          ...availablePackages.map((package) => 
            ElevatedButton(
              onPressed: () => handlePurchase(package),
              child: Text('Buy: ${package.storeProduct.identifier}'),
            ),
          ).toList(),
      ],
    );
  }
}
```

---

#### Native IAP Integration Example

For apps using the native `in_app_purchase` package directly:

```dart
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

class NativeIAPPurchaseView extends StatefulWidget {
  @override
  _NativeIAPPurchaseViewState createState() => _NativeIAPPurchaseViewState();
}

class _NativeIAPPurchaseViewState extends State<NativeIAPPurchaseView> {
  final InAppPurchase _iap = InAppPurchase.instance;
  List<ProductDetails> availableProducts = [];
  String? offerCode;
  bool loading = false;
  
  static const String baseProductIdentifier = "oneMonthSubscription";

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  String get dynamicProductIdentifier {
    return offerCode != null && offerCode!.isNotEmpty
        ? '$baseProductIdentifier$offerCode' // e.g., "oneMonthSubscription_oneWeekFree"
        : baseProductIdentifier;
  }

  Future<void> fetchProducts() async {
    setState(() => loading = true);
    
    try {
      // Get stored offer code
      offerCode = await insertAffiliateSdk.getStoredOfferCode();
      
      // Try to fetch the dynamic product first
      Set<String> productIds = {dynamicProductIdentifier};
      
      // Also include base product as fallback
      if (offerCode != null && offerCode!.isNotEmpty) {
        productIds.add(baseProductIdentifier);
      }
      
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }
      
      // Prioritize the dynamic product if it exists
      List<ProductDetails> sortedProducts = response.productDetails;
      if (offerCode != null && offerCode!.isNotEmpty && sortedProducts.length > 1) {
        sortedProducts.sort((a, b) => 
          a.id == dynamicProductIdentifier ? -1 : 1
        );
      }
      
      setState(() {
        availableProducts = sortedProducts;
        loading = false;
      });
      
      print('Loaded products for: ${productIds.join(', ')}');
      
    } catch (error) {
      try {
        // Fallback logic
        final ProductDetailsResponse fallbackResponse = await _iap.queryProductDetails({baseProductIdentifier});
        setState(() {
          availableProducts = fallbackResponse.productDetails;
          loading = false;
        });
      } catch (fallbackError) {
        print('Failed to fetch base products: $fallbackError');
        setState(() => loading = false);
      }
    }
  }

  Future<void> handlePurchase(String productId) async {
   // Handle purchase is unchanged from previous examples.
  }

  @override
  Widget build(BuildContext context) {
    final ProductDetails? primaryProduct = availableProducts.isNotEmpty ? availableProducts.first : null;

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Subscription',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          
          if (offerCode != null && offerCode!.isNotEmpty)
            Container(
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🎉 Special Offer Applied: $offerCode',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          if (loading)
            Center(child: CircularProgressIndicator())
          else if (primaryProduct != null) ...[
            Text(
              primaryProduct.title,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 5),
            Text(
              'Price: ${primaryProduct.price}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            SizedBox(height: 5),
            Text(
              'Product ID: ${primaryProduct.id}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
            SizedBox(height: 15),
            
            ElevatedButton(
              onPressed: loading ? null : () => handlePurchase(primaryProduct.id),
              child: Text(loading ? "Processing..." : "Subscribe Now"),
            ),
            
            if (primaryProduct.id == dynamicProductIdentifier && offerCode != null && offerCode!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '✓ Promotional pricing applied',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ),
          ] else ...[
            Text(
              'Product not found: $dynamicProductIdentifier',
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: fetchProducts,
              child: Text('Retry'),
            ),
          ],
          
          if (availableProducts.length > 1) ...[
            SizedBox(height: 20),
            Text(
              'Other Options:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ...availableProducts.skip(1).map((product) => 
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  onPressed: () => handlePurchase(product.id),
                  child: Text('${product.title} - ${product.price}'),
                ),
              ),
            ).toList(),
          ],
        ],
      ),
    );
  }
}
```

##### Key Features of Native IAP Integration:

1. **Dynamic Product Loading**: Automatically constructs product IDs using the offer code modifier
2. **Fallback Strategy**: If the promotional product isn't found, falls back to the base product
3. **Visual Feedback**: Shows users when promotional pricing is applied
4. **Error Handling**: Graceful handling when products aren't available
5. **Platform Integration**: Properly handles iOS app account tokens for affiliate tracking

#### Best Practices

1. **Product Setup**: Always create both base and promotional products in App Store Connect
2. **Naming Convention**: Use consistent naming patterns for offer code modifiers
3. **Fallback Logic**: Always implement fallback to base products if promotional ones aren't available
4. **User Experience**: Clearly indicate when special pricing is applied
5. **Testing**: Test both scenarios - with and without offer codes applied

## Attribution Timeout

The Insert Affiliate Flutter SDK now supports attribution timeout functionality, allowing you to set how long an affiliate link attribution remains active before expiring. This feature helps you control the attribution window for affiliate commissions.

### How Attribution Timeout Works

By default, affiliate attributions **never expire** (timeout is disabled). When a timeout is configured, attributions remain active for the specified number of seconds from when they were first set. After this period, the SDK will return `null` when calling `returnInsertAffiliateIdentifier()`, effectively expiring the attribution and preventing affiliate commissions for subsequent purchases.

### Configuration

#### Setting the Attribution Timeout During Initialization (Recommended)

You can configure the attribution timeout period during SDK initialization:

```dart
// Set attribution timeout to 7 days (604800 seconds)
insertAffiliateSdk = InsertAffiliateFlutterSDK(
  companyCode: "{{ your_company_code }}",
  attributionTimeout: 604800, // 7 days in seconds
);

// Set attribution timeout to 60 days (5184000 seconds)  
insertAffiliateSdk = InsertAffiliateFlutterSDK(
  companyCode: "{{ your_company_code }}",
  attributionTimeout: 5184000, // 60 days in seconds
);

// Disable attribution timeout (never expires) - this is the default
insertAffiliateSdk = InsertAffiliateFlutterSDK(
  companyCode: "{{ your_company_code }}",
  attributionTimeout: 0, // Never expires (default)
);
```

#### Runtime Attribution Timeout Updates

You can also update the attribution timeout at runtime using the `setAffiliateAttributionTimeout` method:

```dart
// Set attribution timeout to 7 days (604800 seconds)
await insertAffiliateSdk.setAffiliateAttributionTimeout(604800);

// Set attribution timeout to 60 days (5184000 seconds)
await insertAffiliateSdk.setAffiliateAttributionTimeout(5184000);

// Disable attribution timeout (never expires)
await insertAffiliateSdk.setAffiliateAttributionTimeout(0);
```

#### Getting the Current Timeout Setting

You can retrieve the current timeout setting:

```dart
final timeoutSeconds = await insertAffiliateSdk.getAffiliateAttributionTimeout();
print('Attribution expires after $timeoutSeconds seconds');
```

### Checking Attribution Validity

You can check if the current attribution is still valid:

```dart
final isValid = await insertAffiliateSdk.isAffiliateAttributionValid();
if (isValid) {
  print('Attribution is still active');
} else {
  print('Attribution has expired');
}
```

### Getting Attribution Date

You can retrieve when the attribution was first stored:

```dart
final storedDate = await insertAffiliateSdk.getAffiliateStoredDate();
if (storedDate != null) {
  print('Attribution was set on: ${storedDate.toLocal()}');
}
```

### Bypassing Timeout for Testing

When developing or testing, you may need to retrieve the affiliate identifier even if it has expired. Use the `ignoreTimeout` parameter:

```dart
// This will return the identifier even if attribution has expired
final identifier = await insertAffiliateSdk.returnInsertAffiliateIdentifier(ignoreTimeout: true);
```

### Important Notes

1. **Default Behavior**: If no timeout is explicitly set, the default is disabled (0 = never expires)
2. **Disabled Timeout**: Setting timeout to 0 or negative value disables the timeout (attribution never expires)
3. **Backward Compatibility**: Existing attributions without stored dates are considered valid for backward compatibility
4. **Attribution Reset**: Setting a new or different affiliate identifier will reset the attribution date
5. **Same Identifier**: Re-setting the same affiliate identifier will preserve the original attribution date