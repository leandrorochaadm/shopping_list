import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../domain/models/barcode.dart';
import '../../../domain/models/barcode_owner.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/scale_label.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';

/// How looking up a code ended. Four outcomes with a payload (rule 16); the
/// `null` of the method is the reentrancy guard saying "I did nothing".
sealed class BarcodeLookupOutcome {
  const BarcodeLookupOutcome();
}

/// The code belongs to an ACTIVE leaf.
final class BarcodeFound extends BarcodeLookupOutcome {
  const BarcodeFound(this.owner);

  final BarcodeOwner owner;
}

/// Nobody holds the code, or only a deactivated leaf does. Carries the code
/// so `[ Cadastrar produto ]` can open screen 4 with it.
final class BarcodeUnknown extends BarcodeLookupOutcome {
  const BarcodeUnknown(this.code);

  final Barcode code;
}

/// A scale label was scanned where it does not belong.
final class ScaleLabelRejected extends BarcodeLookupOutcome {
  const ScaleLabelRejected();

  /// pt-BR, in one place for the `#1a` and the pantry check.
  String get message => 'Etiqueta de balança só serve no lançamento da compra.';
}

final class BarcodeLookupFailed extends BarcodeLookupOutcome {
  const BarcodeLookupFailed(this.message);

  /// pt-BR, already translated.
  final String message;
}

/// Looks up the owner of a scanned code for the `#1a` panel and the pantry
/// check, and links a scale code chosen in "Qual produto é este?".
///
/// It is a provider of its own, not part of `CatalogViewModel`, whose `build()`
/// loads categories, types and brands. Nothing to load here.
final class BarcodeLookupViewModel extends Notifier<void> {
  /// One guard per action: the lookup is a read and the link is a write, and
  /// one must not block the other.
  bool _lookingUp = false;
  bool _linking = false;

  @override
  void build() {}

  /// The owner of [raw], or why there is none. A deactivated owner is
  /// "unknown": registering again is the way out, and the save of screen 4
  /// releases the code from the deactivated leaf.
  Future<BarcodeLookupOutcome?> lookUp(String raw) async {
    if (_lookingUp) return null;
    _lookingUp = true;
    try {
      // The label first: its 20-digit QR is not a Barcode, and its EAN-13
      // would only say "in-store" without telling why.
      if (ScaleLabel.parse(raw) != null) return const ScaleLabelRejected();
      final code = Barcode.typed(raw);
      final owners = await ref
          .read(catalogRepositoryProvider)
          .findOwners(IList([code]));
      if (!ref.mounted) return null;

      final owner = owners[code];
      return owner != null && owner.isActive
          ? BarcodeFound(owner)
          : BarcodeUnknown(code);
    } on InStoreBarcode {
      return const ScaleLabelRejected();
    } on InvalidBarcode catch (e) {
      return BarcodeLookupFailed(e.message);
    } on Object catch (e, st) {
      return BarcodeLookupFailed(translateError(e, st, 'procurar o código'));
    } finally {
      _lookingUp = false;
    }
  }

  /// Links a scale code to the leaf the user chose. Null on success, or the
  /// sentence for the SnackBar.
  ///
  /// [registration] is the registration of that leaf, so the rule "only a
  /// product sold loose has a scale code" is asked of the domain. The caller
  /// then runs `newPurchaseViewModelProvider.notifier.refresh()`, so the next
  /// read finds the link.
  Future<String?> linkScaleCode({
    required ProductRegistration registration,
    required String productId,
    required ScaleCode code,
  }) async {
    if (_linking) return null;
    _linking = true;
    try {
      registration.checkScaleCodes(IList([code]));

      await ref
          .read(catalogRepositoryProvider)
          .addScaleCode(productId: productId, code: code);
      if (!ref.mounted) return null;
      return null;
    } on UnexpectedScaleCode catch (e) {
      return e.message;
    } on Object catch (e, st) {
      // The unique index refusing is not a failure to log.
      if (AppFailure.from(e) is DuplicateRecord) return ScaleCode.takenMessage;
      return translateError(e, st, 'ligar a etiqueta ao produto');
    } finally {
      _linking = false;
    }
  }
}

/// `retry: null` on purpose, like every ViewModel provider of the project.
final barcodeLookupViewModelProvider =
    NotifierProvider<BarcodeLookupViewModel, void>(
      BarcodeLookupViewModel.new,
      retry: (retryCount, error) => null,
    );
