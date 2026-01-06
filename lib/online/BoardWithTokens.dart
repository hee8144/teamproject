import 'package:flutter/material.dart';
import 'game_state.dart';

class BoardWithTokens extends StatefulWidget {
  final GameState gameState;
  final int myPlayer;

  const BoardWithTokens({
    super.key,
    required this.gameState,
    required this.myPlayer,
  });

  @override
  State<BoardWithTokens> createState() => _BoardWithTokensState();
}

class _BoardWithTokensState extends State<BoardWithTokens> {
  // 이전 위치 저장 (토큰 애니메이션용)
  final Map<int, int> prevPositions = {};

  @override
  void didUpdateWidget(covariant BoardWithTokens oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 각 플레이어 위치가 바뀌면 prevPositions 업데이트
    for (var entry in widget.gameState.users.entries) {
      final id = entry.key;
      final pos = entry.value.position;

      if (!prevPositions.containsKey(id)) {
        prevPositions[id] = pos;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBoard(),
        ..._buildTokens(),
      ],
    );
  }

  Widget _buildBoard() {
    // 단순히 Grid 표시
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: 28,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final tile = widget.gameState.board[index]!;

        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            color: _tileColor(tile),
          ),
          child: Center(child: Text("b$index")),
        );
      },
    );
  }

  List<Widget> _buildTokens() {
    final List<Widget> tokens = [];

    widget.gameState.users.forEach((id, user) {
      final currentPos = user.position;
      final prevPos = prevPositions[id] ?? currentPos;

      tokens.add(
        AnimatedPositioned(
          key: ValueKey("token$id"),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          top: _calcTop(currentPos),
          left: _calcLeft(currentPos),
          child: _buildToken(id, user),
        ),
      );

      // 다음 프레임에서 현재 위치를 prev로 업데이트
      prevPositions[id] = currentPos;
    });

    return tokens;
  }

  Widget _buildToken(int id, UserState user) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _tokenColor(id),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Center(
          child: Text(
            "P$id",
            style: const TextStyle(fontSize: 10, color: Colors.white),
          )),
    );
  }

  Color _tokenColor(int id) {
    switch (id) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.green;
      case 4:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _tileColor(TileState tile) {
    switch (tile.type) {
      case 'island':
        return Colors.orange.shade200;
      case 'chance':
        return Colors.green.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  // 위치 계산 (Grid 기준)
  double _calcTop(int pos) {
    final row = pos ~/ 7;
    return row * 50.0; // 50 픽셀 per cell
  }

  double _calcLeft(int pos) {
    final col = pos % 7;
    return col * 50.0;
  }
}
