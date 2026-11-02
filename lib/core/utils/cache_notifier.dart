import 'package:flutter/foundation.dart';

class CacheNotifier<T> extends ValueNotifier<T> {
  CacheNotifier(super.value);

  bool get isObserved => hasListeners;
}
