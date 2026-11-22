import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/paging.dart';

/// Search box shared by the record lists.
///
/// The caller owns the controller so it can reset the text when a filter
/// changes. The clear button appears only when there is something to clear,
/// and the outline warms to the brand green while the pointer is over the
/// field so it reads as an input before it is focused.
class EcoSearchField extends StatefulWidget {
  const EcoSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<EcoSearchField> createState() => _EcoSearchFieldState();
}

class _EcoSearchFieldState extends State<EcoSearchField> {
  bool _hovered = false;

  BorderSide get _side => BorderSide(
    color: _hovered
        ? AppColors.primary.withValues(alpha: 0.5)
        : AppColors.sage.withValues(alpha: 0.8),
  );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          return TextField(
            controller: widget.controller,
            onChanged: widget.onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 13, color: AppColors.forest),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.inkMuted,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 19,
                color: _hovered ? AppColors.primary : AppColors.inkMuted,
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: AppColors.inkMuted,
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onChanged('');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: _side,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: _side,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// How much of a list the current search query kept.
///
/// Sits under an [EcoSearchField] so the clerk can tell a short list from a
/// query that matched nothing.
class EcoResultCount extends StatelessWidget {
  const EcoResultCount({
    super.key,
    required this.shown,
    required this.total,
    required this.singular,
    required this.plural,
  });

  final int shown;
  final int total;
  final String singular;
  final String plural;

  @override
  Widget build(BuildContext context) {
    final none = shown == 0;
    final noun = total == 1 ? singular : plural;

    return Row(
      children: [
        Icon(
          none ? Icons.search_off_rounded : Icons.filter_alt_outlined,
          size: 13,
          color: none ? AppColors.warning : AppColors.moss,
        ),
        const SizedBox(width: 5),
        Text(
          none ? 'No match among $total $noun' : '$shown of $total $noun',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: none ? AppColors.warning : AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// Footer for a paged list: range, rows-per-page and previous/next.
///
/// [page] is zero-based. The widget only reports intent; the caller clamps the
/// page with [clampPage] after the filter changes.
class EcoPaginationBar extends StatelessWidget {
  const EcoPaginationBar({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.pageSizes = const [10, 25, 50],
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final List<int> pageSizes;

  @override
  Widget build(BuildContext context) {
    final pages = pageCount(total, pageSize);
    final safePage = clampPage(page, total, pageSize);
    final canBack = safePage > 0;
    final canNext = safePage < pages - 1;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pageRangeLabel(safePage, pageSize, total),
              style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
            ),
          ),
          if (onPageSizeChanged != null)
            PopupMenuButton<int>(
              tooltip: 'Rows per page',
              initialValue: pageSize,
              onSelected: onPageSizeChanged,
              itemBuilder: (_) => [
                for (final size in pageSizes)
                  PopupMenuItem(value: size, child: Text('$size per page')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pageSize / page',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: AppColors.forest,
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Previous page',
            visualDensity: VisualDensity.compact,
            onPressed: canBack ? () => onPageChanged(safePage - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
          Text(
            '${safePage + 1}/$pages',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            visualDensity: VisualDensity.compact,
            onPressed: canNext ? () => onPageChanged(safePage + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
