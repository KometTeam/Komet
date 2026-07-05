enum CheckersSide { white, black }

class Checkers {
  static const int size = 8;
  static const int empty = 0;
  static const int whiteMan = 1;
  static const int whiteKing = 2;
  static const int blackMan = 3;
  static const int blackKing = 4;

  static const List<List<int>> _dirs = [
    [-1, -1],
    [-1, 1],
    [1, -1],
    [1, 1],
  ];

  static List<int> initial() {
    final board = List<int>.filled(size * size, empty);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if ((r + c) % 2 == 0) continue;
        final i = r * size + c;
        if (r <= 2) board[i] = blackMan;
        if (r >= 5) board[i] = whiteMan;
      }
    }
    return board;
  }

  static CheckersSide? sideOf(int piece) {
    if (piece == whiteMan || piece == whiteKing) return CheckersSide.white;
    if (piece == blackMan || piece == blackKing) return CheckersSide.black;
    return null;
  }

  static bool isKing(int piece) => piece == whiteKing || piece == blackKing;

  static CheckersSide opponent(CheckersSide side) =>
      side == CheckersSide.white ? CheckersSide.black : CheckersSide.white;

  static int _row(int i) => i ~/ size;
  static int _col(int i) => i % size;
  static bool _inB(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;
  static int _idx(int r, int c) => r * size + c;
  static int _lastRow(CheckersSide side) =>
      side == CheckersSide.white ? 0 : size - 1;
  static int _kingOf(CheckersSide side) =>
      side == CheckersSide.white ? whiteKing : blackKing;

  static List<List<int>> legalMoves(List<int> board, CheckersSide side) {
    final captures = <List<int>>[];
    for (var i = 0; i < board.length; i++) {
      if (sideOf(board[i]) != side) continue;
      _collectCaptures(List<int>.of(board), i, side, [i], <int>{}, captures);
    }
    if (captures.isNotEmpty) return captures;

    final quiet = <List<int>>[];
    for (var i = 0; i < board.length; i++) {
      if (sideOf(board[i]) != side) continue;
      _collectQuiet(board, i, side, quiet);
    }
    return quiet;
  }

  static void _collectCaptures(
    List<int> work,
    int at,
    CheckersSide side,
    List<int> path,
    Set<int> captured,
    List<List<int>> out,
  ) {
    final steps = _captureSteps(work, at, captured);
    if (steps.isEmpty) {
      if (path.length > 1) out.add(List<int>.of(path));
      return;
    }
    final piece = work[at];
    for (final step in steps) {
      final landing = step[0];
      final victim = step[1];
      final promote = !isKing(piece) && _row(landing) == _lastRow(side);
      final moved = promote ? _kingOf(side) : piece;

      work[at] = empty;
      work[landing] = moved;
      captured.add(victim);
      path.add(landing);

      _collectCaptures(work, landing, side, path, captured, out);

      path.removeLast();
      captured.remove(victim);
      work[landing] = empty;
      work[at] = piece;
    }
  }

  static List<List<int>> _captureSteps(
    List<int> work,
    int at,
    Set<int> captured,
  ) {
    final piece = work[at];
    final side = sideOf(piece);
    if (side == null) return const [];
    final king = isKing(piece);
    final r0 = _row(at);
    final c0 = _col(at);
    final result = <List<int>>[];

    for (final d in _dirs) {
      var r = r0 + d[0];
      var c = c0 + d[1];
      if (king) {
        while (_inB(r, c) && work[_idx(r, c)] == empty) {
          r += d[0];
          c += d[1];
        }
        if (!_inB(r, c)) continue;
        final vi = _idx(r, c);
        if (sideOf(work[vi]) == side || captured.contains(vi)) continue;
        var lr = r + d[0];
        var lc = c + d[1];
        while (_inB(lr, lc) && work[_idx(lr, lc)] == empty) {
          result.add([_idx(lr, lc), vi]);
          lr += d[0];
          lc += d[1];
        }
      } else {
        if (!_inB(r, c)) continue;
        final vi = _idx(r, c);
        if (work[vi] == empty ||
            sideOf(work[vi]) == side ||
            captured.contains(vi)) {
          continue;
        }
        final lr = r + d[0];
        final lc = c + d[1];
        if (_inB(lr, lc) && work[_idx(lr, lc)] == empty) {
          result.add([_idx(lr, lc), vi]);
        }
      }
    }
    return result;
  }

  static void _collectQuiet(
    List<int> board,
    int at,
    CheckersSide side,
    List<List<int>> out,
  ) {
    final piece = board[at];
    final r0 = _row(at);
    final c0 = _col(at);
    if (isKing(piece)) {
      for (final d in _dirs) {
        var r = r0 + d[0];
        var c = c0 + d[1];
        while (_inB(r, c) && board[_idx(r, c)] == empty) {
          out.add([at, _idx(r, c)]);
          r += d[0];
          c += d[1];
        }
      }
    } else {
      final forward = side == CheckersSide.white ? -1 : 1;
      for (final dc in const [-1, 1]) {
        final r = r0 + forward;
        final c = c0 + dc;
        if (_inB(r, c) && board[_idx(r, c)] == empty) {
          out.add([at, _idx(r, c)]);
        }
      }
    }
  }

  static List<int> applyMove(List<int> board, List<int> path) {
    final next = List<int>.of(board);
    if (path.length < 2) return next;
    final from = path.first;
    final side = sideOf(board[from]);
    if (side == null) return next;
    final piece = board[from];
    next[from] = empty;
    var promoted = isKing(piece);

    for (var k = 0; k < path.length - 1; k++) {
      final a = path[k];
      final b = path[k + 1];
      final dr = (_row(b) - _row(a)).sign;
      final dc = (_col(b) - _col(a)).sign;
      var r = _row(a) + dr;
      var c = _col(a) + dc;
      while (r != _row(b) || c != _col(b)) {
        final vi = _idx(r, c);
        if (next[vi] != empty && sideOf(next[vi]) != side) {
          next[vi] = empty;
        }
        r += dr;
        c += dc;
      }
      if (_row(b) == _lastRow(side)) promoted = true;
    }

    next[path.last] = promoted ? _kingOf(side) : piece;
    return next;
  }

  static bool _hasPieces(List<int> board, CheckersSide side) =>
      board.any((p) => sideOf(p) == side);

  static CheckersSide? winner(List<int> board, CheckersSide toMove) {
    if (!_hasPieces(board, toMove) || legalMoves(board, toMove).isEmpty) {
      return opponent(toMove);
    }
    return null;
  }
}
