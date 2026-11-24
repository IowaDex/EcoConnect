import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/manual_assignment.dart';

/// A manual Iswim started and has not submitted yet.
///
/// Only the roster is kept: the title, the drivers, the plates, the areas, the
/// days, the start time and the recurrence. Nothing is sent to Firestore until
/// the manual is submitted, so a half-built manual never reaches City Hall.
class ManualDraft {
  const ManualDraft({required this.title, required this.assignments});

  final String title;
  final List<ManualAssignment> assignments;

  bool get isEmpty => title.trim().isEmpty && assignments.isEmpty;

  Map<String, dynamic> toMap() => {
    'title': title,
    'assignments': [for (final row in assignments) row.toMap()],
  };

  static ManualDraft fromMap(Map<String, dynamic> data) => ManualDraft(
    title: data['title'] as String? ?? '',
    assignments: ManualAssignment.listFromDynamic(data['assignments']),
  );
}

/// Keeps one unfinished manual per scope on the device.
///
/// The scope is the City Hall request the manual answers, so starting a manual
/// for another request never overwrites the draft of the first one.
class ManualDraftStore {
  ManualDraftStore._();
  static final ManualDraftStore instance = ManualDraftStore._();
  factory ManualDraftStore() => instance;

  static String _key(String scope) => 'manual_draft_v1_$scope';

  Future<ManualDraft?> load(String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(scope));
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      final draft = ManualDraft.fromMap(Map<String, dynamic>.from(data));
      return draft.isEmpty ? null : draft;
    } catch (_) {
      // A draft that cannot be read must not block a fresh manual.
      return null;
    }
  }

  Future<void> save(String scope, ManualDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(scope), jsonEncode(draft.toMap()));
    } catch (_) {
      // Storage is a convenience; the manual can still be rebuilt by hand.
    }
  }

  Future<void> clear(String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(scope));
    } catch (_) {}
  }
}
