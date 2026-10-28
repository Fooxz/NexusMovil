import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';

/// Imagen elegida, lista para subir al bucket `product-images`.
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}

/// Elige una imagen de la galería. Las pruebas lo reemplazan.
abstract class ProductImagePicker {
  /// `null` si la tienda canceló. Lanza `FieldValidationFailure` si el
  /// archivo no es JPG, PNG o WEBP o pesa más de 5 MB (límites del bucket).
  Future<PickedImage?> pick();
}

class GalleryImagePicker implements ProductImagePicker {
  final _picker = ImagePicker();

  static const maxBytes = 5 * 1024 * 1024;
  static const _types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  @override
  Future<PickedImage?> pick() async {
    // Se reduce en el teléfono: menos datos y casi siempre bajo el límite.
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    final contentType = file.mimeType ?? _types[extension];
    if (contentType == null || !_types.containsValue(contentType)) {
      throw const FieldValidationFailure(field: 'images', message: 'Usa imágenes JPG, PNG o WEBP.');
    }
    if (bytes.length > maxBytes) {
      throw const FieldValidationFailure(field: 'images', message: 'Cada imagen puede pesar hasta 5 MB.');
    }
    return PickedImage(
      bytes: bytes,
      extension: contentType == 'image/jpeg' ? 'jpg' : contentType.split('/').last,
      contentType: contentType,
    );
  }
}
