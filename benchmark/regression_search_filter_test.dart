// JellyAmp P0.5 step 11 — critical regression: SEARCH + FILTERING.
//
// Exercises the REAL SearchQuery parser and client-side filter logic from
// lib/models/search_models.dart (pure Dart, no network). This protects the
// power-user search syntax and the year/genre/codec/bit-depth/downloaded/
// favorite filters the roadmap lists as critical.
//
// Run:  flutter test benchmark/regression_search_filter_test.dart
import 'package:finamp/models/jellyfin_models.dart' show BaseItemId;
import 'package:finamp/models/search_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'regression_helpers.dart';

void main() {
  group('SearchQuery.parse', () {
    test('parses free text and every power-user key:value term', () {
      final q = SearchQuery.parse(
        'metallica artist:"master of puppets" track:one album:"and justice" '
        'playlist:metal genre:thrash year:1986-1989 codec:flac bit:24 '
        'favorite:true downloaded:true',
      );

      // playlist:metal adds its value to the free-text term (search_models.dart
      // case 'playlist' -> free.add(value)), so "metal" is part of searchTerm.
      expect(q.searchTerm, 'metallica master of puppets one and justice metal');
      expect(q.onlyShowArtists, isTrue);
      expect(q.onlyShowTracks, isTrue);
      expect(q.onlyShowAlbums, isTrue);
      expect(q.onlyShowPlaylists, isTrue);
      expect(q.genreFilter, 'thrash');
      expect(q.yearMin, 1986);
      expect(q.yearMax, 1989);
      expect(q.codec, 'flac');
      expect(q.bitDepth, 24);
      expect(q.favoriteOnly, isTrue);
      expect(q.downloadedFilter, isTrue);
      expect(q.hasTypeScope, isTrue);
      expect(q.hasFilters, isTrue);
    });

    test('handles quoted phrases, reversed year ranges, aliases and unknown keys', () {
      final quoted = SearchQuery.parse('album:"master of puppets"');
      expect(quoted.onlyShowAlbums, isTrue);
      expect(quoted.searchTerm, 'master of puppets');

      // Reversed range must be normalised to ascending.
      final range = SearchQuery.parse('year:1991-1986');
      expect(range.yearMin, 1986);
      expect(range.yearMax, 1991);

      // British "favourite" + numeric booleans + bitdepth alias.
      final alias = SearchQuery.parse('favourite:1 bitdepth:16');
      expect(alias.favoriteOnly, isTrue);
      expect(alias.bitDepth, 16);

      // Unknown keys are kept as literal search text, not dropped.
      final unknown = SearchQuery.parse('foo:bar hello');
      expect(unknown.searchTerm, contains('foo:bar'));
      expect(unknown.searchTerm, contains('hello'));
    });
  });

  group('SearchQuery.matches (filtering)', () {
    test('filters by year, genre, codec and bit-depth', () {
      final flac24 = audioItem('t1', 'A', productionYear: 1986, genres: ['Metal'], codec: 'flac', bitDepth: 24);
      final mp3 = audioItem('t2', 'B', productionYear: 2001, genres: ['Pop'], codec: 'mp3', bitDepth: 16);

      expect(SearchQuery.parse('year:1980-1990 genre:metal codec:flac bit:24').matches(flac24), isTrue);
      expect(SearchQuery.parse('year:1990-2000').matches(flac24), isFalse, reason: 'year out of range');
      expect(SearchQuery.parse('genre:pop').matches(flac24), isFalse, reason: 'genre mismatch');
      expect(SearchQuery.parse('codec:mp3').matches(flac24), isFalse, reason: 'codec mismatch');
      expect(SearchQuery.parse('bit:16').matches(flac24), isFalse, reason: 'bit-depth mismatch');
    });

    test('type-scoping terms set scopes without hiding free text matches', () {
      final track = audioItem('t9', 'One', codec: 'flac');
      final q = SearchQuery.parse('track:one');
      expect(q.onlyShowTracks, isTrue);
      expect(q.hasTypeScope, isTrue);
      // matches() only applies year/genre/codec/bit filters, never the type
      // scope (scope is applied by the caller when bucketing results).
      expect(q.matches(track), isTrue);
    });

    test('matchesAllTracks requires EVERY track to satisfy codec/bit filter', () {
      final allFlac = [audioItem('a', 'x', codec: 'flac'), audioItem('b', 'y', codec: 'flac')];
      final mixed = [audioItem('a', 'x', codec: 'flac'), audioItem('b', 'y', codec: 'mp3')];

      expect(SearchQuery.parse('codec:flac').matchesAllTracks(allFlac), isTrue);
      expect(SearchQuery.parse('codec:flac').matchesAllTracks(mixed), isFalse);
      // An empty album is NOT a "FLAC album".
      expect(SearchQuery.parse('codec:flac').matchesAllTracks(const []), isFalse);
    });
  });
}
