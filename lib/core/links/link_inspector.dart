import 'punycode.dart';

enum LinkScript { latin, cyrillic, greek, armenian }

enum LinkWarningKind {
  textMismatch,
  userInfo,
  mixedScripts,
  lookalikeScript,
  invisibleCharacters,
  ipAddress,
  unusualScheme,
}

typedef LinkLetter = ({String letter, LinkScript script});

class LinkWarning {
  const LinkWarning(this.kind, {this.value = '', this.letters = const []});

  final LinkWarningKind kind;
  final String value;
  final List<LinkLetter> letters;
}

class LinkInspection {
  const LinkInspection({
    required this.url,
    required this.address,
    required this.host,
    required this.hostStart,
    required this.hostEnd,
    required this.flagged,
    required this.warnings,
  });

  final String url;
  final String address;
  final String host;
  final int hostStart;
  final int hostEnd;
  final Set<int> flagged;
  final List<LinkWarning> warnings;

  bool get suspicious => warnings.isNotEmpty;
}

const Set<String> _ordinarySchemes = {
  'http',
  'https',
  'mailto',
  'tel',
  'geo',
  'komet',
  'max',
};

const Map<LinkScript, String> _latinLookalikes = {
  LinkScript.cyrillic: 'асеорхуіјѕһԁԛԝӏү',
  LinkScript.greek: 'αικνορτυχ',
  LinkScript.armenian: 'ոսօհզ',
};

final RegExp _ipHost = RegExp(
  r'^(?:\[[0-9a-f:.]*\]|[0-9.]+|0x[0-9a-f]+(?:\.[0-9a-fx]+)*)$',
  caseSensitive: false,
);

final RegExp _domainTld = RegExp(r'^\p{L}{2,}$', unicode: true);

final RegExp _schemePrefix = RegExp(
  r'^[a-z][a-z0-9+.-]*:',
  caseSensitive: false,
);

final RegExp _hostWithPort = RegExp(
  r'^[^\s/:?#@]+\.[^\s/:?#@]+:\d+(?:[/?#]|$)',
);

String linkWithScheme(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  final hasScheme =
      _schemePrefix.hasMatch(trimmed) && !_hostWithPort.hasMatch(trimmed);
  return hasScheme ? trimmed : 'https://$trimmed';
}

LinkInspection inspectLink(String url, {String? shownText}) {
  final raw = linkWithScheme(url);
  final scheme = _schemeOf(raw);
  final parts = _AuthorityParts.of(raw);
  final address = _AddressBuilder();
  final warnings = <LinkWarning>[];

  if (parts == null) {
    address.add(raw);
    if (address.hasInvisible) {
      warnings.add(const LinkWarning(LinkWarningKind.invisibleCharacters));
    }
    if (scheme.isNotEmpty && !_ordinarySchemes.contains(scheme)) {
      warnings.add(LinkWarning(LinkWarningKind.unusualScheme, value: scheme));
    }
    return LinkInspection(
      url: raw,
      address: address.text,
      host: '',
      hostStart: -1,
      hostEnd: -1,
      flagged: address.flagged,
      warnings: warnings,
    );
  }

  final asciiHost = raw.substring(parts.hostStart, parts.hostEnd);
  final decodedHost = _percentDecoded(asciiHost).toLowerCase();
  final host = decodePunycodeHost(decodedHost) ?? decodedHost;
  final scripts = _ScriptReport.of(host);

  address.add(raw.substring(0, parts.userInfoStart));
  if (parts.hasUserInfo) {
    address.add(
      raw.substring(parts.userInfoStart, parts.hostStart),
      flag: true,
    );
  }
  final hostStart = address.length;
  address.add(host, flagAt: scripts.flagged);
  final hostEnd = address.length;
  address.add(_readableTail(raw.substring(parts.hostEnd)));

  final shownHost = shownText == null ? null : _hostShownBy(shownText);
  if (shownHost != null && !_sameSite(shownHost, host)) {
    warnings.add(LinkWarning(LinkWarningKind.textMismatch, value: shownHost));
  }
  if (parts.hasUserInfo) {
    warnings.add(LinkWarning(LinkWarningKind.userInfo, value: host));
  }
  if (scripts.mixed.isNotEmpty) {
    warnings.add(
      LinkWarning(LinkWarningKind.mixedScripts, letters: scripts.mixed),
    );
  }
  if (scripts.lookalike.isNotEmpty) {
    warnings.add(
      LinkWarning(LinkWarningKind.lookalikeScript, letters: scripts.lookalike),
    );
  }
  if (address.hasInvisible) {
    warnings.add(const LinkWarning(LinkWarningKind.invisibleCharacters));
  }
  if (host.isNotEmpty && _ipHost.hasMatch(host)) {
    warnings.add(LinkWarning(LinkWarningKind.ipAddress, value: host));
  }
  if (scheme.isNotEmpty && !_ordinarySchemes.contains(scheme)) {
    warnings.add(LinkWarning(LinkWarningKind.unusualScheme, value: scheme));
  }

  return LinkInspection(
    url: raw,
    address: address.text,
    host: host,
    hostStart: hostStart,
    hostEnd: hostEnd,
    flagged: address.flagged,
    warnings: warnings,
  );
}

