import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OnlineGameResult extends StatelessWidget {
  final String victoryType;
  final String? winnerIndex;
  final String roomId;

  const OnlineGameResult({
    super.key,
    required this.victoryType,
    required this.roomId,
    this.winnerIndex,
  });

  String _formatMoney(dynamic money) {
    int value = int.tryParse(money.toString()) ?? 0;
    final formatter = NumberFormat('#,###');
    return formatter.format(value);
  }

  Future<List<Map<String, dynamic>>> _fetchPlayers() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('online')
        .doc(roomId)
        .collection('users')
        .get();

    List<Map<String, dynamic>> players = [];

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final String type = data['type'] ?? 'N';
      final int totalMoney = int.tryParse(data['totalMoney']?.toString() ?? '0') ?? 0;

      String indexStr = doc.id.replaceAll('user', '');

      if (type != 'N') {
        players.add({
          'index': indexStr,
          'name': data['name'] ?? 'Player $indexStr',
          'totalMoney': totalMoney,
          'isBankrupt': type == 'D' || type == 'BD',
        });
      }
    }

    players.sort((a, b) => b['totalMoney'].compareTo(a['totalMoney']));

    for (int i = 0; i < players.length; i++) {
      players[i]['rank'] = i + 1;
    }

    return players;
  }

  String _findWinnerName(List<Map<String, dynamic>> players) {
    if (winnerIndex != null && winnerIndex != '0') {
      final winner = players.firstWhere(
            (p) => p['index'] == winnerIndex,
        orElse: () => {'name': '알 수 없음'},
      );
      return winner['name'];
    }
    return players.isNotEmpty ? players.first['name'] : '무명';
  }

  String _victoryTypeText() {
    switch (victoryType) {
      case 'triple_monopoly':
        return '🎯 트리플 독점 승리!';
      case 'line_monopoly':
        return '🎯 라인 독점 승리!';
      case 'bankruptcy':
        return '🎉 파산 승리!';
      case 'turn_limit':
        return '⏰ 턴 종료 승리!';
      default:
        return '🏆 승리!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              top: padding.top + 16,
              bottom: padding.bottom + 16,
              left: padding.left + 16,
              right: padding.right + 16,
            ),
            width: size.width,
            height: size.height,
            child: Center(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchPlayers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final players = snapshot.data!;
                  final winnerNameStr = _findWinnerName(players);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: const Color(0xFF6D4C41), width: 2.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "온라인 게임 결과",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${_victoryTypeText()} 🏆 치열한 경쟁 끝에 $winnerNameStr 님이 우승하셨습니다!",
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              _buildRankTable(players),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ✅ [수정됨] 다시 하기 버튼 -> 방 리스트로 이동
                              _buildActionButton(
                                text: "다시 하기",
                                onTap: () {
                                  // 닉네임을 기억하고 있다면 extra에 넣어서 보내는 것이 좋습니다.
                                  // 현재는 '게스트'로 처리될 수 있습니다.
                                  context.go('/onlineRoom');
                                },
                              ),
                              const SizedBox(height: 16),
                              // ✅ [수정됨] 게임 종료 버튼 -> 메인 화면으로 이동
                              _buildActionButton(
                                text: "게임 종료",
                                onTap: () {
                                  // 앱 메인 화면으로 이동
                                  context.go('/');
                                  // 만약 로컬 게임판으로 가고 싶다면 context.go('/gameMain'); 사용
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankTable(List<Map<String, dynamic>> players) {
    return Table(
      border: TableBorder.all(color: Colors.black26),
      children: [
        _buildRankRow(rank: "순위", name: "이름", money: "자산", isHeader: true),
        for (final p in players)
          _buildRankRow(
            rank: _rankText(p),
            name: p['name'],
            money: "₩${_formatMoney(p['totalMoney'])}",
          ),
      ],
    );
  }

  String _rankText(Map<String, dynamic> p) {
    if (p['index'] == winnerIndex) {
      return "1위 (승자)";
    }
    if (p['isBankrupt']) {
      return "${p['rank']}위 (파산)";
    }
    return "${p['rank']}위";
  }

  TableRow _buildRankRow({
    required String rank,
    required String name,
    required String money,
    bool isHeader = false,
  }) {
    return TableRow(
      children: [
        _RankCell(text: rank, isHeader: isHeader),
        _RankCell(text: name, isHeader: isHeader),
        _RankCell(text: money, isHeader: isHeader),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 140,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        child: Text(text),
      ),
    );
  }
}

class _RankCell extends StatelessWidget {
  final String text;
  final bool isHeader;

  const _RankCell({required this.text, required this.isHeader, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}