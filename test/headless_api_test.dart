// Checks that an app can run in-app referrals without the drop-in screen,
// importing only the package (never `src/`). The tear-offs and field reads
// below fail to compile if any of it stops being public.
// TargetPlatform is Flutter's own, as in any app that calls rewardCodesForPlatform.
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';

/// Never assigned: these tests read the API, they don't call it.
InsertAffiliateFlutterSDK? sdk;
MyAffiliateDetails? me;
ReferralProgramConfig? config;
AffiliateEnrolmentResult? result;

void main() {
  test('every referral call is on the SDK itself', () {
    expect(sdk?.createAffiliateForUser, isNull);
    expect(sdk?.verifyAffiliateCode, isNull);
    expect(sdk?.setReferrerAccount, isNull);
    expect(sdk?.getMyAffiliateDetails, isNull);
    expect(sdk?.isUserAnAffiliate, isNull);
    expect(sdk?.signOutAffiliate, isNull);
    expect(sdk?.getReferralProgramConfig, isNull);
    expect(sdk?.shareReferralLink, isNull);
    expect(sdk?.showReferAFriend, isNull);
  });

  test('enrolling reports its outcome and any error code', () {
    expect(result?.status, isNull);
    expect(result?.isConnected, isNull);
    expect(result?.affiliate?.affiliateShortCode, isNull);
    expect(result?.errorCode, isNull);
    expect(result?.errorMessage, isNull);
    expect(AffiliateEnrolmentStatus.values, hasLength(4));
  });

  test('stats, rewards and program settings are readable', () {
    expect(me?.affiliateShortCode, isNull);
    expect(me?.deeplinkUrl, isNull);
    expect(me?.referralTrigger, isNull);
    expect(me?.referralCount, isNull);
    expect(me?.installCount, isNull);
    expect(me?.eventCount, isNull);
    expect(me?.purchaseCount, isNull);
    expect(me?.totalEarned, isNull);
    expect(me?.totalPaid, isNull);
    expect(me?.totalUnpaid, isNull);
    expect(me?.currency, isNull);
    expect(me?.dashboardUrl, isNull);
    expect(me?.rewardsGranted, isNull);
    expect(me?.premiumUntil, isNull);
    expect(me?.rewardCodes, isNull);
    expect(config?.enabled, isNull);
    expect(config?.companyName, isNull);
    expect(config?.referralTrigger, isNull);
    expect(config?.headline, isNull);
    expect(config?.rewardText, isNull);
    expect(config?.primaryColor, isNull);
  });

  test('a reward code says which store redeems it', () {
    const reward = ReferralRewardCode(code: 'PLAY1', redeemUrl: 'https://play.google.com/redeem?code=PLAY1', store: ReferralRewardCode.googlePlay);
    expect(reward.store, 'google_play');
    expect(reward.isGooglePlay, isTrue);
    expect(reward.isAppStore, isFalse);
    expect(reward.grantedAt, isNull);
    expect(rewardCodesForPlatform(const [reward], platform: TargetPlatform.android), [reward]);
  });

  test('the share text the screen uses is available on its own', () {
    expect(
      buildReferralShareText(deeplinkUrl: 'https://insertaffiliate.link/abc', shortCode: 'ABC123', companyName: 'Velvet'),
      'Try Velvet: https://insertaffiliate.link/abc',
    );
  });
}
