import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/image_payload.dart';

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// One reply on a community post.
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'body': body,
        // Nested lists cannot hold server timestamps.
        'createdAt': Timestamp.now(),
      };

  static CommunityComment fromMap(dynamic raw) {
    final map = raw is Map ? raw : const {};
    return CommunityComment(
      id: (map['id'] as String?) ?? '',
      authorId: (map['authorId'] as String?) ?? '',
      authorName: (map['authorName'] as String?) ?? 'Neighbor',
      body: (map['body'] as String?) ?? '',
      createdAt: _asDate(map['createdAt']),
    );
  }
}

/// A resident or staff post on the community feed. Stored at communityPosts.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    this.authorRole = 'user',
    this.image,
    this.likedBy = const [],
    this.comments = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String body;
  final UploadPayload? image;
  final List<String> likedBy;
  final List<CommunityComment> comments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isStaffPost => authorRole == 'admin' || authorRole == 'driver';

  int get likeCount => likedBy.length;

  int get commentCount => comments.length;

  bool likedByUser(String? uid) => uid != null && likedBy.contains(uid);

  static CommunityPost fromDoc(String id, Map<String, dynamic> data) {
    final rawLikes = data['likedBy'];
    final rawComments = data['comments'];
    return CommunityPost(
      id: id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? 'Neighbor',
      authorRole: (data['authorRole'] as String?) ?? 'user',
      body: (data['body'] as String?) ?? '',
      image: UploadPayload.fromMap(data['image']),
      likedBy: rawLikes is List
          ? rawLikes.whereType<String>().toList(growable: false)
          : const [],
      comments: rawComments is List
          ? rawComments
              .map(CommunityComment.fromMap)
              .toList(growable: false)
          : const [],
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
    );
  }
}
