import 'package:cloud_firestore/cloud_firestore.dart';

class AuditRepository {
  AuditRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const pageSize = 50;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('admin_audit');

  Future<QuerySnapshot<Map<String, dynamic>>> fetchLatest() =>
      _entries.orderBy('at', descending: true).limit(pageSize).get();

  Future<QuerySnapshot<Map<String, dynamic>>> loadAfter(
    DocumentSnapshot<Map<String, dynamic>> cursor,
  ) {
    return _entries
        .orderBy('at', descending: true)
        .startAfterDocument(cursor)
        .limit(pageSize)
        .get();
  }
}
