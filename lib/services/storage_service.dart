import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadWishImage({
    required String wishId,
    required Uint8List file,
    required int index,
  }) async {
    final ref = _storage.ref('wishes/$wishId/photo_$index.jpg');
    await ref.putData(file);
    return ref.getDownloadURL();
  }
}
