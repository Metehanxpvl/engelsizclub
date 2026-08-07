import 'package:flutter/material.dart';

import '../../domain/entities/forum_topic.dart';
import '../../../meto_theme.dart';

/// Material 3 uyumlu forum konu kartı.
class ForumTopicCard extends StatelessWidget {
  const ForumTopicCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  final ForumTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.45 : 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip(
                          context,
                          topic.displayDisease,
                          scheme.primaryContainer,
                          scheme.onPrimaryContainer,
                        ),
                        if ((topic.subCategoryLabel ?? '').isNotEmpty)
                          _chip(
                            context,
                            topic.subCategoryLabel!,
                            scheme.secondaryContainer,
                            scheme.onSecondaryContainer,
                          ),
                        if (topic.ageGroup.trim().isNotEmpty)
                          _chip(
                            context,
                            'Yaş ${topic.ageGroup}',
                            scheme.tertiaryContainer,
                            scheme.onTertiaryContainer,
                          ),
                      ],
                    ),
                  ),
                  if (topic.isResolved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF166534).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF166534)),
                          SizedBox(width: 4),
                          Text(
                            'Çözüldü',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                topic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
              ),
              if (topic.content.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  topic.content.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
              if (topic.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final t in topic.tags.take(4))
                      Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MetoColors.primary,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: topic.avatarColor,
                    child: Text(
                      topic.avatar.trim().isNotEmpty
                          ? topic.avatar.trim().substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topic.anon ? 'Anonim' : topic.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  _stat(Icons.visibility_outlined, topic.views),
                  const SizedBox(width: 10),
                  _stat(Icons.chat_bubble_outline, topic.replyCount),
                  const SizedBox(width: 10),
                  _stat(Icons.favorite_border, topic.likes),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String text,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _stat(IconData icon, int n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: MetoColors.mutedFg),
        const SizedBox(width: 3),
        Text(
          '$n',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
      ],
    );
  }
}
