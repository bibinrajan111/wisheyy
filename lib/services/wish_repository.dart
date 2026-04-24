import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/wish_model.dart';

class WishRepository {
  WishRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _wishes => _firestore.collection('wishes');

  Future<void> saveWish(WishModel wish) async {
    await _wishes.doc(wish.id).set(wish.toJson());
  }

  Future<WishModel> getWish(String id) async {
    final snapshot = await _wishes.doc(id).get();
    if (!snapshot.exists) {
      throw StateError('Wish not found');
    }
    return WishModel.fromJson(snapshot.data()!);
  }
}
