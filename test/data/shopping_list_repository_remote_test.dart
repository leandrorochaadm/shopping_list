import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/pending_changes.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// The channel is stubbed only enough for `watchChanges()` to hand back its
/// stream: nothing here exercises the Realtime wiring, which belongs to
/// `supabase_flutter`. The two callbacks are `@visibleForTesting` precisely so
/// the RULES can be tested without capturing the `callback:` argument.
class _MockChannel extends Mock implements RealtimeChannel {}

PostgresChangePayload _payload(
  PostgresChangeEvent event, {
  String? id = 'item-1',
}) => PostgresChangePayload(
  schema: 'public',
  table: 'shopping_list_item',
  commitTimestamp: DateTime(2026, 8, 28),
  eventType: event,
  // A DELETE brings only the primary key, and in oldRecord.
  newRecord: event == PostgresChangeEvent.delete ? const {} : {'id': ?id},
  oldRecord: event == PostgresChangeEvent.delete ? {'id': ?id} : const {},
  errors: null,
);

ShoppingListItem _item({String? id = 'item-1'}) => ShoppingListItem(
  id: id,
  type: ProductType(
    id: 'type-1',
    name: 'Leite',
    categoryId: 'cat-1',
    baseUnit: BaseUnit.liter,
  ),
  category: Category(id: 'cat-1', name: 'Bebidas'),
  enteredOn: DateTime(2026, 8, 28),
);

void main() {
  setUpAll(() {
    registerFallbackValue(PostgresChangeEvent.all);
    registerFallbackValue((PostgresChangePayload _) {});
  });

  late _MockClient client;
  late _MockChannel channel;
  late ShoppingListRepositoryRemote repository;

  setUp(() {
    client = _MockClient();
    channel = _MockChannel();
    repository = ShoppingListRepositoryRemote(client);

    // The failure is raised at the first hop of every chain, which is where a
    // real PostgrestException would surface anyway.
    when(() => client.from(any())).thenThrow(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );

    when(() => client.channel(any())).thenReturn(channel);
    when(
      () => channel.onPostgresChanges(
        event: any(named: 'event'),
        schema: any(named: 'schema'),
        table: any(named: 'table'),
        callback: any(named: 'callback'),
      ),
    ).thenReturn(channel);
    when(() => channel.subscribe(any(), any())).thenReturn(channel);
    when(channel.unsubscribe).thenAnswer((_) async => 'ok');
  });

  group('every method translates the SQLSTATE instead of leaking it', () {
    // Without this the 23505 arrives as "status 23505", falls into the >= 500
    // arm of AppFailure and tells the user the server is down.
    test('fetchAll', () {
      expect(repository.fetchAll, throwsA(_is409));
    });

    test('add', () {
      expect(() => repository.add(_item()), throwsA(_is409));
    });

    test('update', () {
      expect(() => repository.update(_item()), throwsA(_is409));
    });

    test('remove', () {
      expect(() => repository.remove('item-1'), throwsA(_is409));
    });
  });

  group('the channel', () {
    test('an INSERT from the other phone is a new item', () async {
      // Listen FIRST: the controller is a broadcast one, and it drops what it
      // receives while nobody is on the other end.
      final seen = <ListChangeKind>[];
      repository.watchChanges().listen(seen.add);

      repository.onChange(_payload(PostgresChangeEvent.insert, id: 'other'));
      await Future<void>.delayed(Duration.zero);

      expect(seen, [ListChangeKind.added]);
    });

    test('an UPDATE and a DELETE are just a change', () async {
      final seen = <ListChangeKind>[];
      repository.watchChanges().listen(seen.add);

      repository
        ..onChange(_payload(PostgresChangeEvent.update, id: 'other'))
        ..onChange(_payload(PostgresChangeEvent.delete, id: 'other'));
      await Future<void>.delayed(Duration.zero);

      expect(seen, [ListChangeKind.changed, ListChangeKind.changed]);
    });

    test('a payload with no id at all still counts', () async {
      final seen = <ListChangeKind>[];
      repository.watchChanges().listen(seen.add);

      repository.onChange(_payload(PostgresChangeEvent.insert, id: null));
      await Future<void>.delayed(Duration.zero);

      expect(seen, [ListChangeKind.added]);
    });

    test('the echo of OUR OWN write says nothing', () async {
      // D2 — without this discard, adding an item shows "1 item novo" to
      // whoever has just added it.
      final seen = <ListChangeKind>[];
      repository.watchChanges().listen(seen.add);

      // The write registers the echo BEFORE its await, so the failure of the
      // I/O afterwards does not matter here.
      await expectLater(() => repository.add(_item()), throwsA(_is409));
      repository.onChange(_payload(PostgresChangeEvent.insert));
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });

    test('two writes to the same row swallow two echoes', () async {
      // THE test that fails if the counter goes back to being a Set: two taps
      // on the same checkbox are two writes to one row, a Set would hold one
      // entry, and the second echo would become a banner about the change the
      // person has just made.
      final seen = <ListChangeKind>[];
      repository.watchChanges().listen(seen.add);

      await expectLater(() => repository.update(_item()), throwsA(_is409));
      await expectLater(() => repository.update(_item()), throwsA(_is409));
      repository
        ..onChange(_payload(PostgresChangeEvent.update))
        ..onChange(_payload(PostgresChangeEvent.update));
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);

      // And the third one, which nobody here wrote, comes through.
      repository.onChange(_payload(PostgresChangeEvent.update));
      await Future<void>.delayed(Duration.zero);
      expect(seen, [ListChangeKind.changed]);
    });

    test('a row this phone never wrote comes through', () async {
      final seen = <ListChangeKind>[];
      repository.watchChanges().listen(seen.add);

      await expectLater(() => repository.remove('item-1'), throwsA(_is409));
      repository.onChange(_payload(PostgresChangeEvent.delete, id: 'other'));
      await Future<void>.delayed(Duration.zero);

      expect(seen, [ListChangeKind.changed]);
    });

    test('coming back after a drop says the list changed', () async {
      // D1 — a channel failure is silence; what becomes an event is coming
      // BACK, because anything could have changed while it was down.
      final seen = <ListChangeKind>[];
      repository.watchChanges().listen(seen.add);

      repository.onStatus(RealtimeSubscribeStatus.subscribed, null);
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty, reason: 'the first subscribe is not a change');

      repository.onStatus(RealtimeSubscribeStatus.channelError, 'boom');
      repository.onStatus(RealtimeSubscribeStatus.subscribed, null);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [ListChangeKind.changed]);
    });

    test('reopening the screen does not invent a change', () async {
      // `_closeChannel` zeroes the flag, so the next `subscribed` is a first
      // one again — otherwise the list opens saying "a lista mudou" over
      // nothing.
      final subscription = repository.watchChanges().listen((_) {});
      repository.onStatus(RealtimeSubscribeStatus.subscribed, null);
      await subscription.cancel();

      final seen = <ListChangeKind>[];
      repository.watchChanges().listen(seen.add);
      repository.onStatus(RealtimeSubscribeStatus.subscribed, null);
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });

    test('shares one channel across listeners', () {
      repository.watchChanges().listen((_) {});
      repository.watchChanges().listen((_) {});

      verify(() => client.channel('shopping_list_item')).called(1);
    });
  });
}

/// 409, never 23505 read as a number.
final _is409 = isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409);
