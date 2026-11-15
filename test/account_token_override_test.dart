import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insert_affiliate_flutter_sdk/insert_affiliate_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ownUUID = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
const storedAffiliate = {
  'referring_link': 'CREATOR1',
  'shortUniqueDeviceID': 'ABC123',
};

Future<String?> registerToken(
  List<Map<String, dynamic>> sentPayloads, {
  String? overrideUUID,
}) {
  final client = MockClient((request) async {
    // The SDK also calls other endpoints while it starts up.
    if (request.url.path.endsWith('/create-expected-transaction')) {
      sentPayloads.add(jsonDecode(request.body) as Map<String, dynamic>);
    }
    return http.Response('{}', 200);
  });
  return http.runWithClient(() {
    final sdk = InsertAffiliateFlutterSDK(companyCode: 'COMPANY');
    return sdk.returnUserAccountTokenAndStoreExpectedTransaction(overrideUUID: overrideUUID);
  }, () => client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a supplied UUID is registered and returned', () async {
    SharedPreferences.setMockInitialValues(storedAffiliate);
    final sentPayloads = <Map<String, dynamic>>[];

    final token = await registerToken(sentPayloads, overrideUUID: ownUUID);

    expect(token, ownUUID);
    expect(sentPayloads.single['UUID'], ownUUID);
    expect(sentPayloads.single['shortCode'], 'CREATOR1-ABC123');
  });

  test('a supplied UUID is reused by later calls without one', () async {
    SharedPreferences.setMockInitialValues(storedAffiliate);
    await registerToken([], overrideUUID: ownUUID);

    final token = await registerToken([]);

    expect(token, ownUUID);
  });

  test('a value that is not a UUID registers nothing', () async {
    SharedPreferences.setMockInitialValues(storedAffiliate);
    final sentPayloads = <Map<String, dynamic>>[];

    final token = await registerToken(sentPayloads, overrideUUID: 'user-42');

    expect(token, isNull);
    expect(sentPayloads, isEmpty);
  });

  test('without a supplied UUID the SDK generates one', () async {
    SharedPreferences.setMockInitialValues(storedAffiliate);
    final sentPayloads = <Map<String, dynamic>>[];

    final token = await registerToken(sentPayloads);

    expect(token, isNotNull);
    expect(sentPayloads.single['UUID'], token);
  });
}
