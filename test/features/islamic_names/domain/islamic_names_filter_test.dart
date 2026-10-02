import 'package:deen_companion/features/islamic_names/domain/entities/islamic_name.dart';
import 'package:deen_companion/features/islamic_names/domain/services/islamic_names_filter.dart';
import 'package:flutter_test/flutter_test.dart';

IslamicName n(
  String name, {
  int id = 0,
  String arabic = '',
  String gender = 'male',
  String meaning = '',
  String origin = 'Arabic',
  String note = '',
}) => IslamicName(
  id: id,
  name: name,
  arabic: arabic,
  gender: gender,
  meaning: meaning,
  origin: origin,
  note: note,
);

void main() {
  final aisha = n(
    'Aisha',
    id: 1,
    arabic: 'عائشة',
    gender: 'female',
    meaning: 'Alive',
    note: 'Wife of the Prophet',
  );
  final musa = n(
    'Musa',
    id: 2,
    arabic: 'موسى',
    origin: 'Hebrew',
    meaning: 'Drawn from water',
    note: 'Prophet',
  );
  final ibrahim = n(
    'Ibrahim',
    id: 3,
    arabic: 'إبراهيم',
    origin: 'Hebrew',
    meaning: 'Father of nations',
  );
  final all = [aisha, musa, ibrahim];

  group('uniqueOrigins', () {
    test('deduplicates and sorts alphabetically', () {
      expect(IslamicNamesFilter.uniqueOrigins(all), ['Arabic', 'Hebrew']);
    });

    test('empty input gives empty list', () {
      expect(IslamicNamesFilter.uniqueOrigins(const []), isEmpty);
    });
  });

  group('apply', () {
    test('defaults return everything in original order', () {
      expect(IslamicNamesFilter.apply(all), all);
    });

    test('gender filter keeps exact matches only', () {
      expect(IslamicNamesFilter.apply(all, genderFilter: 'female'), [aisha]);
      expect(IslamicNamesFilter.apply(all, genderFilter: 'male'), [
        musa,
        ibrahim,
      ]);
      expect(IslamicNamesFilter.apply(all, genderFilter: 'unisex'), isEmpty);
    });

    test('origin filter is a set union', () {
      expect(IslamicNamesFilter.apply(all, originFilters: {'Hebrew'}), [
        musa,
        ibrahim,
      ]);
      expect(
        IslamicNamesFilter.apply(all, originFilters: {'Hebrew', 'Arabic'}),
        all,
      );
      expect(
        IslamicNamesFilter.apply(all, originFilters: {'Persian'}),
        isEmpty,
      );
    });

    test('query matches name case-insensitively', () {
      expect(IslamicNamesFilter.apply(all, query: 'MUSA'), [musa]);
      expect(IslamicNamesFilter.apply(all, query: 'bra'), [ibrahim]);
    });

    test('query matches meaning and note', () {
      expect(IslamicNamesFilter.apply(all, query: 'water'), [musa]);
      expect(IslamicNamesFilter.apply(all, query: 'wife'), [aisha]);
    });

    test('query matches Arabic script', () {
      expect(IslamicNamesFilter.apply(all, query: 'موسى'), [musa]);
    });

    test('no match returns empty', () {
      expect(IslamicNamesFilter.apply(all, query: 'zzz'), isEmpty);
    });

    test('filters combine with AND semantics', () {
      expect(
        IslamicNamesFilter.apply(
          all,
          genderFilter: 'male',
          originFilters: {'Hebrew'},
          query: 'father',
        ),
        [ibrahim],
      );
      expect(
        IslamicNamesFilter.apply(
          all,
          genderFilter: 'female',
          originFilters: {'Hebrew'},
        ),
        isEmpty,
      );
    });

    test('returns a new list and never mutates the input', () {
      final result = IslamicNamesFilter.apply(all);
      result.clear();
      expect(all, hasLength(3));
    });

    test(
      'query is not trimmed: a trailing space only matches names containing it',
      () {
        expect(IslamicNamesFilter.apply(all, query: 'musa '), isEmpty);
      },
    );
  });

  group('groupAlphabetically', () {
    test('groups by uppercase first letter in sorted order', () {
      final grouped = IslamicNamesFilter.groupAlphabetically([
        musa,
        aisha,
        ibrahim,
        n('Amina'),
      ]);
      expect(grouped.keys, ['A', 'I', 'M']);
      expect(grouped['A']!.map((x) => x.name), ['Aisha', 'Amina']);
    });

    test('lowercase names are grouped with their uppercase letter', () {
      final grouped = IslamicNamesFilter.groupAlphabetically([
        n('ali'),
        n('Aban'),
      ]);
      expect(grouped.keys.single, 'A');
      expect(grouped['A']!.length, 2);
    });

    test('empty name goes to the # bucket', () {
      final grouped = IslamicNamesFilter.groupAlphabetically([
        n(''),
        n('Zayd'),
      ]);
      expect(grouped['#'], hasLength(1));
      expect(grouped['Z'], hasLength(1));
    });

    test('empty input yields empty map and input is not mutated', () {
      expect(IslamicNamesFilter.groupAlphabetically(const []), isEmpty);
      final input = [musa, aisha];
      IslamicNamesFilter.groupAlphabetically(input);
      expect(input, [musa, aisha]);
    });
  });
}
