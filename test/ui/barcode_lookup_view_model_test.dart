import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/barcode_owner.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/scale_label.dart';
import 'package:shopping_list/ui/barcode/view_model/barcode_lookup_view_model.dart';
import 'package:shopping_list/ui/core/error_translation.dart';
import 'package:shopping_list/ui/core/app_failure.dart';

/// The `_local` fake with a switch that makes the next call fail — no
/// mocktail.
class _SpyCatalog extends CatalogRepositoryLocal {
  _SpyCatalog() : super(latency: Duration.zero);

  Object? failNextCall;
  int findOwnersCalls = 0;
  int addScaleCodeCalls = 0;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<IMap<Barcode, BarcodeOwner>> findOwners(IList<Barcode> codes) async {
    findOwnersCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.findOwners(codes);
  }

  @override
  Future<void> addScaleCode({
    required String productId,
    required ScaleCode code,
  }) async {
    addScaleCodeCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.addScaleCode(productId: productId, code: code);
  }
}

void main() {
  const scaleCode = ScaleCode(storeId: 'store-1', itemCode: '2822521');
  final milk = Barcode.typed('7894900011517');

  late _SpyCatalog repository;
  late ProviderContainer container;
  late BarcodeLookupViewModel vm;

  final byPiece = ProductRegistration(
    id: 'reg-1',
    productTypeId: 'type-1',
    sellingMode: SellingMode.byPiece,
  );
  final byWeight = ProductRegistration(
    id: 'reg-2',
    productTypeId: 'type-2',
    sellingMode: SellingMode.byWeight,
  );

  setUp(() {
    repository = _SpyCatalog();
    container = ProviderContainer.test(
      overrides: <Override>[
        catalogRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    vm = container.read(barcodeLookupViewModelProvider.notifier);
  });

  group('lookUp', () {
    test('finds the active owner', () async {
      await repository.addBarcode(productId: 'prod-1', code: milk);

      final outcome = await vm.lookUp('7894900011517');

      expect(outcome, isA<BarcodeFound>());
      expect((outcome! as BarcodeFound).owner.product.id, 'prod-1');
    });

    test('treats a deactivated owner as unknown', () async {
      await repository.addBarcode(productId: 'prod-1', code: milk);
      final leaf = (await repository.fetchProducts()).firstWhere(
        (p) => p.id == 'prod-1',
      );
      await repository.updateProduct(leaf.deactivated());

      final outcome = await vm.lookUp('7894900011517');

      expect(outcome, isA<BarcodeUnknown>());
      expect((outcome! as BarcodeUnknown).code, milk);
    });

    test('returns unknown with the code when nobody holds it', () async {
      final outcome = await vm.lookUp('7894900011517');

      expect((outcome! as BarcodeUnknown).code, Barcode.typed('7894900011517'));
    });

    test('rejects the scale label QR and its EAN-13', () async {
      expect(
        await vm.lookUp('02822521001605261107'),
        isA<ScaleLabelRejected>(),
      );
      expect(await vm.lookUp('2822521001605'), isA<ScaleLabelRejected>());
      expect(repository.findOwnersCalls, 0);
    });

    test('rejects an in-store UPC-A', () async {
      expect(await vm.lookUp('212345678909'), isA<ScaleLabelRejected>());
      expect(repository.findOwnersCalls, 0);
    });

    test('answers an invalid code with the sentence', () async {
      final outcome = await vm.lookUp('7894900011518');

      expect(
        outcome,
        isA<BarcodeLookupFailed>().having(
          (o) => o.message,
          'message',
          'Código de barras inválido.',
        ),
      );
      expect(repository.findOwnersCalls, 0);
    });

    test('translates a failure', () async {
      repository.failNextCall = ApiException(503, 'down');

      final outcome = await vm.lookUp('7894900011517');

      final message = (outcome! as BarcodeLookupFailed).message;
      expect(
        message,
        translateFailure(const ServerUnavailable(), 'procurar o código'),
      );
      expect(message, isNot(contains('down')));
    });

    test('guards against double tap', () async {
      final outcomes = await Future.wait([
        vm.lookUp('7894900011517'),
        vm.lookUp('7894900011517'),
      ]);

      expect(outcomes.where((o) => o == null), hasLength(1));
      expect(repository.findOwnersCalls, 1);
    });
  });

  group('linkScaleCode', () {
    test('writes the code', () async {
      final result = await vm.linkScaleCode(
        registration: byWeight,
        productId: 'prod-5',
        code: scaleCode,
      );

      expect(result, isNull);
      final leaf = (await repository.fetchProducts()).firstWhere(
        (p) => p.id == 'prod-5',
      );
      expect(leaf.scaleCodes, [scaleCode].lock);
    });

    test('refuses a code taken in the same store', () async {
      await repository.addScaleCode(productId: 'prod-5', code: scaleCode);

      final result = await vm.linkScaleCode(
        registration: byWeight,
        productId: 'prod-1',
        code: scaleCode,
      );

      expect(result, ScaleCode.takenMessage);
    });

    test('refuses a product sold by piece', () async {
      final result = await vm.linkScaleCode(
        registration: byPiece,
        productId: 'prod-1',
        code: scaleCode,
      );

      expect(result, 'Só produto vendido solto tem código de balança.');
      expect(repository.addScaleCodeCalls, 0);
    });

    test('translates a failure', () async {
      repository.failNextCall = ApiException(503, 'down');

      final result = await vm.linkScaleCode(
        registration: byWeight,
        productId: 'prod-5',
        code: scaleCode,
      );

      expect(
        result,
        translateFailure(
          const ServerUnavailable(),
          'ligar a etiqueta ao produto',
        ),
      );
    });

    test('guards against double tap', () async {
      final results = await Future.wait([
        vm.linkScaleCode(
          registration: byWeight,
          productId: 'prod-5',
          code: scaleCode,
        ),
        vm.linkScaleCode(
          registration: byWeight,
          productId: 'prod-5',
          code: scaleCode,
        ),
      ]);

      expect(results, [null, null]);
      expect(repository.addScaleCodeCalls, 1);
    });
  });
}
