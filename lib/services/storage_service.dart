import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadWishImage({
    required String wishId,
    required dynamic file, // File (mobile) OR Uint8List (web)
    required int index,
  }) async {
    final ref = _storage.ref('wishes/$wishId/photo_$index.jpg');

    if (kIsWeb) {
      await ref.putData(file as Uint8List);
    } else {
      await ref.putFile(file);
    }

    return await ref.getDownloadURL();
  }
}