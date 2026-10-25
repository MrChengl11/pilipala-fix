import 'package:flutter/material.dart';

Color getBorderColor(Color color) {
  var brightness =
      ((color.red * 299) + (color.green * 587) + (color.blue * 114)) / 1000;
  return brightness > 70 ? Colors.black : Colors.white;
}