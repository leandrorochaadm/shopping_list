import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/name_normalization.dart';

/// The SAME case table lives in `supabase/checks/normalize_cases.sql`, which
/// is run once by hand against `dev` with its output pasted into the
/// migration. A pure Dart test cannot reach Postgres, so this file guards the
/// Dart half only — claiming otherwise would be a false guarantee.
void main() {
  /// Input → what BOTH sides are expected to produce.
  const shared = <String, String>{
    'Coca-Cola': 'coca-cola',
    '  COCA cola ': 'coca cola',
    'Açaí': 'acai',
    'ÁÇAÍ': 'acai',
    'São João': 'sao joao',
    'Limpeza': 'limpeza',
    '  limpeza': 'limpeza',
    'Pão de Açúcar': 'pao de acucar',
    'Müller': 'muller',
  };

  group('normalizeName', () {
    for (final entry in shared.entries) {
      test('normalizes "${entry.key}"', () {
        expect(normalizeName(entry.key), entry.value);
      });
    }

    test('makes case, blanks and accents the same three things', () {
      expect(normalizeName('AÇAÍ'), normalizeName(' açaí '));
      expect(normalizeName('Limpeza'), normalizeName('limpeza'));
    });

    test('keeps the inner blanks, which are part of the name', () {
      // 'Arroz integral' and 'Arrozintegral' are different products.
      expect(normalizeName(' Arroz  integral '), 'arroz  integral');
    });

    test('handles the empty string and blanks only', () {
      expect(normalizeName(''), '');
      expect(normalizeName('   '), '');
    });

    test('LEAVES a letter outside the hand-written table alone', () {
      // This is the divergence, written down instead of discovered: Postgres
      // unaccent strips the `ř` and the `ø`, and this table does not. The
      // consequence is contained — the unique index refuses the insert and
      // the user reads "já existe um cadastro com esses dados" — but the app
      // will have offered to create it first. Widening the table is the fix;
      // supabase/checks/normalize_cases.sql is what measures the gap.
      // Note what DOES happen: the `á` is in the table and goes, the `ř` is
      // not and stays — the divergence is per letter, not per word.
      expect(normalizeName('Dvořák'), 'dvořak');
      expect(normalizeName('Smørrebrød'), 'smørrebrød');
    });
  });
}
