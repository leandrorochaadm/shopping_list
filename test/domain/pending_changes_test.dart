import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/pending_changes.dart';

void main() {
  group('PendingChanges', () {
    test('says nothing when nothing arrived', () {
      expect(PendingChanges.none.isEmpty, isTrue);
      expect(PendingChanges.none.label, isNull);
    });

    test('counts new items, in the singular and in the plural', () {
      final one = PendingChanges.none.plus(ListChangeKind.added);
      final two = one.plus(ListChangeKind.added);

      expect(one.label, '1 item novo — atualizar');
      expect(two.label, '2 itens novos — atualizar');
      expect(two.addedCount, 2);
    });

    test('a change that is not an addition reads as a change', () {
      final changed = PendingChanges.none.plus(ListChangeKind.changed);

      expect(changed.label, 'A lista mudou — tocar para ver');
      expect(changed.isEmpty, isFalse);
    });

    test('a removal alongside two additions drops the count', () {
      // The number would not be delivered: two of the lines are new, but one
      // that was there is gone, and "2 itens novos" promises the wrong thing.
      final mixed = PendingChanges.none
          .plus(ListChangeKind.added)
          .plus(ListChangeKind.added)
          .plus(ListChangeKind.changed);

      expect(mixed.label, 'A lista mudou — tocar para ver');
      expect(mixed.addedCount, 2);
    });

    test('compares by both fields — the banner must not repaint for free', () {
      expect(
        const PendingChanges(addedCount: 2),
        const PendingChanges(addedCount: 2),
      );
      expect(
        const PendingChanges(addedCount: 2).hashCode,
        const PendingChanges(addedCount: 2).hashCode,
      );
      expect(
        const PendingChanges(addedCount: 2),
        isNot(const PendingChanges(addedCount: 2, hasOtherChanges: true)),
      );
      expect(PendingChanges.none, isNot(const PendingChanges(addedCount: 1)));
    });

    test('names itself in a log line', () {
      expect(PendingChanges.none.toString(), contains('PendingChanges'));
    });
  });
}
