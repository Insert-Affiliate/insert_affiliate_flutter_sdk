import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart' show InsertAffiliateFlutterSDK;
import 'package:insert_affiliate_flutter_sdk/src/referrals.dart';
import 'package:insert_affiliate_flutter_sdk/src/refer_a_friend_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'insert_affiliate_referrer_token_company123';

/// Records the referral calls the drop-in screen makes.
class _FakeSdk extends Fake implements InsertAffiliateFlutterSDK {
  _FakeSdk({this.enrolled = false});

  final bool enrolled;
  final List<Map<String, String?>> calls = [];

  static const _details = MyAffiliateDetails(
    affiliateName: 'Jane',
    affiliateShortCode: 'ABC123',
    deeplinkUrl: 'https://insertaffiliate.link/abc',
    referralTrigger: 'purchase',
    referralCount: 0,
    installCount: 0,
    eventCount: 0,
    purchaseCount: 0,
    totalEarned: 0,
    totalPaid: 0,
    totalUnpaid: 0,
    currency: 'USD',
    dashboardUrl: '',
  );

  @override
  Future<ReferralProgramConfig?> getReferralProgramConfig() async => null;

  @override
  Future<MyAffiliateDetails?> getMyAffiliateDetails() async => enrolled ? _details : null;

  @override
  Future<bool> isUserAnAffiliate() async => enrolled;

  @override
  Future<AffiliateEnrolmentResult> createAffiliateForUser(String email, String name,
      {String? appUserId, String? playPurchaseToken}) async {
    calls.add({'method': 'enrol', 'appUserId': appUserId, 'playPurchaseToken': playPurchaseToken});
    return const AffiliateEnrolmentResult(status: AffiliateEnrolmentStatus.verificationRequired);
  }

  @override
  Future<AffiliateEnrolmentResult> verifyAffiliateCode(String email, String code,
      {String? name, String? appUserId, String? playPurchaseToken}) async {
    calls.add({'method': 'verify', 'appUserId': appUserId, 'playPurchaseToken': playPurchaseToken});
    return const AffiliateEnrolmentResult.error('INVALID_CODE', 'Wrong code');
  }

  @override
  Future<bool> setReferrerAccount({String? appUserId, String? playPurchaseToken}) async {
    calls.add({'method': 'setReferrerAccount', 'appUserId': appUserId, 'playPurchaseToken': playPurchaseToken});
    return true;
  }
}

