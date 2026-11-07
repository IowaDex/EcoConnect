import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_post.dart';
import '../../../core/utils/image_payload.dart';

/// Community posts: residents share updates, staff can post as the barangay.
class CommunityPostService {
  static final CommunityPostService _instance =
      CommunityPostService._internal();
  factory CommunityPostService() => _instance;
  CommunityPostService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('communityPosts');

  Stream<List<CommunityPost>> watchFeed() {
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => CommunityPost.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return items;
    });
  }

  /// Keeps the open post in sync while neighbours react and reply.
  Stream<CommunityPost?> watchPost(String id) {
    return _col.doc(id).snapshots().map((snap) {
      final data = snap.data();
      return data == null ? null : CommunityPost.fromDoc(snap.id, data);
    });
  }

  Future<String> create({    required String authorId,
    required String authorName,
    required String authorRole,
    required String body,
    UploadPayload? image,
  }) async {
    final ref = _col.doc();
    await ref.set({
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'body': body.trim(),
      'image': image?.toMap(),
      'likedBy': <String>[],
      'comments': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Adds or removes the user from the like list.
  Future<void> toggleLike({
    required CommunityPost post,
    required String userId,
  }) async {
    // arrayUnion/arrayRemove touch only this user's entry, so two people
    // reacting at once cannot overwrite each other's like.
    final liked = post.likedBy.contains(userId);
    await _col.doc(post.id).update({
      'likedBy': liked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addComment({
    required CommunityPost post,
    required String authorId,
    required String authorName,
    required String body,
  }) async {
    final comment = CommunityComment(
      id: _commentId(),
      authorId: authorId,
      authorName: authorName,
      body: body.trim(),
    );
    // Appends atomically; the id makes every comment a distinct array element.
    await _col.doc(post.id).update({
      'comments': FieldValue.arrayUnion([comment.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  static String _commentId() {
    final rand = Random();
    return '${DateTime.now().microsecondsSinceEpoch}'
        '${rand.nextInt(999).toString().padLeft(3, '0')}';
  }
}
