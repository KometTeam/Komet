import 'dart:ffi';
import 'dart:io';

typedef _InitNative =
    Int32 Function(
      Pointer<Void> ctx,
      Pointer<Void> iface,
      Pointer<Void> cfg,
      Long flags,
      Int32 version,
    );
typedef VpxInit =
    int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, int, int);

class VpxLibrary {
  VpxLibrary._(this.library);

  static const int errorAbiMismatch = 3;
  static const int _oldestAbi = 1;
  static const int _newestAbi = 96;

  final DynamicLibrary library;

  static List<String> get _candidates {
    if (Platform.isLinux) {
      return const [
        'libvpx.so',
        'libvpx.so.12',
        'libvpx.so.11',
        'libvpx.so.9',
        'libvpx.so.8',
        'libvpx.so.7',
        'libvpx.so.6',
      ];
    }
    if (Platform.isWindows) {
      return const ['vpx.dll', 'libvpx.dll', 'libvpx-1.dll'];
    }
    if (Platform.isMacOS) {
      return const [
        'libvpx.dylib',
        '/opt/homebrew/lib/libvpx.dylib',
        '/usr/local/lib/libvpx.dylib',
      ];
    }
    return const [];
  }

  static VpxLibrary? open() {
    for (final name in _candidates) {
      try {
        return VpxLibrary._(DynamicLibrary.open(name));
      } catch (_) {}
    }
    return null;
  }

  // #***! ABI-версия зашита в каждую сборку libvpx, а дистрибутивы везут разные; поля, которые мы трогаем, не менялись годами
  static int initWithAnyAbi(
    VpxInit init,
    Pointer<Void> ctx,
    Pointer<Void> iface,
    Pointer<Void> cfg, {
    required int preferred,
  }) {
    var result = init(ctx, iface, cfg, 0, preferred);
    for (
      var abi = _newestAbi;
      result == errorAbiMismatch && abi >= _oldestAbi;
      abi--
    ) {
      if (abi != preferred) result = init(ctx, iface, cfg, 0, abi);
    }
    return result;
  }

  VpxInit lookupInit(String symbol) =>
      library.lookupFunction<_InitNative, VpxInit>(symbol);
}
