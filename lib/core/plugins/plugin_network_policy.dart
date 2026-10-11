import 'dart:io';

class PluginNetworkPolicy {
  PluginNetworkPolicy._();

  static Uri httpsUri(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) throw const FormatException('Некорректный URL');
    validateUri(uri);
    return uri;
  }

  static void validateUri(Uri uri, {bool allowHttpForTesting = false}) {
    if ((uri.scheme != 'https' &&
            !(allowHttpForTesting && uri.scheme == 'http')) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Разрешены только корректные HTTPS URL');
    }
    if (allowHttpForTesting) return;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost')) {
      throw const FormatException('Локальные адреса запрещены');
    }
    final literal = InternetAddress.tryParse(host);
    if (literal != null) validateAddresses([literal]);
  }

  static void validateAddresses(List<InternetAddress> addresses) {
    if (addresses.isEmpty || addresses.any(isPrivateAddress)) {
      throw const FormatException('Локальные адреса запрещены');
    }
  }

  static bool isPrivateAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal) return true;
    var bytes = address.rawAddress;
    if (bytes.length == 16 &&
        bytes.take(10).every((b) => b == 0) &&
        bytes[10] == 255 &&
        bytes[11] == 255) {
      bytes = bytes.sublist(12);
    }
    if (bytes.length == 4) {
      return bytes[0] == 0 ||
          bytes[0] == 10 ||
          bytes[0] == 127 ||
          (bytes[0] == 169 && bytes[1] == 254) ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168) ||
          (bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19)) ||
          (bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 0) ||
          (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127) ||
          bytes[0] >= 224;
    }
    return (bytes[0] & 0xe0) != 0x20 ||
        (bytes[0] == 0x20 && bytes[1] == 0x02) ||
        (bytes[0] == 0x20 &&
            bytes[1] == 0x01 &&
            bytes[2] == 0 &&
            bytes[3] == 0) ||
        bytes.every((b) => b == 0) ||
        (bytes[0] & 0xfe) == 0xfc ||
        (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) ||
        bytes[0] == 0xff;
  }

  static HttpClient createClient({
    bool allowHttpForTesting = false,
    Future<List<InternetAddress>> Function(String host)? lookup,
  }) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      validateUri(uri, allowHttpForTesting: allowHttpForTesting);
      if (proxyHost != null) {
        throw const FormatException('Proxy is not supported');
      }
      final addresses = await (lookup ?? InternetAddress.lookup)(
        uri.host,
      ).timeout(const Duration(seconds: 10));
      if (!allowHttpForTesting) validateAddresses(addresses);
      if (addresses.isEmpty) throw const SocketException('No address for host');
      ConnectionTask<Socket>? attempt;
      var cancelled = false;
      Future<Socket> connect() async {
        Object? lastError;
        for (final address in addresses) {
          if (cancelled) throw const SocketException('Connection cancelled');
          try {
            final task = await Socket.startConnect(address, uri.port);
            attempt = task;
            if (cancelled) {
              task.cancel();
              throw const SocketException('Connection cancelled');
            }
            return await task.socket.timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                task.cancel();
                throw const SocketException('Connection timed out');
              },
            );
          } on SocketException catch (error) {
            lastError = error;
          }
        }
        throw SocketException('Could not connect to host: $lastError');
      }

      return ConnectionTask.fromSocket(connect(), () {
        cancelled = true;
        attempt?.cancel();
      });
    };
    return client;
  }
}