bool _isInvisible(int rune) =>
    rune < 0x20 ||
    rune == 0x7F ||
    rune == 0xA0 ||
    rune == 0xAD ||
    rune == 0x34F ||
    rune == 0x61C ||
    rune == 0x115F ||
    rune == 0x1160 ||
    rune == 0x17B4 ||
    rune == 0x17B5 ||
    rune == 0x180E ||
    (rune >= 0x2000 && rune <= 0x200F) ||
    (rune >= 0x2028 && rune <= 0x202F) ||
    (rune >= 0x205F && rune <= 0x206F) ||
    rune == 0x3000 ||
    rune == 0x3164 ||
    rune == 0xFEFF ||
    rune == 0xFFA0 ||
    (rune >= 0xE0000 && rune <= 0xE007F);

LinkScript? _scriptOf(int rune) {
  if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
    return LinkScript.latin;
  }
  if (rune >= 0xC0 && rune <= 0x24F && rune != 0xD7 && rune != 0xF7) {
    return LinkScript.latin;
  }
  if (rune >= 0x1E00 && rune <= 0x1EFF) return LinkScript.latin;
  if ((rune >= 0x400 && rune <= 0x52F) ||
      (rune >= 0x1C80 && rune <= 0x1C8F) ||
      (rune >= 0x2DE0 && rune <= 0x2DFF) ||
      (rune >= 0xA640 && rune <= 0xA69F)) {
    return LinkScript.cyrillic;
  }
  if ((rune >= 0x370 && rune <= 0x3FF) || (rune >= 0x1F00 && rune <= 0x1FFF)) {
    return LinkScript.greek;
  }
  if (rune >= 0x530 && rune <= 0x58F) return LinkScript.armenian;
  return null;
}

String _schemeOf(String raw) {
  final prefix = _schemePrefix.firstMatch(raw)?.group(0);
  if (prefix == null) return '';
  return prefix.substring(0, prefix.length - 1).toLowerCase();
}

String _readableTail(String tail) {
  final decoded = _percentDecodedFull(tail);
  return decoded.runes.any(_isInvisible) ? tail : decoded;
}

String _percentDecoded(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  } on FormatException {
    return value;
  }
}

String _percentDecodedFull(String value) {
  try {
    return Uri.decodeFull(value);
  } on ArgumentError {
    return value;
  } on FormatException {
    return value;
  }
}

String? _hostShownBy(String shownText) {
  final text = shownText.trim();
  if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
  final candidate = text.contains('://') ? text : 'https://$text';
  final parts = _AuthorityParts.of(candidate);
  if (parts == null) return null;
  final decoded = _percentDecoded(
    candidate.substring(parts.hostStart, parts.hostEnd),
  ).toLowerCase();
  final host = decodePunycodeHost(decoded) ?? decoded;
  final labels = host.split('.');
  if (labels.length < 2 || labels.any((l) => l.isEmpty)) return null;
  if (!_domainTld.hasMatch(labels.last)) return null;
  return host;
}

bool _sameSite(String a, String b) {
  String bare(String host) =>
      host.startsWith('www.') ? host.substring(4) : host;
  final left = bare(a);
  final right = bare(b);
  return left == right || left.endsWith('.$right') || right.endsWith('.$left');
}

