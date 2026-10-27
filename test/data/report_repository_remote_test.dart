import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/repositories/report/report_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/period_report.dart';
import 'package:shopping_list/domain/models/report_period.dart';

import '../helpers/pocketbase_test_client.dart';

const _purchaseId = 'purch0000000001';
const _categoryId = 'cat000000000001';
const _typeId = 'type00000000001';
const _brandId = 'brand0000000001';

final _period = ReportPeriod(
  from: DateTime(2026, 8, 1),
  to: DateTime(2026, 8, 31),
);

void main() {
  late List<http.Request> requests;

  MockClient recording(http.Response Function(http.Request) handler) =>
      MockClient((request) async {
        requests.add(request);
        return handler(request);
      });

  setUp(() => requests = []);

  Map<String, dynamic> category() =>
      recordJson(_categoryId, {'name': 'Carnes', 'active': true});

  Map<String, dynamic> type({
    String id = _typeId,
    String name = 'Acém',
    String baseUnit = 'gram',
  }) => recordJson(
    id,
    {
      'name': name,
      'category_id': _categoryId,
      'base_unit': baseUnit,
      'active': true,
    },
    expand: {'category_id': category()},
  );

  Map<String, dynamic> item({
    required String id,
    required int paid,
    required int quantity,
    Map<String, dynamic>? typeRecord,
    Map<String, dynamic>? brand,
  }) => recordJson(
    id,
    {
      'purchase_id': _purchaseId,
      'product_id': 'prod00000000001',
      'quantity_in_base_unit': quantity,
      'total_paid': paid,
    },
    expand: {
      'product_id': recordJson(
        'prod00000000001',
        {'product_registration_id': 'reg000000000001', 'active': true},
        expand: {
          'product_registration_id': recordJson(
            'reg000000000001',
            {
              'product_type_id': _typeId,
              'brand_id': brand == null ? '' : _brandId,
              'description': '',
              'selling_mode': 'by_weight',
              'active': true,
            },
            expand: {
              'product_type_id': typeRecord ?? type(),
              'brand_id': ?brand,
            },
          ),
        },
      ),
    },
  );

  Map<String, dynamic> quote({String brandId = _brandId}) => recordJson(
    'item00000000001',
    {
      'purchase_id': _purchaseId,
      'product_id': 'prod00000000002',
      'quantity_in_base_unit': 4200,
      'total_paid': 4800,
    },
    expand: {
      'purchase_id': recordJson(
        _purchaseId,
        {
          'purchase_date': '2026-07-03 00:00:00.000Z',
          'store_id': 'store0000000003',
        },
        expand: {
          'store_id': recordJson('store0000000003', {
            'name': 'Mercearia do Zé',
            'active': false,
          }),
        },
      ),
      'product_id': recordJson(
        'prod00000000002',
        {
          'product_registration_id': 'reg000000000002',
          'piece_count': 12,
          'piece_size': 350,
          'piece_size_unit': 'milliliter',
          'total_content': 4200,
          'active': true,
        },
        expand: {
          'product_registration_id': recordJson(
            'reg000000000002',
            {
              'product_type_id': 'type00000000002',
              'brand_id': brandId,
              'description': '',
              'selling_mode': 'by_piece',
              'active': true,
            },
            expand: {
              'product_type_id': recordJson(
                'type00000000002',
                {
                  'name': 'Refrigerante',
                  'category_id': 'cat000000000002',
                  'base_unit': 'milliliter',
                  'active': true,
                },
                expand: {
                  'category_id': recordJson('cat000000000002', {
                    'name': 'Bebidas',
                    'active': true,
                  }),
                },
              ),
              if (brandId.isNotEmpty)
                'brand_id': recordJson(brandId, {
                  'name': 'Coca-Cola',
                  'active': true,
                }),
            },
          ),
        },
      ),
    },
  );

  group('failures', () {
    test('both methods translate the server error', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(recording((_) => errorJson(400))),
      );

      for (final call in [
        () => repository.fetchPeriodReport(_period),
        () => repository.fetchPriceQuotes(DateTime(2026, 5, 30)),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
      }
    });

    test('both methods refuse without a session', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(recording((_) => listJson([])), signedIn: false),
      );

      for (final call in [
        () => repository.fetchPeriodReport(_period),
        () => repository.fetchPriceQuotes(DateTime(2026, 5, 30)),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 401),
          ),
        );
      }
      expect(requests, isEmpty);
    });

    test('a transport failure becomes NetworkException', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(offlineClient()),
      );

      await expectLater(
        repository.fetchPeriodReport(_period),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(
        repository.fetchPriceQuotes(DateTime(2026, 5, 30)),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('fetchPeriodReport', () {
    test('sends the interval as two calendar days', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(recording((_) => listJson([]))),
      );

      await repository.fetchPeriodReport(_period);

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/api/collections/purchase_item/records');
      final filter = request.url.queryParameters['filter']!;
      expect(
        filter,
        contains('purchase_id.purchase_date >= "2026-08-01 00:00:00.000Z"'),
      );
      expect(
        filter,
        contains('purchase_id.purchase_date <= "2026-08-31 00:00:00.000Z"'),
      );
      final expand = request.url.queryParameters['expand']!;
      expect(
        expand,
        contains(
          'product_id.product_registration_id.product_type_id.category_id',
        ),
      );
      expect(expand, contains('product_id.product_registration_id.brand_id'));
    });

    test('adds up the period from the lines', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(
          recording(
            (_) => listJson([
              item(id: 'item00000000001', paid: 15000, quantity: 5000),
              item(id: 'item00000000002', paid: 4200, quantity: 1000),
            ]),
          ),
        ),
      );

      final report = await repository.fetchPeriodReport(_period);

      expect(report.total, const Money(19200));
      expect(report.types.single.baseUnit, BaseUnit.gram);
      expect(report.types.single.costPerBaseUnit, 3200);
      expect(report.brands.single.hasBrand, isFalse);
    });

    test('reads the brand from the expand', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(
          recording(
            (_) => listJson([
              item(
                id: 'item00000000001',
                paid: 8600,
                quantity: 4300,
                brand: recordJson(_brandId, {'name': 'Omo', 'active': true}),
              ),
            ]),
          ),
        ),
      );

      final report = await repository.fetchPeriodReport(_period);

      expect(report.brands.single.brandId, _brandId);
      expect(report.brands.single.name, 'Omo');
      expect(report.brands.single.quantityInBaseUnit, 4300);
      expect(report.brands.single.spent, const Money(8600));
    });

    test('an empty period is a value, not an error', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(recording((_) => listJson([]))),
      );

      final report = await repository.fetchPeriodReport(_period);

      expect(report.isEmpty, isTrue);
      expect(report, PeriodReport.empty);
    });
  });

  group('fetchPriceQuotes', () {
    test('reads the leaf, the category and the store', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(recording((_) => listJson([quote()]))),
      );

      final quotes = await repository.fetchPriceQuotes(DateTime(2026, 5, 30));

      final request = requests.single;
      final filter = request.url.queryParameters['filter']!;
      expect(
        filter,
        contains('purchase_id.purchase_date >= "2026-05-30 00:00:00.000Z"'),
      );
      expect(filter, isNot(contains('<=')));
      expect(
        request.url.queryParameters['expand'],
        contains('purchase_id.store_id'),
      );
      final line = quotes.single;
      expect(line.option.label, 'Coca-Cola 12 × 350 ml');
      expect(line.categoryId, 'cat000000000002');
      expect(line.categoryName, 'Bebidas');
      expect(line.store.active, isFalse);
      expect(line.price.paid, const Money(4800));
      expect(line.price.purchasedOn, DateTime(2026, 7, 3));
      expect(line.costPerBaseUnit, 1143);
      expect(line.option.purchaseCount, 0);
      expect(line.option.baseline, isNull);
    });

    test('a registration without brand has no brand', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(recording((_) => listJson([quote(brandId: '')]))),
      );

      final quotes = await repository.fetchPriceQuotes(DateTime(2026, 5, 30));

      expect(quotes.single.option.brand, isNull);
      expect(quotes.single.option.registration.brandId, isNull);
    });

    test('no quotes is an empty list', () async {
      final repository = ReportRepositoryRemote(
        testPocketBase(recording((_) => listJson([]))),
      );

      expect(
        (await repository.fetchPriceQuotes(DateTime(2026, 5, 30))).isEmpty,
        isTrue,
      );
    });
  });
}
