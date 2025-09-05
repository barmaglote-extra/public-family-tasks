import 'package:flutter/material.dart';

mixin BackButtonMixin<T extends StatefulWidget> on State<T> {
  Future<bool> handleBackButton() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return false;
    }
    
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    return false;
  }
}
