import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/scale_label.dart';
import 'package:shopping_list/domain/models/scan_resolution.dart';

import '../helpers/purchase.dart';

void main() {
  const eanRaw = '7894900011517';
  const scaleRaw = '2822521001605';
  const scaleQr = '02822521001605261107';
  const itemCode = '2822521';
  const store1 = ScaleCode(storeId: 'store-1', itemCode: itemCode);
  const store2 = ScaleCode(storeId: 'store-2', itemCode: itemCode);

  final packaged = optionByPiece(
    id: 'a',
    barcodes: [Barcode.typed(eanRaw)].lock,
  );
  final other = optionByPiece(id: 'b');
  final weighed1 = optionByWeight(id: 'w1', scaleCodes: [store1].lock);
  final weighed2 = optionByWeight(id: 'w2', scaleCodes: [store2].lock);

  group('packaging codes', () {
    test('a known EAN gives the match', () {
      expect(
        resolveScan(eanRaw, [other, packaged].lock),
        PackagingMatch(option: packaged),
      );
    });

    test('a valid EAN with no owner gives NoMatch with the barcode', () {
      expect(
        resolveScan(eanRaw, [other].lock),
        NoMatch(code: Barcode.typed(eanRaw)),
      );
    });

    test('a UPC-A finds the leaf saved as the EAN-13', () {
      final ean = optionByPiece(
        id: 'c',
        barcodes: [Barcode.typed('0012345678905')].lock,
      );
      expect(
        resolveScan('012345678905', [other, ean].lock),
        PackagingMatch(option: ean),
      );
    });
  });

  group('scale labels', () {
    test('a linked label with a chosen store gives ScaleMatch', () {
      expect(
        resolveScan(scaleRaw, [weighed1].lock, storeId: 'store-1'),
        ScaleMatch(option: weighed1, storeId: 'store-1', quantity: 160),
      );
    });

    test('the 20-digit QR gives the same', () {
      expect(
        resolveScan(scaleQr, [weighed1].lock, storeId: 'store-1'),
        resolveScan(scaleRaw, [weighed1].lock, storeId: 'store-1'),
      );
    });

    test('a weight leaf of a type without gram has no quantity', () {
      final liquid = optionByWeight(
        id: 'l',
        type: softDrinkType,
        scaleCodes: [store1].lock,
      );
      expect(
        resolveScan(scaleRaw, [liquid].lock, storeId: 'store-1'),
        ScaleMatch(option: liquid, storeId: 'store-1', quantity: null),
      );
    });

    test('a by-piece leaf of a gram type has no quantity', () {
      final powder = optionByPiece(
        id: 'p',
        type: powderType,
        unit: BaseUnit.gram,
        pieceSize: 1000,
        scaleCodes: [store1].lock,
      );
      expect(
        resolveScan(scaleRaw, [powder].lock, storeId: 'store-1'),
        ScaleMatch(option: powder, storeId: 'store-1', quantity: null),
      );
    });

    test('without a store and with one store found, uses that store', () {
      expect(
        resolveScan(scaleRaw, [other, weighed2].lock),
        ScaleMatch(option: weighed2, storeId: 'store-2', quantity: 160),
      );
    });

    test('two leaves in two stores give ScaleInManyStores, in order', () {
      const expected = ScaleInManyStores(
        itemCode: itemCode,
        storeIds: IListConst(['store-1', 'store-2']),
      );
      expect(resolveScan(scaleRaw, [weighed1, weighed2].lock), expected);
      expect(resolveScan(scaleRaw, [weighed2, weighed1].lock), expected);
    });

    test('the SAME leaf in two stores gives ScaleInManyStores', () {
      final both = optionByWeight(id: 'w', scaleCodes: [store2, store1].lock);
      expect(
        resolveScan(scaleRaw, [both].lock),
        ScaleInManyStores(
          itemCode: itemCode,
          storeIds: ['store-1', 'store-2'].lock,
        ),
      );
    });

    test('a code only in another store gives ScaleUnlinked', () {
      expect(
        resolveScan(scaleRaw, [weighed2].lock, storeId: 'store-1'),
        const ScaleUnlinked(itemCode: itemCode, weightInGrams: 160),
      );
    });

    test('a label with no owner gives ScaleUnlinked', () {
      expect(
        resolveScan(scaleRaw, [other].lock),
        const ScaleUnlinked(itemCode: itemCode, weightInGrams: 160),
      );
    });
  });

  group('rejections', () {
    final options = [packaged].lock;

    test('a scale UPC-A is an unknown label', () {
      expect(resolveScan('212345678909', options), const UnknownLabel());
    });

    test('a zero weight is an unknown label', () {
      expect(resolveScan('2822521000004', options), const UnknownLabel());
    });

    test('garbage is invalid', () {
      expect(resolveScan('abc', options), const InvalidScan());
      expect(resolveScan('', options), const InvalidScan());
    });

    test('a wrong check digit is invalid', () {
      expect(resolveScan('2822521001606', options), const InvalidScan());
      expect(resolveScan('7894900011518', options), const InvalidScan());
    });
  });

  group('== and hashCode', () {
    void same(Object a, Object b) {
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    }

    test('PackagingMatch', () {
      same(PackagingMatch(option: packaged), PackagingMatch(option: packaged));
      expect(
        PackagingMatch(option: packaged),
        isNot(PackagingMatch(option: other)),
      );
    });

    test('ScaleMatch', () {
      ScaleMatch make({String id = 'store-1', int? quantity = 160}) =>
          ScaleMatch(option: weighed1, storeId: id, quantity: quantity);
      same(make(), make());
      expect(
        make(),
        isNot(ScaleMatch(option: weighed2, storeId: 'store-1', quantity: 160)),
      );
      expect(make(), isNot(make(id: 'store-2')));
      expect(make(), isNot(make(quantity: null)));
    });

    test('ScaleInManyStores', () {
      ScaleInManyStores make({String code = itemCode, List<String>? ids}) =>
          ScaleInManyStores(
            itemCode: code,
            storeIds: (ids ?? ['store-1', 'store-2']).lock,
          );
      same(make(), make());
      expect(make(), isNot(make(code: '2999999')));
      expect(make(), isNot(make(ids: ['store-2', 'store-1'])));
    });

    test('ScaleUnlinked', () {
      ScaleUnlinked make({String code = itemCode, int grams = 160}) =>
          ScaleUnlinked(itemCode: code, weightInGrams: grams);
      same(make(), make());
      expect(make(), isNot(make(code: '2999999')));
      expect(make(), isNot(make(grams: 161)));
    });

    test('NoMatch', () {
      same(
        NoMatch(code: Barcode.typed(eanRaw)),
        NoMatch(code: Barcode.typed(eanRaw)),
      );
      expect(
        NoMatch(code: Barcode.typed(eanRaw)),
        isNot(NoMatch(code: Barcode.typed('012345678905'))),
      );
    });

    test('the cases with no field', () {
      same(const UnknownLabel(), const UnknownLabel());
      same(const InvalidScan(), const InvalidScan());
      expect(const UnknownLabel(), isNot(const InvalidScan()));
    });

    test('toString names the case', () {
      expect(
        PackagingMatch(option: packaged).toString(),
        contains('PackagingMatch'),
      );
      expect(
        ScaleMatch(option: weighed1, storeId: 's', quantity: 1).toString(),
        contains('ScaleMatch'),
      );
      expect(
        ScaleInManyStores(itemCode: itemCode, storeIds: ['a'].lock).toString(),
        contains('ScaleInManyStores'),
      );
      expect(
        const ScaleUnlinked(itemCode: itemCode, weightInGrams: 1).toString(),
        contains('ScaleUnlinked'),
      );
      expect(
        NoMatch(code: Barcode.typed(eanRaw)).toString(),
        contains('NoMatch'),
      );
      expect(const UnknownLabel().toString(), 'UnknownLabel()');
      expect(const InvalidScan().toString(), 'InvalidScan()');
    });
  });
}
