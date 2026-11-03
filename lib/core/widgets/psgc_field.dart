import 'package:flutter/material.dart';

import '../services/psgc_service.dart';
import '../theme/app_colors.dart';

/// Read-only field that opens a searchable list of PSGC entries.
///
/// Styled to match AppTextField so it sits naturally in the sign-up form.
class PsgcField extends StatelessWidget {
  const PsgcField({
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

/// Opens a searchable bottom sheet and returns the picked entry.
Future<PsgcOption?> showPsgcPicker(
  BuildContext context, {
  required String title,
  required Future<List<PsgcOption>> Function() load,
}) {
  return showModalBottomSheet<PsgcOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PsgcPickerSheet(title: title, load: load),
  );
}

class _PsgcPickerSheet extends StatefulWidget {
  const _PsgcPickerSheet({required this.title, required this.load});

  final String title;
  final Future<List<PsgcOption>> Function() load;

  @override
  State<_PsgcPickerSheet> createState() => _PsgcPickerSheetState();
}

class _PsgcPickerSheetState extends State<_PsgcPickerSheet> {
  final _search = TextEditingController();

  List<PsgcOption> _options = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await widget.load();
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PsgcException
            ? error.message
            : 'Could not load the list. Please try again.';
        _loading = false;
      });
    }
  }

  List<PsgcOption> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _options;
    return _options
        .where((option) => option.name.toLowerCase().contains(query))
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
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.inkMuted),
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
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: AppColors.inkMuted),
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
    if (_loading) {
      return const Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.forest,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _load,
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final options = _visible;
    if (options.isEmpty) {
      return const Center(
        child: Text(
          'No match found',
          style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: options.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.sage.withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        return ListTile(
          dense: true,
          title: Text(
            option.name,
            style: const TextStyle(fontSize: 12.5, color: AppColors.forest),
          ),
          onTap: () => Navigator.of(context).pop(option),
        );
      },
    );
  }
}
