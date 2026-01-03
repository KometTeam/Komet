import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:gwid/app_sizes.dart';

class GlobalImageStore {
  static final Map<String, Uint8List> _memory = {};
  static final Map<String, ValueNotifier<double?>> _progress = {};

  static Uint8List? getData(String url) => _memory[url];

  static void setData(String url, Uint8List bytes) {
    _memory[url] = bytes;
    progressFor(url).value = null;
  }

  static ValueNotifier<double?> progressFor(String url) {
    return _progress.putIfAbsent(url, () => ValueNotifier<double?>(null));
  }

  static void setProgress(String url, double? value) {
    progressFor(url).value = value;
  }
}
