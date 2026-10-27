import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/purchase_count.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/type_consumption.dart';
import '../../../domain/models/type_consumption_build.dart';
import '../../services/pb_schema.dart';
import '../../services/pocketbase_error.dart';
import 'consumption_repository.dart';

const _expandKey = 'expand';

/// The real thing. The client is PRIVATE: the UI never reaches it.
final class ConsumptionRepositoryRemote implements ConsumptionRepository {
  ConsumptionRepositoryRemote(this._pb);

  final PocketBase _pb;

  @override
  Future<IList<TypeConsumption>> fetchTypeConsumption({
    required ReportPeriod window,
    required ReportPeriod month,
  }) async {
    try {
      requireSession(_pb);
      // The dates come from the ViewModel, off the phone's clock. The only day
      // used here is the start of the older interval, and it is the domain's.
      final start = consumptionReadStart(window: window, month: month);

      // Four reads in parallel. No upper bound on the date: the rule of the
      // first purchase counts EVERY line read of the type. No ordering and no
      // filtering here: whoever orders is `groupAveragesByCategory` and
      // whoever drops the deactivated type is `monthlyAverages` — both in the
      // domain (rule 3 and decision E-e).
      final results = await Future.wait([
        _pb
            .collection(PbCollections.purchaseItem)
            .getFullList(
              filter: _pb.filter(
                '${PbFields.purchaseId}.${PbFields.purchaseDate} >= {:start}',
                {'start': encodeStoredDay(start)},
              ),
              expand:
                  '${PbFields.purchaseId},'
                  '${PbFields.productId}.${PbFields.productRegistrationId}'
                  '.${PbFields.productTypeId}.${PbFields.categoryId}',
            ),
        _pb.collection(PbCollections.purchaseItemTotals).getFullList(),
        _pb.collection(PbCollections.product).getFullList(),
        _pb.collection(PbCollections.productRegistration).getFullList(),
      ]);
      final items = results[0];
      final totals = results[1];
      final products = results[2];
      final registrations = results[3];

      final allTimeCountByType = purchaseCountsByType(
        products: [
          for (final r in products) Product.fromJson(_readRow(r)),
        ].toIList(),
        registrations: [
          for (final r in registrations)
            ProductRegistration.fromJson(_readRow(r)),
        ].toIList(),
        countByProduct: {
          for (final r in totals)
            r.data[PbFields.productId] as String:
                (r.data[PbFields.purchaseCount] as num).toInt(),
        }.lock,
      );

      return buildTypeConsumption(
        windowLines: items.map(_consumptionLineOf).toIList(),
        allTimeCountByType: allTimeCountByType,
        window: window,
        month: month,
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}

ConsumptionLine _consumptionLineOf(RecordModel item) {
  final purchase = _one(item.data, PbFields.purchaseId);
  final product = _one(item.data, PbFields.productId);
  final typeRow = _one(
    _one(product, PbFields.productRegistrationId),
    PbFields.productTypeId,
  );
  final categoryRow = _one(typeRow, PbFields.categoryId);
  return ConsumptionLine(
    type: ProductType.fromJson(_rowOfMap(typeRow)),
    category: Category.fromJson(_rowOfMap(categoryRow)),
    purchaseDate: decodeStoredDay(purchase[PbFields.purchaseDate] as String),
    quantityInBaseUnit: (item.data[PbFields.quantityInBaseUnit] as num).toInt(),
  );
}

/// `{...data, id}`; the entities read an absent brand as null, PocketBase `""`.
Map<String, dynamic> _readRow(RecordModel r) =>
    _rowOfMap({...r.data, PbFields.id: r.id});

Map<String, dynamic> _rowOfMap(Map<String, dynamic> data) {
  final row = {...data}..remove(_expandKey);
  if (row[PbFields.brandId] == '') row[PbFields.brandId] = null;
  return row;
}

Map<String, dynamic> _one(Map<String, dynamic> row, String field) {
  final value = (row[_expandKey] as Map<String, dynamic>?)?[field];
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty) {
    return value.first as Map<String, dynamic>;
  }
  throw StateError('Missing expand "$field" in the response.');
}
