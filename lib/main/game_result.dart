import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//
//   runApp(
//     MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: const GameResult(
//         victoryType: 'triple_monopoly',
//         winnerName: 'user1',
//       ),
//     ),
//   );
// }

class GameResult extends StatelessWidget {
  final String victoryType;
  final String? winnerName;

  const GameResult({
    super.key,
    required this.victoryType,
    this.winnerName,
  });

  /// ================= 금액 콤마 포맷 =================
  String _formatMoney(int money) {
    final formatter = NumberFormat('#,###');
    return formatter.format(money);
  }

  /// ================= 순위 계산 =================
  Future<List<Map<String, dynamic>>> _fetchPlayers() async {
    final usersDocRef =
    FirebaseFirestore.instance.collection('games').doc('users');
    final usersDoc = await usersDocRef.get();
    final usersData = usersDoc.data();

    if (usersData == null) return [];

    List<Map<String, dynamic>> players = [];

    usersData.forEach((key, user) {
      final String type = user['type'];
      final int totalMoney = user['totalMoney'] ?? 0;

      if (type == 'P' || type == 'B' || type == 'D') {
        players.add({
          'name': user['name'] ?? key,
          'totalMoney': totalMoney,
          'isBankrupt': type == 'D',
        });
      }
    });

    /// 🔴 결과 화면 전용 정렬
    if (victoryType == 'line_monopoly' ||
        victoryType == 'triple_monopoly') {
      final winner = players.firstWhere(
            (p) => p['name'] == winnerName,
        orElse: () => {},
      );

      final others =
      players.where((p) => p['name'] != winnerName).toList();

      others.sort(
            (a, b) =>
            (b['totalMoney'] as int).compareTo(a['totalMoney'] as int),
      );

      players = [
        if (winner.isNotEmpty) winner,
        ...others,
      ];
    } else {
      // bankruptcy / turn_limit
      players.sort(
            (a, b) =>
            (b['totalMoney'] as int).compareTo(a['totalMoney'] as int),
      );
    }

    /// rank 부여
    for (int i = 0; i < players.length; i++) {
      players[i]['rank'] = i + 1;
    }

    return players;
  }

  /// ================= 승자 이름 계산 =================
  String _determineWinner(List<Map<String, dynamic>> players) {
    if (winnerName != null && winnerName != '0') {
      return winnerName!;
    }

    final nonBankruptPlayers =
    players.where((p) => p['isBankrupt'] == false).toList();

    if (nonBankruptPlayers.isNotEmpty) {
      nonBankruptPlayers.sort(
            (a, b) =>
            (b['totalMoney'] as int).compareTo(a['totalMoney'] as int),
      );
      return nonBankruptPlayers.first['name'];
    }

    return '무명';
  }

  /// ================= 승리 조건 텍스트 =================
  String _victoryTypeText() {
    switch (victoryType) {
      case 'triple_monopoly':
        return '🎯 트리플 독점 승리!';
      case 'line_monopoly':
        return '🎯 라인 독점 승리!';
      case 'bankruptcy':
        return '🎉 파산 승리!';
      case 'turn_limit':
        return '⏰ 턴 종료에 의한 승리!';
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
                    return const CircularProgressIndicator();
                  }

                  final players = snapshot.data!;
                  final winner = _determineWinner(players);

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
                                "최종 승리 결과",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${_victoryTypeText()} 🏆 전국을 여행하며 문화재를 지켜낸 $winner 이 바로 최후의 승자입니다!",
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
                              _buildActionButton(
                                text: "다시 시작",
                                onTap: () {
                                  GoRouter.of(context)
                                      .go('/gameWaitingRoom');
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildActionButton(
                                text: "종료",
                                onTap: () => SystemNavigator.pop(),
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

  /// ================= 🔥 수정된 핵심 로직 =================
  Widget _buildRankTable(List<Map<String, dynamic>> players) {
    return Table(
      border: TableBorder.all(color: Colors.black26),
      children: [
        _buildRankRow(rank: "순위", name: "이름", money: "잔액", isHeader: true),
        for (final p in players)
          _buildRankRow(
            rank: _rankText(p),
            name: p['name'],
            money: "₩${_formatMoney(p['totalMoney'])}",
          ),
      ],
    );
  }

  /// 🔥 승자 표기 로직 분리 (가독성 + 규칙 명확화)
  String _rankText(Map<String, dynamic> p) {
    final bool isWinnerByMonopoly =
        (victoryType == 'line_monopoly' ||
            victoryType == 'triple_monopoly') &&
            p['name'] == winnerName;

    final bool isWinnerByBankruptcy =
        victoryType == 'bankruptcy' && p['rank'] == 1;

    if (isWinnerByMonopoly || isWinnerByBankruptcy) {
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
          ),
        ),
      ),
    );
  }
}
