import 'dart:io';
import 'package:flutter/material.dart';

class AppImageImpl extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const AppImageImpl({
    super.key,
    required this.path,
    required this.fit,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return errorWidget ?? const Icon(Icons.broken_image, color: Colors.grey);
    }

    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) =>
          errorWidget ?? const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
