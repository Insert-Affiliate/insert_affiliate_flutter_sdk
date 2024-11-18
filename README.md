# Insert Affiliate Flutter SDK

## Overview

The **Insert Affiliate Flutter SDK** is designed for Flutter applications, providing seamless integration with the [Insert Affiliate platform](https://insertaffiliate.com). For more details and to access the Insert Affiliate dashboard, visit [app.insertaffiliate.com](https://app.insertaffiliate.com).

## Features

- **Unique Device Identification**: Generates and stores a short unique device ID to identify users effectively.
- **Affiliate Identifier Management**: Set and retrieve the affiliate identifier based on user-specific links.
- **In-App Purchase (IAP) Initialisation**: Easily work with in-app purchases with validation options using the affiliate identifier.

## Installation

Include the following dependencies in your pubspec.yaml file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  insert_affiliate_flutter_sdk: <latest_version>
  in_app_purchase: <latest_version>
  flutter_branch_sdk: <latest_version>
  shared_preferences: <latest_version>
  http: <latest_version>
```

Run flutter pub get to fetch the packages.

### Step 2: Import Necessary Packages
In your main Dart file, import the required packages:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';
```

### Step 3: Initialise the SDK


- Replace `{{ your_iaptic_app_id }}` with your **Iaptic App ID**. You can find this [here](https://www.iaptic.com/account).
- Replace `{{ your_iaptic_app_name }}` with your **Iaptic App Name**. You can find this [here](https://www.iaptic.com/account).
- Replace `{{ your_iaptic_public_key }}` with your **Iaptic Public Key**. You can find this [here](https://www.iaptic.com/settings).

```dart
late final InsertAffiliateFlutterSDK insertAffiliateSdk;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Branch SDK
  FlutterBranchSdk.init(enableLogging: false, disableTracking: false);

  // Initialise Insert Affiliate SDK
  insertAffiliateSdk = InsertAffiliateFlutterSDK(
    iapSkus: ['...'], // Replace with your IAP subscription SKUs
    iapticAppId: "{{ your_iaptic_app_id }}", // Replace with your app ID
    iapticAppName: "{{ your_iaptic_app_name }}", // Replace with your app name
    iapticPublicKey: "{{ your_iaptic_public_key }}", // Replace with your public key
  );

  runApp(MyApp());
}
```

### Step 4: Set Up Your Deep Linking SDK for Referrer Links
In the example below, we demonstrate using Branch.io. This logic is compatible with any deep linking platform that provides the clicked link—simply call `insertAffiliateSdk.saveInsertAffiliateLink(...)` and pass the link as an argument.

```dart
late StreamSubscription<Map> _branchStreamSubscription;

@override
void initState() {
  super.initState();

  _branchStreamSubscription = FlutterBranchSdk.listSession().listen((data) {
    if (data.containsKey("+clicked_branch_link") && data["+clicked_branch_link"] == true) {
      insertAffiliateSdk.saveInsertAffiliateLink(data["~referring_link"]);
    }
  }, onError: (error) {
    print('Branch session error: ${error.toString()}');
  });
}

@override
void dispose() {
  _branchStreamSubscription?.cancel();
  super.dispose();
}
```

### Step 5: Implement In-App Purchases
Set up InAppPurchase and listen for purchase updates:

#### Initialise In-App Purchases:
```dart
final InAppPurchase _iap = InAppPurchase.instance;
bool _available = false;
List<ProductDetails> _products = [];

Future<void> _initializeInAppPurchase() async {
  _available = await _iap.isAvailable();
  if (_available) {
    const Set<String> _kIds = <String>{'oneMonthSubscriptionTwo'};
    final ProductDetailsResponse response = await _iap.queryProductDetails(_kIds);
    if (response.notFoundIDs.isNotEmpty) {
      print("Product not found: ${response.notFoundIDs}");
    }
    setState(() {
      _products = response.productDetails;
    });
  } else {
    print("Store not available");
  }
}
```

#### Listen to Purchase Updates:
```dart
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    if (purchaseDetails.status == PurchaseStatus.purchased) {
      // Validate purchase with Insert Affiliate SDK
      insertAffiliateSdk.handlePurchaseValidation(purchaseDetails);
    }
    InAppPurchase.instance.completePurchase(purchaseDetails);
  }
}
```