class _AuthorityParts {
  const _AuthorityParts({
    required this.userInfoStart,
    required this.hostStart,
    required this.hostEnd,
  });

  final int userInfoStart;
  final int hostStart;
  final int hostEnd;

  bool get hasUserInfo => hostStart > userInfoStart;

  static _AuthorityParts? of(String raw) {
    final schemeEnd = raw.indexOf('://');
    if (schemeEnd <= 0) return null;
    final start = schemeEnd + 3;
    var end = raw.length;
    for (var i = start; i < raw.length; i++) {
      final unit = raw[i];
      if (unit == '/' || unit == '?' || unit == '#' || unit == r'\') {
        end = i;
        break;
      }
    }
    final at = end > start ? raw.lastIndexOf('@', end - 1) : -1;
    final hostStart = at >= start ? at + 1 : start;
    var hostEnd = end;
    if (hostStart < end && raw[hostStart] == '[') {
      final close = raw.indexOf(']', hostStart);
      if (close >= 0 && close < end) hostEnd = close + 1;
    } else {
      final colon = raw.indexOf(':', hostStart);
      if (colon >= 0 && colon < end) hostEnd = colon;
    }
    return _AuthorityParts(
      userInfoStart: start,
      hostStart: hostStart,
      hostEnd: hostEnd,
    );
  }
}

class _ScriptReport {
  _ScriptReport();

  final Set<int> flagged = {};
  final List<LinkLetter> mixed = [];
  final List<LinkLetter> lookalike = [];

  static _ScriptReport of(String host) {
    final report = _ScriptReport();
    final labels = host.split('.');
    final tldIsAscii = labels.last.codeUnits.every((unit) => unit < 0x80);
    var offset = 0;
    for (final label in labels) {
      report._inspectLabel(label, offset, tldIsAscii: tldIsAscii);
      offset += label.length + 1;
    }
    return report;
  }

  void _inspectLabel(String label, int offset, {required bool tldIsAscii}) {
    final byScript = <LinkScript, List<({int at, String letter})>>{};
    var at = offset;
    for (final rune in label.runes) {
      final letter = String.fromCharCode(rune);
      final script = _scriptOf(rune);
      if (script != null) {
        (byScript[script] ??= []).add((at: at, letter: letter));
      }
      at += letter.length;
    }
    if (byScript.length > 1) {
      final majority = byScript.entries.reduce((a, b) {
        if (a.value.length != b.value.length) {
          return a.value.length > b.value.length ? a : b;
        }
        return a.key == LinkScript.latin ? a : b;
      }).key;
      byScript.forEach((script, letters) {
        if (script == majority) return;
        for (final entry in letters) {
          flagged.add(entry.at);
          _addLetter(mixed, entry.letter, script);
        }
      });
      return;
    }
    if (byScript.length != 1 || !tldIsAscii) return;
    final only = byScript.entries.single;
    final lookalikes = _latinLookalikes[only.key];
    if (lookalikes == null) return;
    if (!only.value.every((entry) => lookalikes.contains(entry.letter))) {
      return;
    }
    for (final entry in only.value) {
      flagged.add(entry.at);
      _addLetter(lookalike, entry.letter, only.key);
    }
  }

  static void _addLetter(
    List<LinkLetter> into,
    String letter,
    LinkScript script,
  ) {
    if (into.any((l) => l.letter == letter)) return;
    into.add((letter: letter, script: script));
  }
}

class _AddressBuilder {
  final StringBuffer _buffer = StringBuffer();
  final Set<int> flagged = {};
  bool hasInvisible = false;

  int get length => _buffer.length;

  String get text => _buffer.toString();

  void add(String text, {bool flag = false, Set<int> flagAt = const {}}) {
    var offset = 0;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (_isInvisible(rune)) {
        hasInvisible = true;
        _flagged(_marker(rune));
      } else if (flag || flagAt.contains(offset)) {
        _flagged(char);
      } else {
        _buffer.write(char);
      }
      offset += char.length;
    }
  }

  void _flagged(String text) {
    for (var i = 0; i < text.length; i++) {
      flagged.add(_buffer.length + i);
    }
    _buffer.write(text);
  }

  static String _marker(int rune) =>
      '[U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}]';
}
