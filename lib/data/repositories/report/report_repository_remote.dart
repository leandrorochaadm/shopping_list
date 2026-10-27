import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../domain/models/brand.dart';
import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/period_report.dart';
import '../../../domain/models/period_summary.dart';
import '../../../domain/models/price_quote.dart';
import '../../../domain/models/price_reference.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/store.dart';
import '../../services/pb_schema.dart';
import '../../services/pocketbase_error.dart';
import 'report_repository.dart';

// The keys of the nested map that `ProductOption.fromJson` reads. They are the
// entity's contract, not the collections' names.
const _registrationKey = 'product_registration';
const _typeKey = 'product_type';
const _brandKey = 'brand';

const _expandKey = 'expand';

// The date of the purchase, reached through the item's relation.
const _purchaseDate = '${PbFields.purchaseId}.${PbFields.purchaseDate}';

// Leaf -> registration -> type -> category, and the registration's brand.
const _registrationPath =
    '${PbFields.productId}.${PbFields.productRegistrationId}';
const _productExpand =
    '$_registrationPath.${PbFields.productTypeId}.${PbFields.categoryId},'
    '$_registrationPath.${PbFields.brandId}';
const _quoteExpand =
    '${PbFields.purchaseId}.${PbFields.storeId},$_productExpand';

/// The real thing. The client is PRIVATE: the UI never reaches it.
final class ReportRepositoryRemote implements ReportRepository {
  ReportRepositoryRemote(this._pb);

  final PocketBase _pb;

  @override
  Future<PeriodReport> fetchPeriodReport(ReportPeriod period) async {
    try {
      requireSession(_pb);
      // No `active` filter (requirement 16) and no owner filter: the
      // `listRule` already limits the list. Both ends are closed. No `sort`:
      // `summarizePeriod` adds up and the screen orders.
      final records = await _pb
          .collection(PbCollections.purchaseItem)
          .getFullList(
            filter: _pb.filter(
              '$_purchaseDate >= {:from} && '
              '$_purchaseDate <= {:to}',
              {
                'from': encodeStoredDay(period.from),
                'to': encodeStoredDay(period.to),
              },
            ),
            expand: _productExpand,
          );
      return summarizePeriod(records.map(_periodLineOf).toIList());
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<PriceQuote>> fetchPriceQuotes(DateTime since) async {
    try {
      requireSession(_pb);
      // No `active` filter: a leaf, a registration or a store deactivated
      // after the purchase stays in the report (requirement 16). No upper
      // bound and no `sort`: whoever orders is `buildComparison`, in Dart.
      final records = await _pb
          .collection(PbCollections.purchaseItem)
          .getFullList(
            filter: _pb.filter('$_purchaseDate >= {:since}', {
              'since': encodeStoredDay(since),
            }),
            expand: _quoteExpand,
          );
      return records.map(_quoteOf).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}

PeriodLine _periodLineOf(RecordModel item) {
  final product = _one(item.data, PbFields.productId);
  final registration = _one(product, PbFields.productRegistrationId);
  final typeRow = _one(registration, PbFields.productTypeId);
  final type = ProductType.fromJson(_rowOf(typeRow));
  final category = Category.fromJson(
    _rowOf(_one(typeRow, PbFields.categoryId)),
  );
  final brandRow = _oneOrNull(registration, PbFields.brandId);
  final brand = brandRow == null ? null : Brand.fromJson(_rowOf(brandRow));

  return PeriodLine(
    categoryId: category.id!,
    categoryName: category.name,
    productTypeId: type.id!,
    productTypeName: type.name,
    baseUnit: type.baseUnit,
    brandId: brand?.id,
    brandName: brand?.name,
    quantityInBaseUnit: (item.data[PbFields.quantityInBaseUnit] as num).toInt(),
    paid: Money.fromJson(item.data[PbFields.totalPaid]),
  );
}

PriceQuote _quoteOf(RecordModel item) {
  final purchase = _one(item.data, PbFields.purchaseId);
  final product = _one(item.data, PbFields.productId);
  final type = _one(
    _one(product, PbFields.productRegistrationId),
    PbFields.productTypeId,
  );
  final category = _one(type, PbFields.categoryId);

  return PriceQuote(
    option: _optionOf(product),
    categoryId: category[PbFields.id] as String,
    categoryName: category[PbFields.name] as String,
    store: Store.fromJson(_rowOf(_one(purchase, PbFields.storeId))),
    price: PriceReference(
      paid: Money.fromJson(item.data[PbFields.totalPaid]),
      quantityInBaseUnit: (item.data[PbFields.quantityInBaseUnit] as num)
          .toInt(),
      purchasedOn: decodeStoredDay(purchase[PbFields.purchaseDate] as String),
    ),
  );
}

/// A leaf expanded as `ProductOption.fromJson` expects. No barcodes (the
/// comparison never carried them) and no history.
ProductOption _optionOf(Map<String, dynamic> product) {
  final registration = _one(product, PbFields.productRegistrationId);
  final brand = _oneOrNull(registration, PbFields.brandId);
  return ProductOption.fromJson({
    ..._rowOf(product),
    _registrationKey: {
      ..._rowOf(registration),
      _typeKey: _rowOf(_one(registration, PbFields.productTypeId)),
      _brandKey: brand == null ? null : _rowOf(brand),
    },
  });
}

/// The row without its `expand`; an empty brand (`""`) is null.
Map<String, dynamic> _rowOf(Map<String, dynamic> data) {
  final row = {...data}..remove(_expandKey);
  if (row[PbFields.brandId] == '') row[PbFields.brandId] = null;
  return row;
}

Map<String, dynamic>? _oneOrNull(Map<String, dynamic> row, String field) {
  final value = (row[_expandKey] as Map<String, dynamic>?)?[field];
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty) {
    return value.first as Map<String, dynamic>;
  }
  return null;
}

Map<String, dynamic> _one(Map<String, dynamic> row, String field) =>
    _oneOrNull(row, field) ??
    (throw StateError('Missing expand "$field" in the response.'));
