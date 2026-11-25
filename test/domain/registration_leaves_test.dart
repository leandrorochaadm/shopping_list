import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/registration_leaves.dart';
import 'package:shopping_list/domain/models/scale_label.dart';

void main() {
  Packaging pack(int size) => Packaging(pieceCount: 1, pieceSize: size, baseUnit: BaseUnit.gram);

  Product loose({bool active = true, String id = 'loose'}) =>
      Product(id: id, productRegistrationId: 'reg-1', active: active);

  Product packed() => Product(id: 'pack', productRegistrationId: 'reg-1', packaging: pack(250));

  const code = ScaleCode(storeId: 'store-1', itemCode: '2822521');

  void check({
    IList<Packaging> packagings = const IList.empty(),
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
    IList<Product> existing = const IList.empty(),
  }) => checkNewLeaves(packagings: packagings, loose: loose, scaleCodes: scaleCodes, existing: existing);

  group('checkNewLeaves', () {
    test('accepts packagings without a loose leaf', () {
      expect(() => check(packagings: [pack(250), pack(500)].lock), returnsNormally);
    });

    test('accepts a loose-only save', () {
      expect(() => check(loose: true), returnsNormally);
    });

    test('refuses no packaging and no loose leaf', () {
      expect(() => check(), throwsA(isA<MissingPackaging>()));
    });

    test('refuses scale codes without the loose leaf', () {
      expect(() => check(packagings: [pack(250)].lock, scaleCodes: [code].lock), throwsA(isA<UnexpectedScaleCode>()));
    });

    test('accepts scale codes with the loose leaf', () {
      expect(() => check(loose: true, scaleCodes: [code].lock), returnsNormally);
    });

    test('refuses a second active loose leaf', () {
      expect(() => check(loose: true, existing: [loose()].lock), throwsA(isA<LooseAlreadyExists>()));
    });

    test('ignores a deactivated loose leaf', () {
      expect(() => check(loose: true, existing: [loose(active: false)].lock), returnsNormally);
    });

    test('accepts a packaging next to a saved loose leaf', () {
      expect(() => check(packagings: [pack(250)].lock, existing: [loose()].lock), returnsNormally);
    });

    test('accepts a loose leaf next to saved packagings', () {
      expect(() => check(loose: true, existing: [packed()].lock), returnsNormally);
    });

    test('allows a 1 kg packaging next to the loose leaf', () {
      expect(() => check(packagings: [pack(1000)].lock, loose: true), returnsNormally);
    });

    test('reports the missing packaging first', () {
      expect(() => check(scaleCodes: [code].lock), throwsA(isA<MissingPackaging>()));
    });
  });

  group('activeLooseOf', () {
    test('finds only the active loose leaf', () {
      expect(activeLooseOf(const IList.empty()), isNull);
      expect(activeLooseOf([packed()].lock), isNull);
      expect(activeLooseOf([loose(active: false)].lock), isNull);
      final active = loose(id: 'active');
      expect(activeLooseOf([loose(active: false), active].lock), active);
      expect(activeLooseOf([active].lock), active);
    });
  });

  group('LooseAlreadyExists', () {
    test('LooseAlreadyExists names itself', () {
      expect(const LooseAlreadyExists().toString(), 'LooseAlreadyExists: Esse produto já tem granel.');
    });
  });

  group('exceptions moved here', () {
    test('MissingPackaging carries its message', () {
      expect(const MissingPackaging().message, 'Informe ao menos uma embalagem para este produto.');
      expect(const MissingPackaging().toString(), startsWith('MissingPackaging: '));
    });

    test('UnexpectedScaleCode carries its message', () {
      expect(const UnexpectedScaleCode().message, 'Só o granel tem código de balança.');
      expect(const UnexpectedScaleCode().toString(), startsWith('UnexpectedScaleCode: '));
    });
  });
}
