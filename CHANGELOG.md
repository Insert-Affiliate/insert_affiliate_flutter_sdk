## Unreleased
- In-app referrals (Refer a friend): turn your app's users into affiliates from inside the app. Needs the matching Insert Affiliate API release and the program switched on in the dashboard.
  - `createAffiliateForUser(email, name)` enrols the user. When the email is already an affiliate, a 6-digit code is emailed and `verifyAffiliateCode(email, code)` connects this device (also after a reinstall or on a new phone). The code may be typed in any script's digits.
  - `getMyAffiliateDetails()` returns the referrer's code, link, `referralCount`, earnings, `rewardsGranted`, `premiumUntil` and `rewardCodes`. Also `isUserAnAffiliate()`, `signOutAffiliate()`, `getReferralProgramConfig()` and `shareReferralLink()`.
  - `showReferAFriend(context)` presents the drop-in "Refer a friend" bottom sheet (`ReferAFriendScreen`): join form, email code step, code and link with Copy and Share, referral count, earnings, "Free premium until ..." and reward codes with Redeem. Copy and colour come from `ReferAFriendOptions`, then the dashboard.
  - Automatic referrer rewards (RevenueCat, Adapty, App Store offer codes, Google Play): pass `appUserId` and/or `playPurchaseToken` to `createAffiliateForUser` / `verifyAffiliateCode` / `ReferAFriendOptions`, or later to `setReferrerAccount`.
  - The device keeps a referrer token in the app's shared preferences. It is cleared on `signOutAffiliate()` or when the server rejects it (`INVALID_TOKEN`, `AFFILIATE_NOT_FOUND`), and kept on network and other errors.
  - Every label on the screen can be translated or reworded: `ReferAFriendOptions(strings: ReferralStrings(...))`. Each field is optional and falls back to the English default, and `{email}` and `{date}` are filled in when the screen shows the text. `headline` and `rewardText` stay where they are. "Send a new code" now confirms that another code was sent.
- New dependency: `share_plus` (`>=11.0.0 <13.0.0`) for the system share sheet.
- In-app referrals: enrol, verify and `setReferrerAccount` send the phone's OS (`os`: `ios` or `android`) so the server can pick the referrer's reward store. Left out on web and desktop.
- In-app referrals: `ReferralRewardCode` has `store` (`app_store` or `google_play`, missing means `app_store`) with `isAppStore` / `isGooglePlay`. The Refer a friend screen lists App Store codes on iOS and Google Play promo codes on Android (all codes elsewhere), via the new `rewardCodesForPlatform`.

## 1.7.0
Add short code usage tracking

## 1.4.0
Adapty integration

## 1.3.0
Major feature release: Affiliate Details & Short Code Validation
- NEW: `getAffiliateDetails()` method to retrieve affiliate information without setting identifier
- NEW: `AffiliateDetails` class containing affiliateName, affiliateShortCode, and deeplinkUrl
- Enhanced: `setShortCode()` now returns `Future<bool>` for validation feedback (breaking change)
- Enhanced: `setShortCode()` validates short codes against the API before storing
- Enhanced: Comprehensive README documentation with Flutter widget examples
- Enhanced: Added detailed usage examples for getting affiliate details
- Enhanced: Improved error handling and user feedback for short code validation

## 1.2.1
Documentation update:
- Fixed: README.md attribution timeout documentation now correctly shows initialization method as recommended approach
- Enhanced: Added runtime configuration method as secondary option for attribution timeout
- Clarified: Attribution timeout configuration best practices

## 1.2.0
Major feature release: Attribution Timeout + Dependency Updates
- NEW: Attribution timeout functionality with seconds precision
- NEW: `attributionTimeout` parameter in SDK constructor
- NEW: `setAffiliateAttributionTimeout()` and `getAffiliateAttributionTimeout()` methods
- NEW: `isAffiliateAttributionValid()` method to check attribution validity
- NEW: `getAffiliateStoredDate()` method to retrieve attribution date
- NEW: `returnInsertAffiliateIdentifier(ignoreTimeout: true)` parameter for testing
- Enhanced: Attribution dates are now tracked automatically
- Enhanced: Backward compatibility maintained for existing attributions
- Updated: All dependencies from v1.1.8 merged (latest versions)
- Updated: Dart SDK requirement to >=3.9.0
- Fixed: Connectivity API compatibility for new connectivity_plus version
- Fixed: Deprecated window usage replaced with platformDispatcher

## 1.1.8
Major dependency update with SDK upgrade:
- Updated Dart SDK requirement to >=3.9.0
- device_info_plus: ^12.1.0 (from ^10.1.2) - now fully up-to-date
- connectivity_plus: ^6.1.0 (from ^5.0.2) 
- in_app_purchase: ^3.2.3 (from ^3.2.0)
- in_app_purchase_storekit: ^0.4.6 (from ^0.3.20)
- shared_preferences: ^2.5.3 (from ^2.3.2)
- url_launcher: ^6.3.2 (from ^6.3.1)
- package_info_plus: ^9.0.0 (from ^8.1.0)
- flutter_lints: ^6.0.0 (from ^3.0.0)

## 1.1.7
Updated dependencies to latest versions, including:
- http: ^1.2.2 (from ^0.13.5)
- shared_preferences: ^2.3.2 (from ^2.0.13)
- url_launcher: ^6.3.1 (from ^6.1.0)
- connectivity_plus: ^5.0.2 (from ^3.0.0)
- device_info_plus: ^10.1.2 (from ^9.0.0)
- android_play_install_referrer: ^0.4.0 (from ^0.3.0)
- in_app_purchase: ^3.2.0 (from >=2.0.0 <4.0.0)

## 1.1.6
Package info plus dependency update

## 1.1.5
Introducing Insert Links

## 1.1.4
AppsFlyer integration documentation and improvements.

## 1.1.3
Android promo codes support added

## 1.1.2
Fix approach for iOS offer codes - iOS only.

## 1.1.1
Support for iOS offer codes on iOS only.

## 1.1.0
Support for iOS offer codes

## 1.0.9
Short Code 3-25 chars

## 1.0.8
Updating Track Event to pass companyId

## 1.0.6
Adding direct app & play store integration

## 1.0.5
Update ReadMe for RevCat Change

## 1.0.4
Updating ReadMe.Md to fix broken links

## 1.0.3
Updating guide and ReadMe.md

## 1.0.2
Release of Short Codes

## 1.0.0
* Initial release
