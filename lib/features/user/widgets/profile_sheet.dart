import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../../core/constants/resident_areas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/utils/phone.dart';
import '../../auth/widgets/area_field.dart';
import 'user_avatar.dart';

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
  late final TextEditingController _areaOtherController;
  String? _photoUrl;
  String? _area;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.auth.currentUser;
    _addressController = TextEditingController(text: user?.houseStreet ?? '');
    _phoneController = TextEditingController(
      text: Phone.localDigits(user?.phone),
    );
    _photoUrl = user?.photoUrl;

    // A stored area that is not on the list came from "Other / Not Listed",
    // so it reopens as that option with the typed text filled in.
    final stored = user?.subdivision?.trim() ?? '';
    if (stored.isEmpty) {
      _area = null;
      _areaOtherController = TextEditingController();
    } else if (ResidentAreas.all.contains(stored)) {
      _area = stored;
      _areaOtherController = TextEditingController();
    } else {
      _area = ResidentAreas.other;
      _areaOtherController = TextEditingController(text: stored);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _areaOtherController.dispose();
    super.dispose();
  }

  Future<void> _pickArea() async {
    final picked = await showAreaPicker(context, selected: _area);
    if (picked == null || !mounted) return;
    setState(() {
      _area = picked;
      if (!ResidentAreas.isOther(picked)) _areaOtherController.clear();
    });
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
    final resized = decoded.width > 320
        ? img.copyResize(decoded, width: 320)
        : decoded;
    final encoded = img.encodeJpg(resized, quality: 78);

    if (!mounted) return;
    setState(
      () => _photoUrl = 'data:image/jpeg;base64,${base64Encode(encoded)}',
    );
  }

  Future<void> _save() async {
    final digits = _phoneController.text.trim();
    if (digits.isNotEmpty) {
      final error = Phone.validate(digits);
      if (error != null) {
        _toast(error);
        return;
      }
    }

    final area = ResidentAreas.isOther(_area)
        ? _areaOtherController.text.trim()
        : _area;
    if (ResidentAreas.isOther(_area) && (area == null || area.isEmpty)) {
      _toast('Please enter your area');
      return;
    }

    setState(() => _saving = true);
    final ok = await widget.auth.updateProfile(
      phone: digits.isEmpty ? null : Phone.toE164(digits),
      subdivision: area,
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
    if (!await confirmLogout(context) || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final location = context.read<LocationProvider>();
    Navigator.of(context).pop();
    // Delete the shared pin while still signed in; rules reject it afterwards.
    final removed = await location.endSession();
    await widget.auth.logout();
    if (!removed) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Signed out, but your shared location could not be '
            'removed. Sign in when online and turn sharing off.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    messenger.clearSnackBars();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/verify-identity');
                },
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.sage),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        user?.verificationStatus.icon ?? Icons.badge_outlined,
                        size: 18,
                        color:
                            user?.verificationStatus.color ?? AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Verify my identity',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      Text(
                        user?.verificationStatus.label ?? 'Upload ID',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color:
                              user?.verificationStatus.color ??
                              AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: AppColors.moss,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ProfilePicker(
              label: 'Subdivision / Area / Sitio',
              value: _area,
              hint: 'Select your area',
              onTap: _pickArea,
            ),
            if (ResidentAreas.isOther(_area)) ...[
              const SizedBox(height: 12),
              _ProfileField(
                label: 'Specify your area',
                hint: 'Subdivision, area or sitio',
                controller: _areaOtherController,
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 12),
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
              hint: '09XX XXX XXXX',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
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

/// Tappable row in the profile-sheet style that opens a picker.
class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    filled ? value! : hint,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: filled ? AppColors.forest : AppColors.inkMuted,
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.forest,
                ),
              ],
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
              fontSize: 11,
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
