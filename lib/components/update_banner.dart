import 'package:finamp/services/update_checker.dart';
import 'package:finamp/services/update_checker_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Subtle, non-intrusive update banner.
/// Shows once per session and can be dismissed easily.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final updateAsync = ref.watch(updateCheckerProvider);

    return updateAsync.when(
      data: (update) {
        if (update == null) return const SizedBox.shrink();

        return Container(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.system_update_alt, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Jellyamp ${update.latestVersion} is available',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse(update.htmlUrl)),
                child: const Text('View'),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _dismissed = true),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}