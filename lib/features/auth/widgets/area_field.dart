import 'package:flutter/material.dart';

import '../../../core/constants/resident_areas.dart';
import '../../../core/theme/app_colors.dart';

/// Read-only field that opens a searchable list of Batasan Hills areas.
///
/// Styled to match AppTextField so it sits naturally in the sign-up form.
class AreaField extends StatelessWidget {
  const AreaField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onTap,
    this.enabled = true,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onTap;
  final bool enabled;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.forest,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          readOnly: true,
          enabled: enabled,
          onTap: onTap,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: AppColors.forest),
          cursorColor: AppColors.forest,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: enabled ? AppColors.forest : AppColors.sage,
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
          ),
        ),
      ],
    );
  }
}

/// Opens the searchable area sheet and returns the picked area, or null when
/// the resident dismissed it.
Future<String?> showAreaPicker(
  BuildContext context, {
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AreaPickerSheet(selected: selected),
  );
}

class _AreaPickerSheet extends StatefulWidget {
  const _AreaPickerSheet({this.selected});

  final String? selected;

  @override
  State<_AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends State<_AreaPickerSheet> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return ResidentAreas.all;
    return ResidentAreas.all
        .where((area) => area.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Subdivision / Area / Sitio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                style: const TextStyle(fontSize: 13, color: AppColors.forest),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 42),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final areas = _visible;
    if (areas.isEmpty) {
      return const Center(
        child: Text(
          'No match found',
          style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: areas.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppColors.sage.withValues(alpha: 0.4)),
      itemBuilder: (context, index) {
        final area = areas[index];
        final active = area == widget.selected;
        return ListTile(
          dense: true,
          title: Text(
            area,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: AppColors.forest,
            ),
          ),
          trailing: active
              ? const Icon(
                  Icons.check_rounded,
                  size: 17,
                  color: AppColors.primary,
                )
              : null,
          onTap: () => Navigator.of(context).pop(area),
        );
      },
    );
  }
}
