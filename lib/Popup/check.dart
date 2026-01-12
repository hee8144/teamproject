import 'package:cloud_firestore/cloud_firestore.dart';

class WarningResult {
  final List<int> players;
  final String type; // "triple" | "line"

  WarningResult(this.players, this.type);
}

class WarningChecker {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  final List<int> players = [1, 2, 3, 4];

  Future<WarningResult?> check() async {
    final snap = await fs.collection("games").doc("board").get();
    if (!snap.exists || snap.data() == null) return null;

    final board = snap.data() as Map<String, dynamic>;

    final List<int> triple = [];
    final List<int> line = [];

    for (final player in players) {
      if (_isTripleWarning(board, player)) {
        triple.add(player);
      } else if (_isLineWarning(board, player)) {
        line.add(player);
      }
    }

    if (triple.isNotEmpty) {
      return WarningResult(triple, "triple");
    }
    if (line.isNotEmpty) {
      return WarningResult(line, "line");
    }

    return null; // 🔥 조건 불일치 → 아무 일도 안 함
  }

  /* ===== 트리플 독점 직전 ===== */

  bool _isTripleWarning(Map<String, dynamic> board, int player) {
    int completed = 0;
    bool hasAlmost = false;

    for (int g = 1; g <= 8; g++) {
      final tiles = board.values.where((tile) =>
      tile is Map &&
          tile['type'] == 'land' &&
          tile['group'] == g).toList();

      if (tiles.isEmpty) continue;

      int mine = 0;
      bool blocked = false;

      for (final tile in tiles) {
        final owner = int.tryParse(tile['owner']?.toString() ?? '0') ?? 0;
        final level = tile['level'] ?? 0;

        if (owner == player) mine++;
        else if (level == 4) {
          blocked = true;
          break;
        }
      }

      if (mine == tiles.length) completed++;
      else if (!blocked && mine == tiles.length - 1) hasAlmost = true;
    }

    return completed >= 2 && hasAlmost;
  }

  /* ===== 라인 독점 직전 ===== */

  bool _isLineWarning(Map<String, dynamic> board, int player) {
    final lines = [
      [0, 7],
      [7, 14],
      [14, 21],
      [21, 28],
    ];

    for (final line in lines) {
      int land = 0;
      int mine = 0;
      bool blocked = false;

      for (int i = line[0]; i < line[1]; i++) {
        final tile = board["b$i"];
        if (tile == null || tile['type'] != 'land') continue;

        land++;
        final owner = int.tryParse(tile['owner']?.toString() ?? '0') ?? 0;
        final level = tile['level'] ?? 0;

        if (owner == player) mine++;
        else if (level == 4) {
          blocked = true;
          break;
        }
      }

      if (!blocked && land > 0 && mine == land - 1) {
        return true;
      }
    }

    return false;
  }
}
