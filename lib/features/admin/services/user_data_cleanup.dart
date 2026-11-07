import 'package:cloud_firestore/cloud_firestore.dart';

/// Removes a deleted user's personal records from the feature collections.
///
/// Admin-only: the rules let staff delete these, nobody else. Location data is
/// handled separately by the location feature. Incident reports and recycling
/// drop-offs stay because they are barangay records, not personal content.
class UserDataCleanup {
  UserDataCleanup({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Collection name -> the field that holds the owner's uid.
  static const ownerFields = {
    'notifications': 'userId',
    'verificationRequests': 'userId',
    'wasteSubmissions': 'userId',
    'collectionRequests': 'requesterId',
  };

  // A batch holds at most 500 writes.
  static const _batchLimit = 400;

  Future<void> deleteAllFor(String uid) async {
    for (final entry in ownerFields.entries) {
      final snap =
          await _db.collection(entry.key).where(entry.value, isEqualTo: uid).get();
      await _deleteAll(snap.docs);
    }
    await _cleanCommunityPosts(uid);
    // A driver's live presence document is keyed by their uid.
    await _db.collection('routes').doc(uid).delete();
  }

  /// Deletes the user's own posts and strips their likes and comments from
  /// everyone else's. Comments live inside an array on the post, so they
  /// cannot be queried by author; the feed is read once and filtered here.
  /// shortcut: reads the whole feed, fine for one barangay, switch to a
  /// comments subcollection if the feed grows to thousands of posts.
  Future<void> _cleanCommunityPosts(String uid) async {
    final posts = await _db.collection('communityPosts').get();
    final own = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final post in posts.docs) {
      final data = post.data();
      if (data['authorId'] == uid) {
        own.add(post);
        continue;
      }
      final likes = data['likedBy'];
      final comments = data['comments'];
      final theirs = comments is List
          ? comments.where((c) => c is Map && c['authorId'] == uid).toList()
          : const [];
      final liked = likes is List && likes.contains(uid);
      if (theirs.isEmpty && !liked) continue;
      // arrayRemove matches the stored values exactly, so it cannot disturb
      // a like or comment someone else added in the meantime.
      await post.reference.update({
        if (liked) 'likedBy': FieldValue.arrayRemove([uid]),
        if (theirs.isNotEmpty) 'comments': FieldValue.arrayRemove(theirs),
      });
    }
    await _deleteAll(own);
  }

  Future<void> _deleteAll(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    for (var i = 0; i < docs.length; i += _batchLimit) {
      final batch = _db.batch();
      for (final doc in docs.skip(i).take(_batchLimit)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
