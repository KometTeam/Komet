const String _prefix = 'xn--';

const int _base = 36;
const int _tMin = 1;
const int _tMax = 26;
const int _skew = 38;
const int _damp = 700;
const int _initialBias = 72;
const int _initialN = 128;
const int _maxCodePoint = 0x10FFFF;

String? decodePunycodeLabel(String label) {
  if (!label.toLowerCase().startsWith(_prefix)) return label;
  return _decode(label.substring(_prefix.length));
}

String? decodePunycodeHost(String host) {
  final labels = host.split('.');
  final decoded = <String>[];
  for (final label in labels) {
    final unicode = decodePunycodeLabel(label);
    if (unicode == null) return null;
    decoded.add(unicode);
  }
  return decoded.join('.');
}

String? _decode(String input) {
  if (input.isEmpty) return null;
  final output = <int>[];
  final delimiter = input.lastIndexOf('-');
  final basicLength = delimiter < 0 ? 0 : delimiter;
  for (var j = 0; j < basicLength; j++) {
    final unit = input.codeUnitAt(j);
    if (unit >= 0x80) return null;
    output.add(unit);
  }

  var n = _initialN;
  var bias = _initialBias;
  var i = 0;
  var index = basicLength > 0 ? basicLength + 1 : 0;
  while (index < input.length) {
    final oldI = i;
    var weight = 1;
    for (var k = _base; ; k += _base) {
      if (index >= input.length) return null;
      final digit = _digitValue(input.codeUnitAt(index++));
      if (digit < 0) return null;
      i += digit * weight;
      if (i > _maxCodePoint * (output.length + 1)) return null;
      final threshold = k <= bias
          ? _tMin
          : (k >= bias + _tMax ? _tMax : k - bias);
      if (digit < threshold) break;
      weight *= _base - threshold;
    }
    final length = output.length + 1;
    bias = _adapt(i - oldI, length, oldI == 0);
    n += i ~/ length;
    i %= length;
    if (n > _maxCodePoint || (n >= 0xD800 && n <= 0xDFFF)) return null;
    output.insert(i, n);
    i++;
  }
  return String.fromCharCodes(output);
}

int _digitValue(int unit) {
  if (unit >= 0x30 && unit <= 0x39) return unit - 0x30 + 26;
  if (unit >= 0x41 && unit <= 0x5A) return unit - 0x41;
  if (unit >= 0x61 && unit <= 0x7A) return unit - 0x61;
  return -1;
}

int _adapt(int delta, int points, bool first) {
  var value = first ? delta ~/ _damp : delta ~/ 2;
  value += value ~/ points;
  var k = 0;
  while (value > ((_base - _tMin) * _tMax) ~/ 2) {
    value ~/= _base - _tMin;
    k += _base;
  }
  return k + ((_base - _tMin + 1) * value) ~/ (value + _skew);
}
