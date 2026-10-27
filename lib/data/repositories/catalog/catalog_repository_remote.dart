import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../domain/models/barcode.dart';
import '../../../domain/models/barcode_owner.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/name_normalization.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/purchase_count.dart';
import '../../../domain/models/record_id.dart';
import '../../../domain/models/scale_label.dart';
import '../../services/pb_schema.dart';
import '../../services/pocketbase_error.dart';
import 'catalog_repository.dart';

const _expandKey = 'expand';

/// Where the leaf of a batch sits in the answers, and where its codes do.
final class _LeafSlot {
  const _LeafSlot(this.leafAt, this.codeAts);

  final int leafAt;
  final List<int> codeAts;
}

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`.** Without it a failure of
/// the SDK arrives raw and the user reads "server unavailable" when the
/// product simply already exists.
final class CatalogRepositoryRemote implements CatalogRepository {
  CatalogRepositoryRemote(this._pb);

  final PocketBase _pb;

  @override
  Future<IList<Category>> fetchCategories() async {
    try {
      requireSession(_pb);
      // No `active` filter anywhere in this file: decision B3 needs the
      // deactivated rows for the duplicate guard, and the screen greys them
      // out instead of the query hiding them. No owner filter either: the
      // `listRule` already limits the list to the signed-in user.
      final records = await _pb
          .collection(PbCollections.category)
          .getFullList(sort: PbFields.name);
      return records.map((r) => Category.fromJson(_rowOf(r))).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<ProductType>> fetchTypes() async {
    try {
      requireSession(_pb);
      final records = await _pb
          .collection(PbCollections.productType)
          .getFullList(sort: PbFields.name);
      return records.map((r) => ProductType.fromJson(_rowOf(r))).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<Brand>> fetchBrands() async {
    try {
      requireSession(_pb);
      final records = await _pb
          .collection(PbCollections.brand)
          .getFullList(sort: PbFields.name);
      return records.map((r) => Brand.fromJson(_rowOf(r))).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<Category> createCategory(Category category) =>
      _create(PbCollections.category, category.toJson(), Category.fromJson);

  @override
  Future<ProductType> createType(ProductType type) =>
      _create(PbCollections.productType, type.toJson(), ProductType.fromJson);

  @override
  Future<Brand> createBrand(Brand brand) =>
      _create(PbCollections.brand, brand.toJson(), Brand.fromJson);

  @override
  Future<ProductType> updateType(ProductType type) => _update(
    PbCollections.productType,
    type.id!,
    type.toJson(),
    ProductType.fromJson,
  );

  @override
  Future<Category> updateCategory(Category category) => _update(
    PbCollections.category,
    category.id!,
    category.toJson(),
    Category.fromJson,
  );

  @override
  Future<Brand> updateBrand(Brand brand) =>
      _update(PbCollections.brand, brand.id!, brand.toJson(), Brand.fromJson);

  @override
  Future<ProductRegistration> updateRegistration(
    ProductRegistration registration,
  ) => _update(
    PbCollections.productRegistration,
    registration.id!,
    registration.toJson(),
    ProductRegistration.fromJson,
  );

  @override
  Future<Product> updateProduct(Product product) async {
    try {
      requireSession(_pb);
      // The leaf comes back WITH its codes.
      final record = await _pb
          .collection(PbCollections.product)
          .update(
            product.id!,
            body: _writeBody(product.toJson()..remove(PbFields.id)),
            expand: PbFields.productBarcodeViaProductId,
          );
      return _leafOf(record);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// The three creates differ in their collection and their `fromJson`, and in
  /// nothing else. The owner is the signed-in user; the server refuses any
  /// other.
  Future<T> _create<T>(
    String collection,
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    try {
      requireSession(_pb);
      final record = await _pb
          .collection(collection)
          .create(
            body: {
              ..._writeBody(json),
              PbFields.user: _pb.authStore.record!.id,
            },
          );
      return fromJson(_rowOf(record));
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// The id leaves the body because it is already in the path, and the owner
  /// never goes: the `updateRule` refuses an owner swap.
  Future<T> _update<T>(
    String collection,
    String id,
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    try {
      requireSession(_pb);
      final record = await _pb
          .collection(collection)
          .update(id, body: _writeBody(json..remove(PbFields.id)));
      return fromJson(_rowOf(record));
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<ProductRegistration>> fetchRegistrations() async {
    try {
      requireSession(_pb);
      // No `active` filter, like every other read in this file: the
      // maintenance screen is what offers "mostrar desativados", and the
      // duplicate guard needs to see them anyway (decision B3).
      final records = await _pb
          .collection(PbCollections.productRegistration)
          .getFullList(sort: PbFields.description);
      return records
          .map((r) => ProductRegistration.fromJson(_rowOf(r)))
          .toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<Product>> fetchProducts() async {
    try {
      requireSession(_pb);
      final records = await _pb
          .collection(PbCollections.product)
          .getFullList(
            sort: PbFields.totalContent,
            expand: PbFields.productBarcodeViaProductId,
          );
      return records.map(_leafOf).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ProductRegistration?> findRegistrationById(String id) async {
    try {
      requireSession(_pb);
      // Not `getOne`: its 404 would become an `ApiException` instead of null.
      final page = await _pb
          .collection(PbCollections.productRegistration)
          .getList(
            page: 1,
            perPage: 1,
            skipTotal: true,
            filter: _pb.filter('${PbFields.id} = {:id}', {'id': id}),
          );
      return page.items.isEmpty
          ? null
          : ProductRegistration.fromJson(_rowOf(page.items.first));
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IMap<String, int>> fetchPurchaseCountsByType() async {
    try {
      requireSession(_pb);
      // A view that only sums and groups — no now(), no window, no threshold
      // (decisions 7 and 13). What to do with the count is Dart's business.
      final answers = await Future.wait([
        _pb.collection(PbCollections.purchaseItemTotals).getFullList(),
        _pb.collection(PbCollections.product).getFullList(),
        _pb.collection(PbCollections.productRegistration).getFullList(),
      ]);
      return purchaseCountsByType(
        products: answers[1].map((r) => Product.fromJson(_rowOf(r))).toIList(),
        registrations: answers[2]
            .map((r) => ProductRegistration.fromJson(_rowOf(r)))
            .toIList(),
        countByProduct: {
          for (final r in answers[0])
            r.data[PbFields.productId] as String:
                (r.data[PbFields.purchaseCount] as num).toInt(),
        }.lock,
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<TypeLeaf>> fetchLeavesOfType(String productTypeId) async {
    try {
      requireSession(_pb);
      final records = await _pb
          .collection(PbCollections.product)
          .getFullList(
            filter: _pb.filter(
              '${PbFields.productRegistrationId}.${PbFields.productTypeId} '
              '= {:t}',
              {'t': productTypeId},
            ),
            expand: PbFields.productRegistrationId,
            sort: PbFields.totalContent,
          );
      return [
        for (final r in records)
          TypeLeaf(
            product: Product.fromJson(_rowOf(r)),
            registration: ProductRegistration.fromJson(
              _rowOfMap(_expanded(r.data, PbFields.productRegistrationId)!),
            ),
          ),
      ].toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ProductRegistration?> findRegistration({
    required String productTypeId,
    String? brandId,
    required String description,
  }) async {
    try {
      requireSession(_pb);
      // The server has no normalized column: it narrows by type and brand,
      // and the comparison is the domain's `normalizeName`.
      final records = await _pb
          .collection(PbCollections.productRegistration)
          .getFullList(filter: _typeAndBrand(productTypeId, brandId));
      final wanted = normalizeName(description);
      for (final r in records) {
        final registration = ProductRegistration.fromJson(_rowOf(r));
        if (normalizeName(registration.description) == wanted) {
          return registration;
        }
      }
      return null;
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<String>> fetchDescriptions({
    required String productTypeId,
    String? brandId,
  }) async {
    try {
      requireSession(_pb);
      final records = await _pb
          .collection(PbCollections.productRegistration)
          .getFullList(
            filter:
                '${_typeAndBrand(productTypeId, brandId)} && '
                '${PbFields.description} != ""',
            sort: PbFields.description,
          );
      return records
          .map((r) => r.data[PbFields.description] as String)
          .toSet()
          .toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// A null brand is a VALUE (decision B2): PocketBase stores it as `''`.
  String _typeAndBrand(String productTypeId, String? brandId) => _pb.filter(
    '${PbFields.productTypeId} = {:t} && ${PbFields.brandId} = {:b}',
    {'t': productTypeId, 'b': brandId ?? ''},
  );

  @override
  Future<IList<Product>> fetchProductsOf(String registrationId) async {
    try {
      requireSession(_pb);
      final records = await _pb
          .collection(PbCollections.product)
          .getFullList(
            filter: _pb.filter('${PbFields.productRegistrationId} = {:id}', {
              'id': registrationId,
            }),
            sort: PbFields.totalContent,
            expand: PbFields.productBarcodeViaProductId,
          );
      return records.map(_leafOf).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<PackagingWithBarcodes> packagings,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) async {
    try {
      requireSession(_pb);
      final user = _pb.authStore.record!.id;
      final registrationId = newRecordId();

      // One batch, never loose creates: a registration with four packagings is
      // five records in two collections, and the batch is what makes them
      // all-or-nothing. Parent before child.
      final batch = _pb.createBatch();
      batch
          .collection(PbCollections.productRegistration)
          .create(
            body: {
              ..._writeBody(registration.toJson()),
              PbFields.id: registrationId,
              PbFields.user: user,
            },
          );
      final slots = _addLeaves(
        batch,
        user: user,
        registrationId: registrationId,
        packagings: packagings,
        scaleCodes: scaleCodes,
        // The registration took request 0.
        firstIndex: 1,
      );
      final answers = await batch.send();

      return SavedRegistration(
        registration: ProductRegistration.fromJson(
          _rowOfMap(_bodyOf(answers[0])),
        ),
        products: _productsOf(answers, slots),
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<Product>> addPackagings({
    required String registrationId,
    required IList<PackagingWithBarcodes> packagings,
  }) async {
    try {
      requireSession(_pb);
      // Nothing to write is nothing to ask: an empty list must never create a
      // by-weight leaf inside a by-piece registration.
      if (packagings.isEmpty) return const IList.empty();

      final batch = _pb.createBatch();
      final slots = _addLeaves(
        batch,
        user: _pb.authStore.record!.id,
        registrationId: registrationId,
        packagings: packagings,
        scaleCodes: const IList.empty(),
        firstIndex: 0,
      );
      return _productsOf(await batch.send(), slots);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// Queues the leaves and their codes, leaf before its codes, and says where
  /// each one will sit in the answers.
  ///
  /// A product sold by weight arrives with no packaging and still gets ONE
  /// leaf (decision B1), and the scale codes ride on it. No check on
  /// [scaleCodes] here: "packagings + scale code" was already refused by
  /// `checkScaleCodes` in the domain.
  List<_LeafSlot> _addLeaves(
    BatchService batch, {
    required String user,
    required String registrationId,
    required IList<PackagingWithBarcodes> packagings,
    required IList<ScaleCode> scaleCodes,
    required int firstIndex,
  }) {
    final slots = <_LeafSlot>[];
    var next = firstIndex;

    void addLeaf(
      PackagingWithBarcodes? card,
      List<Map<String, dynamic>> codes,
    ) {
      final leafId = newRecordId();
      batch
          .collection(PbCollections.product)
          .create(
            body: {
              ...Product(
                id: leafId,
                productRegistrationId: registrationId,
                packaging: card?.packaging,
              ).toJson(),
              PbFields.user: user,
            },
          );
      final leafAt = next++;
      final codeAts = <int>[];
      for (final code in codes) {
        // The codes get no id from the app: no later request points at them.
        batch
            .collection(PbCollections.productBarcode)
            .create(
              body: {PbFields.productId: leafId, ...code, PbFields.user: user},
            );
        codeAts.add(next++);
      }
      slots.add(_LeafSlot(leafAt, codeAts));
    }

    if (packagings.isEmpty) {
      addLeaf(null, [for (final c in scaleCodes) c.toJson()]);
    } else {
      for (final card in packagings) {
        addLeaf(card, [
          for (final b in card.barcodes)
            {PbFields.code: b.toJson(), PbFields.storeId: ''},
        ]);
      }
    }
    return slots;
  }

  IList<Product> _productsOf(
    List<BatchResult> answers,
    List<_LeafSlot> slots,
  ) => [
    for (final slot in slots)
      Product.fromJson({
        ..._rowOfMap(_bodyOf(answers[slot.leafAt])),
        Product.barcodesKey: [
          for (final at in slot.codeAts) _bodyOf(answers[at]),
        ],
      }),
  ].toIList();

  @override
  Future<IMap<Barcode, BarcodeOwner>> findOwners(IList<Barcode> codes) async {
    if (codes.isEmpty) return const IMap.empty();
    try {
      requireSession(_pb);
      // `store_id = ""` is what leaves the scale codes out. A 7-digit item code
      // is never equal to a GTIN-14, but the filter does not depend on that.
      final params = {
        for (var i = 0; i < codes.length; i++) 'c$i': codes[i].toJson(),
      };
      final anyCode = [
        for (final key in params.keys) '${PbFields.code} = {:$key}',
      ].join(' || ');
      const registrationPath =
          '${PbFields.productId}.${PbFields.productRegistrationId}';
      final records = await _pb
          .collection(PbCollections.productBarcode)
          .getFullList(
            filter: _pb.filter(
              '${PbFields.storeId} = "" && ($anyCode)',
              params,
            ),
            expand:
                '$registrationPath.${PbFields.productTypeId},'
                '$registrationPath.${PbFields.brandId}',
            sort: PbFields.created,
          );

      final owners = <Barcode, BarcodeOwner>{};
      for (final r in records) {
        final code = Barcode.fromJson(r.data[PbFields.code] as String);
        final owner = _ownerOf(r);
        final held = owners[code];
        // Without a unique index two rows can hold one code (a write from both
        // phones at once): the active owner stays, so `conflictOf` sees it.
        if (held == null || (!held.isActive && owner.isActive)) {
          owners[code] = owner;
        }
      }
      return owners.lock;
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// Rebuilds the nested map `BarcodeOwner.fromJson` reads: the leaf with its
  /// registration, which carries the type and the brand.
  BarcodeOwner _ownerOf(RecordModel code) {
    final leaf = _expanded(code.data, PbFields.productId)!;
    final registration = _expanded(leaf, PbFields.productRegistrationId)!;
    final type = _expanded(registration, PbFields.productTypeId)!;
    final brand = _expanded(registration, PbFields.brandId);
    return BarcodeOwner.fromJson({
      ..._rowOfMap(leaf),
      BarcodeOwner.registrationKey: {
        ..._rowOfMap(registration),
        BarcodeOwner.typeKey: _rowOfMap(type),
        BarcodeOwner.brandKey: brand == null ? null : _rowOfMap(brand),
      },
    });
  }

  @override
  Future<void> addBarcode({
    required String productId,
    required Barcode code,
  }) async {
    try {
      requireSession(_pb);
      await _pb
          .collection(PbCollections.productBarcode)
          .create(
            body: {
              PbFields.productId: productId,
              PbFields.code: code.toJson(),
              // A packaging code: no store.
              PbFields.storeId: '',
              PbFields.user: _pb.authStore.record!.id,
            },
          );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> removeBarcode({
    required String productId,
    required Barcode code,
  }) async {
    try {
      requireSession(_pb);
      await _deleteCodes(
        _pb.filter(
          '${PbFields.productId} = {:p} && ${PbFields.code} = {:c} && '
          '${PbFields.storeId} = ""',
          {'p': productId, 'c': code.toJson()},
        ),
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> addScaleCode({
    required String productId,
    required ScaleCode code,
  }) async {
    try {
      requireSession(_pb);
      await _pb
          .collection(PbCollections.productBarcode)
          .create(
            body: {
              PbFields.productId: productId,
              ...code.toJson(),
              PbFields.user: _pb.authStore.record!.id,
            },
          );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> removeScaleCode({
    required String productId,
    required ScaleCode code,
  }) async {
    try {
      requireSession(_pb);
      await _deleteCodes(
        _pb.filter(
          '${PbFields.productId} = {:p} && ${PbFields.code} = {:c} && '
          '${PbFields.storeId} = {:s}',
          {'p': productId, 'c': code.itemCode, 's': code.storeId},
        ),
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// A real DELETE (decision of 10/10/2026), and only in `product_barcode`.
  /// PocketBase has no delete-by-filter, so it finds the rows and removes them
  /// in one batch. Nothing found is nothing to write.
  Future<void> _deleteCodes(String filter) async {
    final rows = await _pb
        .collection(PbCollections.productBarcode)
        .getFullList(filter: filter);
    if (rows.isEmpty) return;
    final batch = _pb.createBatch();
    for (final row in rows) {
      batch.collection(PbCollections.productBarcode).delete(row.id);
    }
    await batch.send();
  }

  /// The leaf plus the codes the back-relation expanded (none is an empty
  /// list, not a missing leaf).
  Product _leafOf(RecordModel record) {
    final expanded =
        (record.data[_expandKey] as Map?)?[PbFields.productBarcodeViaProductId];
    return Product.fromJson({
      ..._rowOf(record),
      Product.barcodesKey: switch (expanded) {
        final List<dynamic> rows => rows,
        final Map<dynamic, dynamic> row => [row],
        _ => const <dynamic>[],
      },
    });
  }

  /// One expanded relation of [data], or null when it is empty or absent.
  Map<String, dynamic>? _expanded(Map<String, dynamic> data, String field) {
    final value = (data[_expandKey] as Map?)?[field];
    return value is Map ? value.cast<String, dynamic>() : null;
  }

  /// A batch answer is `{status, body}`.
  Map<String, dynamic> _bodyOf(BatchResult answer) =>
      (answer.body as Map).cast<String, dynamic>();

  Map<String, dynamic> _rowOf(RecordModel record) =>
      _rowOfMap({...record.data, PbFields.id: record.id});

  /// The entities read an absent brand as null; PocketBase says `''`.
  Map<String, dynamic> _rowOfMap(Map<String, dynamic> data) {
    final row = {...data}..remove(_expandKey);
    if (row[PbFields.brandId] == '') row[PbFields.brandId] = null;
    return row;
  }

  /// The way back of [_rowOfMap]: a null brand is written as `''`.
  Map<String, dynamic> _writeBody(Map<String, dynamic> json) {
    final body = {...json};
    if (body.containsKey(PbFields.brandId) && body[PbFields.brandId] == null) {
      body[PbFields.brandId] = '';
    }
    return body;
  }
}
