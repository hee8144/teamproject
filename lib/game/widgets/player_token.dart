import 'package:flutter/material.dart';

class PlayerToken extends StatelessWidget {
  final int playerIndex;
  final Map<String, dynamic> playerData;
  final int currentTurn;
  final double boardSize;
  final double tileSize;

  const PlayerToken({
    super.key,
    required this.playerIndex,
    required this.playerData,
    required this.currentTurn,
    required this.boardSize,
    required this.tileSize,
  });

  // 좌표 계산 헬퍼 (메인과 독립적으로 계산)
  Map<String, double> _getTilePosition(int index) {
    double top = 0;
    double left = 0;

    if (index >= 0 && index <= 7) {
      top = boardSize - tileSize;
      left = boardSize - tileSize - (index * tileSize);
    } else if (index >= 8 && index <= 14) {
      left = 0;
      top = boardSize - tileSize - ((index - 7) * tileSize);
    } else if (index >= 15 && index <= 21) {
      top = 0;
      left = (index - 14) * tileSize;
    } else if (index >= 22 && index <= 27) {
      left = boardSize - tileSize;
      top = (index - 21) * tileSize;
    }
    return {'top': top, 'left': left};
  }

  @override
  Widget build(BuildContext context) {
    String type = playerData["type"] ?? "N";

    // 파산하거나 게임에 없는 유저는 표시하지 않음
    if (type == "N" || type == "D" || type == "BD") return const SizedBox();

    int position = playerData["position"] ?? 0;

    // 1. 타일의 좌상단 좌표 가져오기
    Map<String, double> pos = _getTilePosition(position);
    double tileX = pos['left']!;
    double tileY = pos['top']!;

    // 2. 말판 크기 및 중앙 정렬 계산
    double tokenSize = 24.0;
    double centerOffset = (tileSize - tokenSize) / 2;
    double finalX = tileX + centerOffset;
    double finalY = tileY + centerOffset;

    // 색상 설정
    final List<Color> userColors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple
    ];

    // 내 차례인지 확인
    bool isMyTurn = (playerIndex + 1) == currentTurn;

    // 스타일 설정 (내 차례일 때만 불투명 + 테두리 강조)
    double opacity = isMyTurn ? 1.0 : 0.3;
    double borderWidth = isMyTurn ? 3.0 : 1.0;
    Color borderColor = Colors.white.withOpacity(isMyTurn ? 1.0 : 0.6);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      top: finalY,
      left: finalX,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: tokenSize,
        height: tokenSize,
        decoration: BoxDecoration(
            color: userColors[playerIndex].withOpacity(opacity),
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isMyTurn ? 0.6 : 0.1),
                  blurRadius: isMyTurn ? 5 : 1,
                  offset: const Offset(1, 1))
            ]),
      ),
    );
  }
}