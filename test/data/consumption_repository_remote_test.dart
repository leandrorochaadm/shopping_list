import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/report_period.dart';

import '../helpers/pocketbase_test_client.dart';

const _categoryId = 'cat000000000004';
const _typeId = 'type00000000005';
const _registrationId = 'reg000000000005';
const _productId = 'prod00000000005';
const _purchaseId = 'purch0000000001';

final _window = ReportPeriod(
  from: DateTime(2026, 5, 1),
  to: DateTime(2026, 7, 31),
);
final _month = ReportPeriod(
  from: DateTime(2026, 8, 1),
  to: DateTime(2026, 8, 31),
);

void main() {
  late List<http.Request> requests;

  setUp(() => requests = []);

  /// Answers by collection, so the four parallel reads each get their own.
  MockClient serving({
    List<Map<String, dynamic>> items = const [],
    List<Map<String, dynamic>> totals = const [],
    List<Map<String, dynamic>> products = const [],
    List<Map<String, dynamic>> registrations = const [],
  }) => MockClient((request) async {
    requests.add(request);
    return switch (request.url.pathSegments[2]) {
      'purchase_item' => listJson(items),
      'purchase_item_totals' => listJson(totals),
      'product' => listJson(products),
      'product_registration' => listJson(registrations),
      _ => errorJson(404),
    };
  });

  ConsumptionRepositoryRemote repositoryOf(MockClient client) =>
      ConsumptionRepositoryRemote(testPocketBase(client));

  Future<dynamic> fetch(ConsumptionRepositoryRemote repository) =>
      repository.fetchTypeConsumption(window: _window, month: _month);

  Map<String, dynamic> item({
    required String date,
    required int quantity,
    String name = 'Café',
    String baseUnit = 'gram',
    bool typeActive = true,
  }) => recordJson(
    'item00000000001',
    {
      'purchase_id': _purchaseId,
      'product_id': _productId,
      'quantity_in_base_unit': quantity,
      'total_paid': 1000,
    },
    expand: {
      'purchase_id': recordJson(_purchaseId, {'purchase_date': date}),
      'product_id': recordJson(
        _productId,
        {'product_registration_id': _registrationId},
        expand: {
          'product_registration_id': recordJson(
            _registrationId,
            {'product_type_id': _typeId},
            expand: {
              'product_type_id': recordJson(
                _typeId,
                {
                  'name': name,
                  'category_id': _categoryId,
                  'base_unit': baseUnit,
                  'active': typeActive,
                },
                expand: {
                  'category_id': recordJson(_categoryId, {
                    'name': 'Mercearia',
                    'active': true,
                  }),
                },
              ),
            },
          ),
        },
      ),
    },
  );

  Map<String, dynamic> total(int count) => recordJson('total000000001', {
    'product_id': _productId,
    'purchase_count': count,
  });

  Map<String, dynamic> product() => recordJson(_productId, {
    'product_registration_id': _registrationId,
    'active': true,
  });

  Map<String, dynamic> registration({String brandId = ''}) =>
      recordJson(_registrationId, {
        'product_type_id': _typeId,
        'brand_id': brandId,
        'description': '',
        'selling_mode': 'by_weight',
        'active': true,
      });

  group('failures', () {
    test('translates the server error', () async {
      final repository = repositoryOf(MockClient((_) async => errorJson(400)));

      await expectLater(
        fetch(repository),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    });

    test('refuses without a session', () async {
      final repository = ConsumptionRepositoryRemote(
        testPocketBase(serving(), signedIn: false),
      );

      await expectLater(
        fetch(repository),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(requests, isEmpty);
    });

    test('a transport failure becomes a NetworkException', () async {
      final repository = repositoryOf(offlineClient());

      await expectLater(fetch(repository), throwsA(isA<NetworkException>()));
    });
  });

  group('fetchTypeConsumption', () {
    test('reads from the start of the older window, no upper bound', () async {
      final repository = repositoryOf(serving());

      await fetch(repository);

      expect(requests, hasLength(4));
      expect(
        requests.map((r) => r.url.pathSegments[2]),
        unorderedEquals([
          'purchase_item',
          'purchase_item_totals',
          'product',
          'product_registration',
        ]),
      );
      final items = requests.firstWhere(
        (r) => r.url.pathSegments[2] == 'purchase_item',
      );
      final filter = items.url.queryParameters['filter']!;
      expect(
        filter,
        contains('purchase_id.purchase_date >= "2026-05-01 00:00:00.000Z"'),
      );
      expect(filter, isNot(contains('<=')));
      final expand = items.url.queryParameters['expand']!;
      expect(expand, contains('purchase_id'));
      expect(
        expand,
        contains(
          'product_id.product_registration_id.product_type_id.category_id',
        ),
      );
    });

    test('a purchase before the read start comes from the history', () async {
      final repository = repositoryOf(
        serving(
          items: [item(date: '2026-06-10 00:00:00.000Z', quantity: 2000)],
          totals: [total(2)],
          products: [product()],
          registrations: [registration()],
        ),
      );

      final lines = await fetch(repository);

      final line = lines.single;
      expect(line.type.name, 'Café');
      expect(line.type.baseUnit, BaseUnit.gram);
      expect(line.category.name, 'Mercearia');
      expect(line.consumedInWindow, 2000);
      expect(line.consumedInMonth, 0);
      expect(line.firstPurchaseOn, DateTime(2026, 4, 30));
    });

    test(
      'a history equal to the lines read starts at the first line',
      () async {
        final repository = repositoryOf(
          serving(
            items: [item(date: '2026-06-10 00:00:00.000Z', quantity: 2000)],
            totals: [total(1)],
            products: [product()],
            registrations: [registration()],
          ),
        );

        final lines = await fetch(repository);

        expect(lines.single.firstPurchaseOn, DateTime(2026, 6, 10));
      },
    );

    test('a purchase of the current month', () async {
      final repository = repositoryOf(
        serving(
          items: [
            item(
              date: '2026-08-10 00:00:00.000Z',
              quantity: 3000,
              name: 'Iogurte',
              baseUnit: 'milliliter',
            ),
          ],
          totals: [total(1)],
          products: [product()],
          registrations: [registration()],
        ),
      );

      final lines = await fetch(repository);

      expect(lines.single.consumedInWindow, 0);
      expect(lines.single.consumedInMonth, 3000);
      expect(lines.single.firstPurchaseOn, DateTime(2026, 8, 10));
    });

    test('a deactivated type stays in the answer, flagged', () async {
      final repository = repositoryOf(
        serving(
          items: [
            item(
              date: '2026-05-12 00:00:00.000Z',
              quantity: 3000,
              typeActive: false,
            ),
          ],
          totals: [total(1)],
          products: [product()],
          registrations: [registration()],
        ),
      );

      final lines = await fetch(repository);

      expect(lines.single.type.active, isFalse);
    });

    test('no purchase at all is an empty list', () async {
      final repository = repositoryOf(serving());

      expect((await fetch(repository)).isEmpty, isTrue);
    });

    test('a registration without brand does not throw', () async {
      final repository = repositoryOf(
        serving(
          items: [item(date: '2026-06-10 00:00:00.000Z', quantity: 2000)],
          totals: [total(2)],
          products: [product()],
          registrations: [registration(brandId: '')],
        ),
      );

      final lines = await fetch(repository);

      expect(lines.single.firstPurchaseOn, DateTime(2026, 4, 30));
    });
  });
}
