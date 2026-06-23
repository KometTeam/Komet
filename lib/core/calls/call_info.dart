import 'dart:convert';

class CallInfo {
  String? conversationId;
  String? topology;

  String? peerPlatform;
  String? peerEngine;

  String? peerIp;
  String? peerNetwork;
  String? path;

  String? audioCodec;
  bool record = false;
  bool denoise = false;
  bool animoji = false;

  String? region;
  String? dtlsFingerprint;
  final List<String> stun = [];
  final List<String> turn = [];
}

class CallParse {
  static Map<String, String> candidate(String c) {
    final parts = c.trim().split(RegExp(r'\s+'));
    String? at(int i) => (i >= 0 && i < parts.length) ? parts[i] : null;
    int idx(String k) => parts.indexOf(k);
    final r = <String, String>{};
    final tr = at(2);
    if (tr != null) r['transport'] = tr.toUpperCase();
    final ip = at(4);
    if (ip != null) r['ip'] = ip;
    final port = at(5);
    if (port != null) r['port'] = port;
    final typ = idx('typ');
    if (typ != -1) r['type'] = at(typ + 1) ?? '';
    final nc = idx('network-cost');
    if (nc != -1) r['cost'] = at(nc + 1) ?? '';
    return r;
  }

  static String networkLabel(String? cost) {
    switch (cost) {
      case '0':
        return 'VPN';
      case '10':
        return 'Wi-Fi / Ethernet';
      case '50':
        return 'неизвестно';
      case '900':
      case '999':
        return 'сотовая';
      default:
        return (cost == null || cost.isEmpty) ? '—' : 'cost=$cost';
    }
  }

  static String engine(String sdp) {
    for (final line in const LineSplitter().convert(sdp)) {
      if (!line.startsWith('o=')) continue;
      final l = line.toLowerCase();
      if (l.contains('mozilla') || l.contains('sdparta')) return 'Firefox (web)';
      if (l.contains('gstreamer')) return 'GStreamer';
      return 'нативный libwebrtc';
    }
    return 'неизвестно';
  }

  static String? audioCodec(String sdp) {
    for (final line in const LineSplitter().convert(sdp)) {
      if (line.startsWith('a=rtpmap:') && line.toLowerCase().contains('opus')) {
        final i = line.indexOf(' ');
        if (i != -1) return line.substring(i + 1).trim();
      }
    }
    return null;
  }

  static String? fingerprint(String sdp) {
    for (final line in const LineSplitter().convert(sdp)) {
      if (line.startsWith('a=fingerprint:')) {
        return line.substring('a=fingerprint:'.length).trim();
      }
    }
    return null;
  }

  static bool hasAnimoji(String sdp) => sdp.contains('animoji');

  static bool isServerIp(String ip) => ip.startsWith('155.212.');

  static String pathLabel(String? localType, String? remoteType) {
    final relay = localType == 'relay' || remoteType == 'relay';
    final via = relay ? 'через сервер (TURN)' : 'прямое (P2P)';
    String t(String? v) => v ?? '?';
    return '$via · ${t(localType)} ↔ ${t(remoteType)}';
  }
}
