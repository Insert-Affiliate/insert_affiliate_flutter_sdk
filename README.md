# Insert Affiliate Flutter SDK

## Overview

The **Insert Affiliate Flutter SDK** is designed for Flutter applications, providing seamless integration with the [Insert Affiliate platform](https://insertaffiliate.com).The Insert Affiliate Flutter SDK simplifies affiliate marketing for iOS apps with in-app-purchases, allowing developers to create a seamless user experience for affiliate tracking and monetisation.

### Features

- **Unique Device ID**: Creates a unique ID to anonymously associate purchases with users for tracking purposes.
- **Affiliate Identifier Management**: Set and retrieve the affiliate identifier based on user-specific links.
- **In-App Purchase (IAP) Initialisation**: Easily reinitialise in-app purchases with the option to validate using an affiliate identifier.

## Getting Started
To get started with the Insert Affiliate Flutter SDK:

1. [Install the SDK via pubspec.yaml](#installation)
2. [Initialise the SDK in your Main Dart File](#basic-usage)
3. [Set up in-app purchases (Required)](#in-app-purchase-setup-required)

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

  // Initialise Insert Affiliate SDK
  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    companyCode: "{{ your_company_code }}",
  );

  runApp(MyApp());
}
```
- Replace `{{ your_company_code }}` with the unique company code associated with your Insert Affiliate account. You can find this code in your dashboard under [Settings](http://app.insertaffiliate.com/settings).


## In-App Purchase Setup [Required]
Insert Affiliate requires a Receipt Verification platform to validate in-app purchases. You must choose **one** of our supported partners:
- [RevenueCat](https://www.revenuecat.com/)
- [Iaptic](https://www.iaptic.com/account)

### Option 1: RevenueCat Integration

COMING SOON

<!--#### 1. Code Setup-->
<!--First, complete the [RevenueCat SDK installation](https://www.revenuecat.com/docs/getting-started/installation/flutter)-->

<!--#### 2. Webhook Setup-->

<!--1. Go to RevenueCat and [create a new webhook](https://www.revenuecat.com/docs/integrations/webhooks)-->

<!--2. Configure the webhook with these settings:-->
<!--   - Webhook URL: `https://api.insertaffiliate.com/v1/api/revenuecat-webhook`-->
<!--   - Authorization header: Use the value from your Insert Affiliate dashboard (you'll get this in step 4)-->

<!--3. In your [Insert Affiliate dashboard settings](https://app.insertaffiliate.com/settings):-->
<!--   - Navigate to the verification settings-->
<!--   - Set the in-app purchase verification method to `RevenueCat`-->

<!--4. Back in your Insert Affiliate dashboard:-->
<!--   - Locate the `RevenueCat Webhook Authentication Header` value-->
<!--   - Copy this value-->
<!--   - Paste it as the Authorization header value in your RevenueCat webhook configuration-->

### Option 2: Iaptic Integration
First, complete the [In App Purchase Flutter Library](https://pub.dev/packages/in_app_purchase) setup. Then modify your ```main.dart``` file:


```
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

## Deep Link Setup [Required]

### Step 1: Add the Deep Linking Platform Dependency

In this example, the deep linking functionality is implemented using [Branch.io](https://dashboard.branch.io/).

Any alternative deep linking platform can be used by passing the referring link to ```insertAffiliateSdk.setInsertAffiliateIdentifier(data["~referring_link"]);``` as in the below Branch.io example

### Step 2: Modify Your Deep Link listSession Listener function in `Main.dart`

After setting up your Branch integration, add the following code to initialise the Insert Affiliate Flutter SDK.

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
                insertAffiliateSdk.storeInsertAffiliateIdentifier(data["~referring_link"]);
            }
        }, onError: (error) {
            print('Branch session error: ${error.toString()}');
        });
    }
}

```

## Additional Features

### 1. Event Tracking (Beta)

The **InsertAffiliateFlutter SDK** now includes a beta feature for event tracking. Use event tracking to log key user actions such as signups, purchases, or referrals. This is useful for:§
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
  },
  child: Text("Track Test Event"),
);
```

### 2. Short Codes (Beta)

### What are Short Codes?

Short codes are unique, 10-character alphanumeric identifiers that affiliates can use to promote products or subscriptions. These codes are ideal for influencers or partners, making them easier to share than long URLs.

**Example Use Case**: An influencer promotes a subscription with the short code "JOIN123456" within their TikTok video's description. When users enter this code within your app during sign-up or before purchase, the app tracks the subscription back to the influencer for commission payouts.

For more information, visit the [Insert Affiliate Short Codes Documentation](https://docs.insertaffiliate.com/short-codes).

```dart
late final InsertAffiliateFlutterSDK insertAffiliateSdk;

insertAffiliateSdk.setShortCode("B2SC6VRSKQ")
```

#### Example Integration
Below is an example SwiftUI implementation where users can enter a short code, which will be validated and associated with the affiliate's account:

```dart
late final InsertAffiliateFlutterSDK insertAffiliateSdk;

ElevatedButton(
    onPressed: () => insertAffiliateSdk.setShortCode("B2SC6VRSKQ"),
    child: Text("Set Short Code"),
)
```

#### Example Usage
Set the Affiliate Identifier (required for tracking):

```swift
InsertAffiliateSwift.setInsertAffiliateIdentifier(referringLink: "your_affiliate_link")
```