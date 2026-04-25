import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadWishAsset({
    required String wishId,
    required Uint8List file,
    required String fileName,
    String? contentType,
  }) async {
    final ref = _storage.ref('wishes/$wishId/$fileName');
    await ref.putData(file, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<String> uploadWishImage({
    required String wishId,
    required Uint8List file,
    required int index,
  }) {
    return uploadWishAsset(
      wishId: wishId,
      file: file,
      fileName: 'photo_$index.jpg',
      contentType: 'image/jpeg',
    );
  }
}
