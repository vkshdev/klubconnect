import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageUploadService {
  ImageUploadService({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  Future<String> uploadCompressedImage({
    required File image,
    required String storagePath,
    required String ownerId,
    required String institutionId,
    required String ownerType,
    int maxWidth = 1440,
    int maxHeight = 1440,
    int quality = 82,
  }) async {
    final bytes = await _compressImage(
      image,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
    final ref = _storage.ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'owner_id': ownerId,
        'owner_type': ownerType,
        'institution_id': institutionId,
      },
    );

    await ref.putData(bytes, metadata);
    final downloadUrl = await ref.getDownloadURL();
    await _recordAsset(
      storagePath: storagePath,
      ownerId: ownerId,
      ownerType: ownerType,
      institutionId: institutionId,
      size: bytes.length,
      downloadUrl: downloadUrl,
    );
    return downloadUrl;
  }

  Future<Uint8List> _compressImage(
    File image, {
    required int maxWidth,
    required int maxHeight,
    required int quality,
  }) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      image.absolute.path,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return compressed ?? await image.readAsBytes();
  }

  Future<void> _recordAsset({
    required String storagePath,
    required String ownerId,
    required String ownerType,
    required String institutionId,
    required int size,
    required String downloadUrl,
  }) {
    final assetId = base64Url.encode(utf8.encode(storagePath));
    return _firestore.collection('storage_assets').doc(assetId).set({
      'storage_path': storagePath,
      'owner_id': ownerId,
      'owner_type': ownerType,
      'institution_id': institutionId,
      'content_type': 'image/jpeg',
      'size': size,
      'download_url': downloadUrl,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
