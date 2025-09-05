import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasks/services/localization_service.dart';

/// A simple Text widget that automatically translates the given key
class LocalizedText extends StatelessWidget {
  final String translationKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Map<String, String>? params;

  const LocalizedText(
    this.translationKey, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.params,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localizationService, child) {
        return Text(
          localizationService.translate(translationKey, params: params),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

/// Extension to add easy translation access to BuildContext
extension LocalizationContext on BuildContext {
  String tr(String key, {Map<String, String>? params}) {
    return Provider.of<LocalizationService>(this, listen: false).translate(key, params: params);
  }
}
