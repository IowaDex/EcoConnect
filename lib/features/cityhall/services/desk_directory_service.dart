import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/desk_document.dart';

/// Resolves the people behind a document from the real user directory.
///
/// A trip ticket keeps the driver name it was issued with and a memo keeps the
/// sender name it was written with. Those are snapshots; the desk wants the
/// account's current full name and barangay, so this stream overlays the live
/// `users/{uid}` profile when one exists.
///
/// The query is limited to the three desk roles. City Hall can read the
/// directory under the existing rules, and residents are never fetched.
class DeskDirectoryService {
  DeskDirectoryService._();
  static final DeskDirectoryService instance = DeskDirectoryService._();
  factory DeskDirectoryService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Map<String, DeskPerson>> watchPeople() => _db
      .collection('users')
      .where('role', whereIn: ['driver', 'admin', 'iswim'])
      .snapshots()
      .map((snap) {
        final people = <String, DeskPerson>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          final name = _text(data['name']).isNotEmpty
              ? _text(data['name'])
              : _text(data['displayName']);
          if (name.isEmpty) continue;
          people[doc.id] = DeskPerson(
            uid: doc.id,
            name: name,
            barangay: _text(data['barangay']),
            role: _text(data['role']),
          );
        }
        return people;
      });

  static String _text(dynamic value) => value is String ? value.trim() : '';
}
