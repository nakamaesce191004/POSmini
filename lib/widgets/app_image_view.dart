import 'package:flutter/material.dart';
import 'image_helper/app_image_stub.dart'
    if (dart.library.io) 'image_helper/app_image_native.dart'
    if (dart.library.html) 'image_helper/app_image_web.dart'
    if (dart.library.js_interop) 'image_helper/app_image_web.dart';

class AppImageView extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const AppImageView({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return AppImageImpl(
      path: path,
      fit: fit,
      width: width,
      height: height,
      errorWidget: errorWidget,
    );
  }
}
