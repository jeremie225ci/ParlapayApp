import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseStorageRepositoryProvider = Provider<FirebaseStorageRepository>(
  (ref) => FirebaseStorageRepository(firebaseStorage: FirebaseStorage.instance),
);

class FirebaseStorageRepository {
  final FirebaseStorage firebaseStorage;

  FirebaseStorageRepository({required this.firebaseStorage});

  Future<String> storeFileToFirebase(String path, dynamic file) async {
    UploadTask? uploadTask;
    if (file is File) {
      uploadTask = firebaseStorage.ref().child(path).putFile(file);
    } else if (file is Uint8List) {
      uploadTask = firebaseStorage.ref().child(path).putData(file);
    } else {
      throw Exception('El tipo de archivo no es soportado');
    }

    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }
}
