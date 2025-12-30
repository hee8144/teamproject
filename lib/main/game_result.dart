import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemNavigator
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameResult extends StatelessWidget {
  const GameResult({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameResultPage(),
    );
  }
}

class GameResultPage extends StatelessWidget {
  const GameResultPage({super.key});

  /// ================= 게임 상태 초기화 =================
  Future<void> _resetGameState() async {
    final usersDocRef =
    FirebaseFirestore.instance.collection('games').doc('users');
    final usersDoc = await usersDocRef.get();
    final usersData = usersDoc.data();
    if (usersData == null) return;

    Map<String, dynamic> updatedUsers = {};

    usersData.forEach((key, user) {
      if (user['type'] == 'N') {
        updatedUsers[key] = user;
      } else {
        updatedUsers[key] = {
          ...user,
          'money': 7000000,
          'totalMoney': 7000000,
          'position': 0,
          'card': 'N',
          'level': 1,
          'rank': 0,
          'double': 0,
          'islandCount': 0,
          'isTraveling': false,
          'turn': 0,
        };
      }
    });

    await usersDocRef.update(updatedUsers);
  }

  /// ================= DB에서 순위 가져오기 =================
  Future<List<Map<String, dynamic>>> _fetchRankData() async {
    final usersDocRef =
    FirebaseFirestore.instance.collection('games').doc('users');
    final usersDoc = await usersDocRef.get();
    final usersData = usersDoc.data();
    if (usersData == null) return [];

    List<Map<String, dynamic>> players = [];

    usersData.forEach((key, user) {
      if (user['type'] != 'N') {
        players.add({
          'name': user['name'] ?? key,
          'money': user['money'] ?? user['totalMoney'] ?? 0,
        });
      }
    });

    players.sort((a, b) => (b['money'] as int).compareTo(a['money'] as int));
    return players;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    const borderColor = Color(0xFF6D4C41);
    const paperColor = Color(0xFFFFF3E0);

    return Scaffold(
      body: Stack(
        children: [
          // 배경
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 메인
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
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: paperColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 2.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 왼쪽
                    Flexible(
                      flex: 7,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: size.width * 0.5,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE0B2),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                Border.all(color: borderColor, width: 1.8),
                              ),
                              child: const Text(
                                "최종 승리 결과",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4E342E),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "최종 순위",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E2723),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FutureBuilder<List<Map<String, dynamic>>>(
                                future: _fetchRankData(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return const Center(
                                        child: Text(
                                            "순위 정보를 불러오는 중 오류 발생"));
                                  } else if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Center(
                                        child: Text("플레이어 정보가 없습니다."));
                                  }

                                  final players = snapshot.data!;
                                  return _buildRankTable(players);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 오른쪽
                    Flexible(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionButton(
                              text: "다시 시작",
                              onTap: () async {
                                await _resetGameState();
                                context.go(
                                    '/gameWaitingRoom?types=user1,user2'); // 필요 시 수정
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              text: "종료",
                              onTap: () {
                                SystemNavigator.pop();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankTable(List<Map<String, dynamic>> players) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF6D4C41))),
      child: Table(
        border: TableBorder.symmetric(
            inside: const BorderSide(color: Colors.black26)),
        columnWidths: const {
          0: FixedColumnWidth(50),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        children: [
          _buildRankRow(rank: "순위", name: "이름", money: "잔액", isHeader: true),
          for (int i = 0; i < players.length; i++)
            _buildRankRow(
              rank: "${i + 1}위",
              name: players[i]['name'],
              money: "₩${players[i]['money']}",
            ),
        ],
      ),
    );
  }

  TableRow _buildRankRow({
    required String rank,
    required String name,
    required String money,
    bool isHeader = false,
  }) {
    return TableRow(
      decoration: BoxDecoration(color: isHeader ? const Color(0xFFFFEFD5) : null),
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
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD7CCC8),
          foregroundColor: const Color(0xFF3E2723),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: Color(0xFF6D4C41),
              width: 1.8,
            ),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _RankCell extends StatelessWidget {
  final String text;
  final bool isHeader;

  const _RankCell({
    required this.text,
    required this.isHeader,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? 14 : 12,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF4E342E),
          ),
        ),
      ),
    );
  }
}
