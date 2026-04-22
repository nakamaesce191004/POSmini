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
    throw UnsupportedError('Cannot create an image without dart:html or dart:io');
  }
}
