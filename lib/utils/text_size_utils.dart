import 'package:flutter/material.dart';

// Extension method to get appropriate text scaling
extension TextSizeUtils on BuildContext {
  TextScaler getTextScaler(String textSizePreference) {
    switch (textSizePreference) {
      case 'medium':
        return TextScaler.linear(1.2);
      case 'large':
        return TextScaler.linear(1.5);
      case 'small':
      default:
        return TextScaler.linear(1.0);
    }
  }

  // Helper method to get appropriate font size adjustment
  double getFontSizeAdjustment(String textSizePreference) {
    switch (textSizePreference) {
      case 'medium':
        return 2.0;
      case 'large':
        return 4.0;
      case 'small':
      default:
        return 0.0;
    }
  }
}
