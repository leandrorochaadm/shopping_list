/// What arrived from the other phone. Two natures, because the banner reads
/// two different sentences: a new item is countable ("2 itens novos"), the
/// rest is not ("a lista mudou").
enum ListChangeKind { added, changed }

/// What the banner knows, and the reason the list never moves under a finger:
/// changes from the other phone pile up HERE, and it is the tap that redraws.
final class PendingChanges {
  const PendingChanges({this.addedCount = 0, this.hasOtherChanges = false});

  static const none = PendingChanges();

  final int addedCount;
  final bool hasOtherChanges;

  bool get isEmpty => addedCount == 0 && !hasOtherChanges;

  PendingChanges plus(ListChangeKind kind) => switch (kind) {
    ListChangeKind.added => PendingChanges(
      addedCount: addedCount + 1,
      hasOtherChanges: hasOtherChanges,
    ),
    ListChangeKind.changed => PendingChanges(
      addedCount: addedCount,
      hasOtherChanges: true,
    ),
  };

  /// The banner's sentence, or null when there is no banner. An item removed
  /// or marked by the other phone is not countable — and mixing "2 itens
  /// novos" with a removal would make the screen promise a number it is not
  /// going to deliver. pt-BR: it is read on screen.
  String? get label {
    if (isEmpty) return null;
    if (hasOtherChanges) return 'A lista mudou — tocar para ver';
    return addedCount == 1
        ? '1 item novo — atualizar'
        : '$addedCount itens novos — atualizar';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingChanges &&
          other.addedCount == addedCount &&
          other.hasOtherChanges == hasOtherChanges);

  @override
  int get hashCode => Object.hash(addedCount, hasOtherChanges);

  @override
  String toString() =>
      'PendingChanges(added: $addedCount, other: $hasOtherChanges)';
}
