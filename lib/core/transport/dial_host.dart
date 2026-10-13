import 'dart:async';
import 'dart:io';

typedef HostLookup = Future<List<InternetAddress>> Function(String host);

const Duration dialHostLookupTimeout = Duration(seconds: 10);

Future<void> resolveDialHost(
  String host, {
  Duration timeout = dialHostLookupTimeout,
  HostLookup lookup = InternetAddress.lookup,
}) async {
  if (InternetAddress.tryParse(host) != null) return;
  await lookup(host).timeout(
    timeout,
    onTimeout: () => throw TimeoutException('DNS не ответил для $host', timeout),
  );
}
