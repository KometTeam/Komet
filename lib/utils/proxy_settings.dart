enum ProxyProtocol { http, https, socks4, socks5 }

class ProxySettings {
  final bool isEnabled;
  final String host;
  final int port;
  final ProxyProtocol protocol;
  final String? username;
  final String? password;

  ProxySettings({
    this.isEnabled = false,
    this.host = '',
    this.port = 8080,
    this.protocol = ProxyProtocol.http,
    this.username,
    this.password,
  });

  String toFindProxyString() {
    if (!isEnabled || host.isEmpty) {
      return 'DIRECT';
    }

    String protocolString;
    switch (protocol) {
      case ProxyProtocol.http:
      case ProxyProtocol.https:
        protocolString = 'PROXY';
        break;
      case ProxyProtocol.socks4:
        protocolString = 'SOCKS4';
        break;
      case ProxyProtocol.socks5:
        protocolString = 'SOCKS5';
        break;
    }

    return '$protocolString $host:$port';
  }

  ProxySettings copyWith({
    bool? isEnabled,
    String? host,
    int? port,
    ProxyProtocol? protocol,
    String? username,
    String? password,
  }) {
    return ProxySettings(
      isEnabled: isEnabled ?? this.isEnabled,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'host': host,
      'port': port,
      'protocol': protocol.name,
      'username': username,
      'password': password,
    };
  }

  factory ProxySettings.fromJson(Map<String, dynamic> json) {
    return ProxySettings(
      isEnabled: json['isEnabled'] ?? false,
      host: json['host'] ?? '',
      port: json['port'] ?? 8080,
      protocol: ProxyProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => ProxyProtocol.http,
      ),
      username: json['username'],
      password: json['password'],
    );
  }
}
