import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> markQuranRead(String userId, String date) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('quranTracking')
        .doc(date)
        .set({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
  }

  // Admin: tüm kullanıcıları al
  Stream<QuerySnapshot> getAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Admin: kullanıcı detayı
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data();
  }
}
