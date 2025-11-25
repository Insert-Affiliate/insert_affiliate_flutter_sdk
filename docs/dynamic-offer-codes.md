# Dynamic Offer Codes Complete Guide

Automatically apply discounts or trials when users come from specific affiliates using offer code modifiers.

## How It Works

When someone clicks an affiliate link or enters a short code linked to an offer (set up in the Insert Affiliate Dashboard), the SDK fills in `OfferCode` with the right modifier (like `_oneWeekFree`). You can then add this to your regular product ID to load the correct version of the subscription in your app.

## Setup in Insert Affiliate Dashboard

1. Go to [app.insertaffiliate.com/affiliates](https://app.insertaffiliate.com/affiliates)
2. Select the affiliate you want to configure
3. Click "View" to access the affiliate's settings
4. Assign an **iOS IAP Modifier** to the affiliate (e.g., `_oneWeekFree`, `_threeMonthsFree`)
5. Assign an **Android IAP Modifier** to the affiliate (e.g., `-oneweekfree`, `-threemonthsfree`)
6. Save the settings

Once configured, when users click that affiliate's links or enter their short codes, your app will automatically receive the modifier and can load the appropriate discounted product.

## Setup in App Store Connect (iOS)

Create both a base and a promotional product:
- Base product: `oneMonthSubscription`
- Promo product: `oneMonthSubscription_oneWeekFree`

Ensure **both** products are approved and available for sale.

## Setup in Google Play Console (Android)

There are multiple ways you can configure your products:

1. **Multiple Products Approach**: Create both a base and a promotional product:
   - Base product: `oneMonthSubscription`
   - Promo product: `oneMonthSubscription-oneweekfree`

2. **Single Product with Multiple Base Plans**: Create one product with multiple base plans, one with an offer attached

3. **Developer Triggered Offers**: Have one base product and apply the offer through developer-triggered offers

4. **Base Product with Intro Offers**: Have one base product that includes an introductory offer

**If using the Multiple Products Approach:**
- Ensure **both** products are activated
- Generate a release to at least **Internal Testing** to make products available

## Basic Usage

### Automatic Offer Code Fetching

The SDK automatically fetches and saves the associated offer code modifier when:
- An affiliate identifier is set via `setInsertAffiliateIdentifier()`
- A short code is set via `setShortCode()`

### Access the Stored Offer Code

```dart
String? offerCode = await insertAffiliateSdk.getStoredOfferCode();
```

## RevenueCat Integration Example

For apps using RevenueCat, dynamically construct offering identifiers:

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
              'Special Offer Applied: $offerCode',
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

## Native IAP Integration Example

For apps using the native `in_app_purchase` package:

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
        final ProductDetailsResponse fallbackResponse =
            await _iap.queryProductDetails({baseProductIdentifier});
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

  @override
  Widget build(BuildContext context) {
    final ProductDetails? primaryProduct =
        availableProducts.isNotEmpty ? availableProducts.first : null;

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
                'Special Offer Applied: $offerCode',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (loading)
            Center(child: CircularProgressIndicator())
          else if (primaryProduct != null) ...[
            Text(primaryProduct.title, style: TextStyle(fontSize: 16)),
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
              onPressed: loading ? null : () => _handlePurchase(primaryProduct.id),
              child: Text(loading ? "Processing..." : "Subscribe Now"),
            ),

            if (primaryProduct.id == dynamicProductIdentifier &&
                offerCode != null && offerCode!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Promotional pricing applied',
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
        ],
      ),
    );
  }

  Future<void> _handlePurchase(String productId) async {
    // Handle purchase implementation
  }
}
```

## Key Features

1. **Dynamic Product Loading**: Automatically constructs product IDs using the offer code modifier
2. **Fallback Strategy**: If the promotional product isn't found, falls back to the base product
3. **Visual Feedback**: Shows users when promotional pricing is applied
4. **Cross-Platform**: Works on both iOS and Android with appropriate product naming

## Example Product Identifiers

**iOS (App Store Connect):**
- Base product: `oneMonthSubscription`
- With introductory discount: `oneMonthSubscription_oneWeekFree`
- With different offer: `oneMonthSubscription_threeMonthsFree`

**Android (Google Play Console):**
- Base product: `onemonthsubscription`
- With introductory discount: `onemonthsubscription-oneweekfree`
- With different offer: `onemonthsubscription-threemonthsfree`

## Best Practices

1. **Product Setup**: Always create both base and promotional products in store consoles
2. **Naming Convention**: Use consistent naming patterns for offer code modifiers
3. **Fallback Logic**: Always implement fallback to base products if promotional ones aren't available
4. **User Experience**: Clearly indicate when special pricing is applied
5. **Testing**: Test both scenarios - with and without offer codes applied

## Testing

1. **Set up test affiliate** with offer code modifier in Insert Affiliate dashboard
2. **Click test affiliate link** or enter short code
3. **Verify offer code** is stored:
   ```dart
   final offerCode = await insertAffiliateSdk.getStoredOfferCode();
   print('Offer code: $offerCode');
   ```
4. **Check dynamic product ID** is constructed correctly
5. **Complete test purchase** to verify correct product is purchased

## Troubleshooting

**Problem:** Offer code is null
- **Solution:** Ensure affiliate has offer code modifier configured in dashboard
- Verify user clicked affiliate link or entered short code before checking

**Problem:** Promotional product not found
- **Solution:** Verify promotional product exists in App Store Connect / Google Play Console
- Check product ID matches exactly (including the modifier)
- Ensure product is published to at least TestFlight (iOS) or Internal Testing (Android)

**Problem:** Always showing base product instead of promotional
- **Solution:** Ensure offer code is retrieved before fetching products
- Check that `offerCode` is not null/empty
- Verify the dynamic product identifier is correct

## Next Steps

- Configure offer code modifiers for high-value affiliates
- Create promotional products in App Store Connect and Google Play Console
- Test the complete flow from link click to purchase
- Monitor affiliate performance in Insert Affiliate dashboard

[Back to Main README](../README.md)
