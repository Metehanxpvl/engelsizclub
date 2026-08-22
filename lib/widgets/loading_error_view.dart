import 'package:flutter/material.dart';

import '../l10n/l10n_text.dart';
import '../meto_theme.dart';

/// Shared loading / error / retry UI for data-fetch screens.
class LoadingErrorView extends StatelessWidget {
  const LoadingErrorView({
    super.key,
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyMessage,
    this.loadingMessage,
  });

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String? emptyMessage;
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: MetoColors.primary),
            if (loadingMessage != null) ...[
              const SizedBox(height: 12),
              L10nText(
                loadingMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: MetoColors.mutedFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (error != null && error!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: MetoColors.mutedFg),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MetoColors.mutedFg,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const L10nText('Tekrar dene'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (emptyMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: L10nText(
            emptyMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MetoColors.mutedFg),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