Widget _screen(_FakeSdk sdk, ReferAFriendOptions options) =>
    MaterialApp(home: Scaffold(body: ReferAFriendScreen(sdk: sdk, options: options)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildReferralShareText', () {
    test('link: default message', () {
      expect(
        buildReferralShareText(deeplinkUrl: 'https://insertaffiliate.link/abc', shortCode: 'ABC123', companyName: 'Velvet'),
        'Try Velvet: https://insertaffiliate.link/abc',
      );
    });

    test('link: custom message without placeholders gets the link appended', () {
      expect(
        buildReferralShareText(
          deeplinkUrl: 'https://insertaffiliate.link/abc',
          shortCode: 'ABC123',
          companyName: 'Velvet',
          message: 'Get a free week:',
        ),
        'Get a free week: https://insertaffiliate.link/abc',
      );
    });

    test('custom message placeholders are replaced', () {
      expect(
        buildReferralShareText(
          deeplinkUrl: 'https://insertaffiliate.link/abc',
          shortCode: 'ABC123',
          companyName: 'Velvet',
          message: 'Join me {link} (code {code})',
        ),
        'Join me https://insertaffiliate.link/abc (code ABC123)',
      );
    });

    test('Short Code Only: default message uses the code', () {
      expect(
        buildReferralShareText(deeplinkUrl: 'ABC123', shortCode: 'ABC123', companyName: 'Velvet'),
        'Use my code ABC123 in Velvet',
      );
      expect(
        buildReferralShareText(deeplinkUrl: '', shortCode: 'ABC123', companyName: ''),
        'Use my code ABC123',
      );
    });

    test('Short Code Only: {link} falls back to the code', () {
      expect(
        buildReferralShareText(deeplinkUrl: '', shortCode: 'ABC123', companyName: 'Velvet', message: 'Code: {link}'),
        'Code: ABC123',
      );
    });
  });

  group('JSON parsing', () {
    test('MyAffiliateDetails.fromJson reads every field', () {
      final details = MyAffiliateDetails.fromJson({
        'affiliateName': 'Jane',
        'affiliateShortCode': 'a1b2c3d4',
        'deeplinkurl': 'https://insertaffiliate.link/x',
        'referralTrigger': 'purchase',
        'referralCount': 7,
        'installCount': 19,
        'purchaseCount': 7,
        'eventCount': 11,
        'totalEarned': 42.5,
        'totalPaid': 30,
        'totalUnpaid': 12.5,
        'currency': 'USD',
        'dashboardUrl': 'https://app.insertaffiliate.com/signin',
      });
      expect(details.affiliateName, 'Jane');
      expect(details.affiliateShortCode, 'a1b2c3d4');
      expect(details.deeplinkUrl, 'https://insertaffiliate.link/x');
      expect(details.referralTrigger, 'purchase');
      expect(details.referralCount, 7);
      expect(details.installCount, 19);
      expect(details.purchaseCount, 7);
      expect(details.eventCount, 11);
      expect(details.totalEarned, 42.5);
      expect(details.totalPaid, 30.0);
      expect(details.totalUnpaid, 12.5);
      expect(details.currency, 'USD');
      expect(details.dashboardUrl, 'https://app.insertaffiliate.com/signin');
    });

    test('MyAffiliateDetails.fromJson tolerates missing fields', () {
      final details = MyAffiliateDetails.fromJson({});
      expect(details.affiliateName, '');
      expect(details.referralCount, 0);
      expect(details.totalEarned, 0);
      expect(details.currency, 'USD');
      expect(details.rewardsGranted, 0);
      expect(details.premiumUntil, isNull);
      expect(details.rewardCodes, isEmpty);
    });

    test('MyAffiliateDetails.fromJson reads rewards', () {
      final details = MyAffiliateDetails.fromJson({
        'rewardsGranted': 3,
        'premiumUntil': '2026-10-01T12:00:00.000Z',
        'rewardCodes': [
          {
            'code': 'FREEWEEK2',
            'redeemUrl': 'https://apps.apple.com/redeem?ctx=offercodes&id=123&code=FREEWEEK2',
            'grantedAt': '2026-09-18T10:00:00.000Z',
          },
          {'code': 'FREEWEEK1', 'redeemUrl': 'https://apps.apple.com/redeem?code=FREEWEEK1', 'grantedAt': null},
          {'redeemUrl': 'https://ignored'},
          'not an object',
        ],
      });
      expect(details.rewardsGranted, 3);
      expect(details.premiumUntil, DateTime.utc(2026, 10, 1, 12));
      expect(details.rewardCodes.map((reward) => reward.code), ['FREEWEEK2', 'FREEWEEK1']);
      expect(details.rewardCodes.first.redeemUrl, contains('code=FREEWEEK2'));
      expect(details.rewardCodes.first.grantedAt, DateTime.utc(2026, 9, 18, 10));
      expect(details.rewardCodes.last.grantedAt, isNull);
    });

    test('MyAffiliateDetails.fromJson ignores bad reward values', () {
      final details = MyAffiliateDetails.fromJson({'premiumUntil': 'not a date', 'rewardCodes': 'nope'});
      expect(details.premiumUntil, isNull);
      expect(details.rewardCodes, isEmpty);
    });

    test('ReferralProgramConfig.fromJson', () {
      final config = ReferralProgramConfig.fromJson({
        'enabled': true,
        'companyName': 'Velvet',
        'referralTrigger': 'event',
        'headline': 'Give a week, get a week',
        'rewardText': 'Earn a free week for every friend who subscribes.',
        'primaryColor': '#112233',
      });
      expect(config.enabled, isTrue);
      expect(config.companyName, 'Velvet');
      expect(config.referralTrigger, 'event');
      expect(config.headline, 'Give a week, get a week');
      expect(config.rewardText, startsWith('Earn'));
      expect(config.primaryColor, '#112233');
      expect(ReferralProgramConfig.fromJson({}).enabled, isFalse);
    });

    test('AffiliateEnrolmentResult.fromJson maps statuses', () {
      final created = AffiliateEnrolmentResult.fromJson({
        'status': 'created',
        'token': 'secret',
        'affiliate': {'affiliateName': 'Jane', 'affiliateShortCode': 'ABC', 'deeplinkurl': 'https://x'},
      });
      expect(created.status, AffiliateEnrolmentStatus.created);
      expect(created.isConnected, isTrue);
      expect(created.affiliate?.affiliateShortCode, 'ABC');
      expect(created.affiliate?.deeplinkUrl, 'https://x');

      final pending = AffiliateEnrolmentResult.fromJson({'status': 'verificationRequired'});
      expect(pending.status, AffiliateEnrolmentStatus.verificationRequired);
      expect(pending.isConnected, isFalse);
      expect(pending.affiliate, isNull);

      expect(AffiliateEnrolmentResult.fromJson({'status': 'connected'}).status, AffiliateEnrolmentStatus.connected);
      final unknown = AffiliateEnrolmentResult.fromJson({'status': 'weird'});
      expect(unknown.status, AffiliateEnrolmentStatus.error);
      expect(unknown.errorCode, 'INVALID_RESPONSE');
    });
  });

  group('InsertAffiliateReferrals', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    InsertAffiliateReferrals client(MockClientHandler handler) =>
        InsertAffiliateReferrals(companyCode: 'company123', client: MockClient(handler));

    test('enrol created stores the token and sends platform flutter', () async {
      late Map<String, dynamic> sent;
      final referrals = client((request) async {
        expect(request.url.toString(), 'https://api.insertaffiliate.com/V1/sdk/affiliate/enrol');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'created',
            'token': 'tok_1',
            'affiliate': {'affiliateName': 'Jane', 'affiliateShortCode': 'ABC', 'deeplinkurl': 'ABC'},
          }),
          200,
        );
      });

      final result = await referrals.enrol(' jane@example.com ', 'Jane');
      expect(result.status, AffiliateEnrolmentStatus.created);
      // flutter_test reports Android as the target platform by default.
      expect(sent, {
        'companyId': 'company123',
        'email': 'jane@example.com',
        'name': 'Jane',
        'platform': 'flutter',
        'os': 'android',
      });
      expect(await referrals.hasToken(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_tokenKey), 'tok_1');
    });

    test('enrol and verify send deviceId and the app supplied ids', () async {
      final bodies = <Map<String, dynamic>>[];
      final referrals = InsertAffiliateReferrals(
        companyCode: 'company123',
        deviceId: () async => 'dev123',
        client: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'status': 'verificationRequired'}), 200);
        }),
      );

      await referrals.enrol('jane@example.com', 'Jane', appUserId: ' rc_user_1 ', playPurchaseToken: 'play_tok');
      await referrals.verify('jane@example.com', '123456', appUserId: '');
      expect(bodies[0]['deviceId'], 'dev123');
      expect(bodies[0]['appUserId'], 'rc_user_1');
      expect(bodies[0]['playPurchaseToken'], 'play_tok');
      expect(bodies[1]['deviceId'], 'dev123');
      expect(bodies[1].containsKey('appUserId'), isFalse);
      expect(bodies[1].containsKey('playPurchaseToken'), isFalse);
    });

    test('enrol, verify and setIdentity send os on iOS and Android only', () async {
      final bodies = <String, Map<String, dynamic>>{};
      final referrals = client((request) async {
        bodies[request.url.path.split('/').last] = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'status': 'verificationRequired', 'saved': true}), 200);
      });
      final expected = {
        TargetPlatform.iOS: 'ios',
        TargetPlatform.android: 'android',
        TargetPlatform.macOS: null,
        TargetPlatform.windows: null,
        TargetPlatform.linux: null,
        TargetPlatform.fuchsia: null,
      };
      try {
        for (final entry in expected.entries) {
          debugDefaultTargetPlatformOverride = entry.key;
          SharedPreferences.setMockInitialValues({_tokenKey: 'tok_1'});
          bodies.clear();
          await referrals.enrol('jane@example.com', 'Jane');
          await referrals.verify('jane@example.com', '123456');
          await referrals.setIdentity(appUserId: 'rc_user_1');
          expect(bodies.keys, unorderedEquals(['enrol', 'verify', 'identity']));
          for (final body in bodies.values) {
            expect(body['os'], entry.value, reason: '${entry.key}');
            expect(body.containsKey('os'), entry.value != null, reason: '${entry.key}');
          }
          expect(bodies['enrol']!['platform'], 'flutter');
          expect(bodies['verify']!['platform'], 'flutter');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('enrol verificationRequired stores nothing', () async {
      final referrals = client((_) async => http.Response(jsonEncode({'status': 'verificationRequired'}), 200));
      final result = await referrals.enrol('jane@example.com', 'Jane');
      expect(result.status, AffiliateEnrolmentStatus.verificationRequired);
      expect(await referrals.hasToken(), isFalse);
    });

    test('server errors surface code and message', () async {
      final referrals = client((_) async => http.Response(
            jsonEncode({'error': 'In-app referrals are not enabled for this app.', 'code': 'PROGRAM_DISABLED'}),
            403,
          ));
      final result = await referrals.enrol('jane@example.com', 'Jane');
      expect(result.status, AffiliateEnrolmentStatus.error);
      expect(result.errorCode, 'PROGRAM_DISABLED');
      expect(result.errorMessage, 'In-app referrals are not enabled for this app.');
    });

    test('network failure returns NETWORK_ERROR', () async {
      final referrals = client((_) async => throw http.ClientException('offline'));
      final result = await referrals.verify('jane@example.com', '123456');
      expect(result.errorCode, 'NETWORK_ERROR');
    });

    test('verify connected stores the token', () async {
      final referrals = client((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], '123456');
        return http.Response(jsonEncode({'status': 'connected', 'token': 'tok_2', 'affiliate': {}}), 200);
      });
      final result = await referrals.verify('jane@example.com', '123456', name: 'Jane');
      expect(result.status, AffiliateEnrolmentStatus.connected);
      expect(await referrals.hasToken(), isTrue);
    });

    test('me returns null without a token and makes no request', () async {
      var called = false;
      final referrals = client((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      expect(await referrals.me(), isNull);
      expect(called, isFalse);
    });

    test('me sends the token header and parses details', () async {
      SharedPreferences.setMockInitialValues({_tokenKey: 'tok_1'});
      final referrals = client((request) async {
        expect(request.headers['X-Insert-Affiliate-Token'], 'tok_1');
        return http.Response(jsonEncode({'affiliateShortCode': 'ABC', 'referralCount': 3}), 200);
      });
      final details = await referrals.me();
      expect(details?.affiliateShortCode, 'ABC');
      expect(details?.referralCount, 3);
    });

    test('me clears the token on 401 and 404', () async {
      for (final status in [401, 404]) {
        SharedPreferences.setMockInitialValues({_tokenKey: 'tok_1'});
        final referrals = client((_) async => http.Response(jsonEncode({'code': 'INVALID_TOKEN'}), status));
        expect(await referrals.me(), isNull);
        expect(await referrals.hasToken(), isFalse);
      }
    });

    test('me keeps the token on a server error', () async {
      SharedPreferences.setMockInitialValues({_tokenKey: 'tok_1'});
      final referrals = client((_) async => http.Response('oops', 500));
      expect(await referrals.me(), isNull);
      expect(await referrals.hasToken(), isTrue);
    });

    test('setIdentity returns false without a token and makes no request', () async {
      var called = false;
      final referrals = client((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      expect(await referrals.setIdentity(appUserId: 'rc_user_1'), isFalse);
      expect(called, isFalse);
    });

    test('setIdentity posts the ids with the token header', () async {
      SharedPreferences.setMockInitialValues({_tokenKey: 'tok_1'});
      final referrals = InsertAffiliateReferrals(
        companyCode: 'company123',
        deviceId: () async => 'dev123',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.insertaffiliate.com/V1/sdk/affiliate/me/identity');
          expect(request.headers['X-Insert-Affiliate-Token'], 'tok_1');
          expect(jsonDecode(request.body),
              {'appUserId': 'rc_user_1', 'playPurchaseToken': 'play_tok', 'deviceId': 'dev123', 'os': 'android'});
          return http.Response(jsonEncode({'saved': true}), 200);
        }),
      );
      expect(await referrals.setIdentity(appUserId: 'rc_user_1', playPurchaseToken: 'play_tok'), isTrue);
      expect(await referrals.hasToken(), isTrue);
    });

    test('setIdentity clears the token on 401 and 404', () async {
      for (final status in [401, 404]) {
        SharedPreferences.setMockInitialValues({_tokenKey: 'tok_1'});
        final referrals = client((_) async => http.Response(jsonEncode({'code': 'INVALID_TOKEN'}), status));
        expect(await referrals.setIdentity(appUserId: 'rc_user_1'), isFalse);
        expect(await referrals.hasToken(), isFalse);
      }
    });

    test('setIdentity keeps the token on a server or network error', () async {
      SharedPreferences.setMockInitialValues({_tokenKey: 'tok_1'});
      final failing = client((_) async => http.Response('oops', 500));
      expect(await failing.setIdentity(appUserId: 'rc_user_1'), isFalse);
      expect(await failing.hasToken(), isTrue);
      final offline = client((_) async => throw http.ClientException('offline'));
      expect(await offline.setIdentity(appUserId: 'rc_user_1'), isFalse);
      expect(await offline.hasToken(), isTrue);
    });

    test('clearToken signs out', () async {
      SharedPreferences.setMockInitialValues({_tokenKey: 'tok_1'});
      final referrals = client((_) async => http.Response('{}', 200));
      await referrals.clearToken();
      expect(await referrals.hasToken(), isFalse);
    });

    test('config hits the company path', () async {
      final referrals = client((request) async {
        expect(request.url.path, '/V1/sdk/affiliate/config/company123');
        return http.Response(jsonEncode({'enabled': true, 'companyName': 'Velvet'}), 200);
      });
      final config = await referrals.config();
      expect(config?.enabled, isTrue);
      expect(config?.companyName, 'Velvet');
    });
  });

  group('ReferAFriendScreen account options', () {
    const options = ReferAFriendOptions(email: 'jane@example.com', appUserId: 'rc_user_1', playPurchaseToken: 'play_tok');

    testWidgets('enrol and verify pass appUserId and playPurchaseToken', (tester) async {
      final sdk = _FakeSdk();
      await tester.pumpWidget(_screen(sdk, options));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get my link'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(sdk.calls, [
        {'method': 'enrol', 'appUserId': 'rc_user_1', 'playPurchaseToken': 'play_tok'},
        {'method': 'verify', 'appUserId': 'rc_user_1', 'playPurchaseToken': 'play_tok'},
      ]);
    });

    testWidgets('an enrolled user saves the account once when the screen opens', (tester) async {
      final sdk = _FakeSdk(enrolled: true);
      await tester.pumpWidget(_screen(sdk, options));
      await tester.pumpAndSettle();
      expect(sdk.calls, [
        {'method': 'setReferrerAccount', 'appUserId': 'rc_user_1', 'playPurchaseToken': 'play_tok'},
      ]);
    });

    testWidgets('no account options means no setReferrerAccount call', (tester) async {
      final sdk = _FakeSdk(enrolled: true);
      await tester.pumpWidget(_screen(sdk, const ReferAFriendOptions()));
      await tester.pumpAndSettle();
      expect(sdk.calls, isEmpty);
    });
  });

  group('UI helpers', () {
    test('parseReferralHexColor', () {
      expect(parseReferralHexColor('#6A0DAD'), const Color(0xFF6A0DAD));
      expect(parseReferralHexColor('112233'), const Color(0xFF112233));
      expect(parseReferralHexColor(''), isNull);
      expect(parseReferralHexColor('#12'), isNull);
      expect(parseReferralHexColor(null), isNull);
    });

    test('formatReferralAmount', () {
      expect(formatReferralAmount(42.5, 'USD'), r'$42.50');
      expect(formatReferralAmount(3, 'SEK'), '3.00 SEK');
    });
  });
}
