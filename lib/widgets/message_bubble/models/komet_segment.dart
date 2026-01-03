import 'package:flutter/material.dart';

class KometColoredSegment {
  final String text;
  final Color? color;

  KometColoredSegment(this.text, this.color);
}

enum KometSegmentType { normal, colored, galaxy, pulse }

class KometSegment {
  final String text;
  final KometSegmentType type;
  final Color? color;

  KometSegment(this.text, this.type, {this.color});
}
