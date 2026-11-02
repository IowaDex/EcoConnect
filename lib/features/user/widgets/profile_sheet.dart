import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';

/// Opens the editable profile sheet: avatar, address and mobile number.
void showProfileSheet(BuildContext context) {
  final auth = context.read<AuthProvider>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ProfileSheet(auth: auth),
  );
}

/// Editable profile sheet: avatar, address and mobile number, saved to the
/// user's Firestore document.
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.auth});

  final AuthProvider auth;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  String? _photoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.auth.currentUser;
    _addressController = TextEditingController(text: user?.houseStreet ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _photoUrl = user?.photoUrl;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final raw = await picked.readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      if (mounted) _toast('That file is not a supported image');
      return;
    }

    // Avatars live inline in the user document, so keep the payload small:
    // a 320px JPEG is a few KB, comfortably under Firestore's 1 MB limit.
    final resized =
        decoded.width > 320 ? img.copyResize(decoded, width: 320) : decoded;
    final encoded = img.encodeJpg(resized, quality: 78);

    if (!mounted) return;
    setState(
      () => _photoUrl = 'data:image/jpeg;base64,${base64Encode(encoded)}',
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.auth.updateProfile(
      phone: _phoneController.text.trim(),
      houseStreet: _addressController.text.trim(),
      photoUrl: _photoUrl,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      _toast(widget.auth.error ?? 'Could not save your changes');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logOut() async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await widget.auth.logout();
    messenger.clearSnackBars();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            UserAvatar(
              photoUrl: _photoUrl,
              size: 88,
              showBadge: true,
              onTap: _pickPhoto,
            ),
            const SizedBox(height: 14),
            Text(
              user?.displayName ?? 'EcoConnect user',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 20),
            _ProfileField(
              label: 'Address',
              hint: 'Add your address',
              controller: _addressController,
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            _ProfileField(
              label: 'Mobile number',
              hint: 'Add your number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.creamBright,
                        ),
                      )
                    : const Text(
                        'Save changes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _saving ? null : _logOut,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Log out',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bordered cream field with a small caption, matching the profile sheet.
class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.forest,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.inkMuted,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}


