import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Unified, grouped search results (JellyAmp fork feature).
///
/// Renders one section per content type — Artists, Albums, Tracks, Playlists,
/// Genres — so a single query searches the whole library at once instead of
/// only the active tab. Supports the [SearchQuery] power syntax (year:/codec:/
/// bit:/genre:/favorite:/artist:/album:/track:/playlist:).
class SearchResultsView extends ConsumerWidget {
  const SearchResultsView({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(groupedSearchProvider(query));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${l10n.searchError}: $error', textAlign: TextAlign.center),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noSearchResults, textAlign: TextAlign.center),
            ),
          );
        }

        final sections = <(String, List<BaseItemDto>)>[
          (l10n.artists, results.artists),
          (l10n.albums, results.albums),
          (l10n.tracks, results.tracks),
          (l10n.playlists, results.playlists),
          (l10n.genres, results.genres),
        ].where((section) => section.$2.isNotEmpty).toList();

        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            for (final (title, items) in sections) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                child: Text(
                  '$title · ${items.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              for (final item in items) ItemWrapper(item: item),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
