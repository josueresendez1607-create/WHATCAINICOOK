import 'package:flutter/widgets.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 90, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logos/logo.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'Logotipo de WHATCANICOOK',
    );
  }
}
