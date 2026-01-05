import 'dart:math';

class GameRules {
  /// 1. 통행료 계산 로직
  static int calculateToll({
    required int basePrice,
    required int level,
    required double multiply,
    required bool isFestival,
    required bool isDoubleTollItem,
  }) {
    // 1. 축제 배수 적용
    double finalMult = multiply;
    if (isFestival && finalMult == 1.0) finalMult *= 2;

    // 2. 건물 레벨 배수 적용
    int levelMult = 0;
    switch (level) {
      case 1: levelMult = 2; break;
      case 2: levelMult = 6; break;
      case 3: levelMult = 14; break;
      case 4: levelMult = 30; break;
      default: levelMult = 0; // 땅만 있을 때 (보통 0 혹은 기본값)
    }

    // 3. 기본 계산
    int calculated = (basePrice * finalMult * levelMult).round();

    // 4. 천사카드(상대 2배) 적용
    if (isDoubleTollItem) calculated *= 2;

    return calculated;
  }

  /// 2. 지진/태풍 공격 후 남을 레벨 계산
  static int getLevelAfterAttack(int currentLevel) {
    if (currentLevel <= 1) return 0; // 1 이하면 파괴
    return currentLevel - 1; // 아니면 1단계 하락
  }

  /// 3. 승리 조건 체크 (트리플 독점, 라인 독점)
  /// 승리 시 승리 타입 문자열("triple_monopoly", "line_monopoly") 반환, 아니면 null
  static String? checkWinCondition(Map<String, dynamic> boardList, int player) {
    // A. 트리플 독점 (Triple Monopoly) 체크
    int ownedGroups = 0;
    for (int g = 1; g <= 8; g++) {
      List<Map<String, dynamic>> groupTiles = [];

      boardList.forEach((key, val) {
        if (val is Map && val['group'] == g && val['type'] == 'land') {
          groupTiles.add(val as Map<String, dynamic>);
        }
      });

      if (groupTiles.isNotEmpty) {
        bool allMine = groupTiles.every((tile) =>
        int.tryParse(tile['owner'].toString()) == player
        );
        if (allMine) ownedGroups++;
      }
    }

    if (ownedGroups >= 3) {
      return "triple_monopoly";
    }

    // B. 라인 독점 (Line Monopoly) 체크
    List<List<int>> lines = [
      [0, 7],   // 1라인
      [7, 14],  // 2라인
      [14, 21], // 3라인
      [21, 28]  // 4라인
    ];

    for (var line in lines) {
      bool lineMonopoly = true;
      bool hasLand = false;

      for (int i = line[0]; i < line[1]; i++) {
        var tile = boardList["b$i"];
        if (tile != null && tile['type'] == 'land') {
          hasLand = true;
          if (int.tryParse(tile['owner'].toString()) != player) {
            lineMonopoly = false;
            break;
          }
        }
      }

      if (hasLand && lineMonopoly) {
        return "line_monopoly";
      }
    }

    return null; // 승리 조건 미달성
  }
}