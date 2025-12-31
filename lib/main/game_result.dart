import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// ================= 앱 단독 실행용 main =================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const GameResult());
}


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

  /// ================= 현재 유저 타입 저장 =================
  Future<String> _saveUserTypesBeforeReset() async {
    final usersDocRef =
    FirebaseFirestore.instance.collection('games').doc('users');
    final usersDoc = await usersDocRef.get();
    final usersData = usersDoc.data();

    if (usersData == null) return 'N,N,N,N';

    List<String> types = ['N', 'N', 'N', 'N'];

    for (int i = 1; i <= 4; i++) {
      final user = usersData['user$i'];
      if (user != null && user['type'] != null) {
        types[i - 1] = user['type'];
      }
    }

    // 예: "P,N,B,N"
    return types.join(',');
  }

  /// ================= 순위 + 파산승리 여부 =================
  Future<Map<String, dynamic>> _fetchResultData() async {
    final usersDocRef =
    FirebaseFirestore.instance.collection('games').doc('users');
    final usersDoc = await usersDocRef.get();
    final usersData = usersDoc.data();

    if (usersData == null) {
      return {'players': [], 'isBankruptcyWin': false};
    }

    List<Map<String, dynamic>> players = [];
    bool isBankruptcyWin = false;

    usersData.forEach((key, user) {
      final String type = user['type'];
      final int money = user['money'] ?? 0;

      if (type == 'P' || type == 'B' || type == 'D') {
        players.add({
          'name': user['name'] ?? key,
          'rank': user['rank'] ?? 99,
          'money': money,
          'isBankrupt': type == 'D', // ✅ type D면 파산으로 처리
        });

        if (money <= 0) {
          isBankruptcyWin = true;
        }
      }
    });

    players.sort(
            (a, b) => (a['rank'] as int).compareTo(b['rank'] as int));

    return {
      'players': players,
      'isBankruptcyWin': isBankruptcyWin,
    };
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
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(18),
                  border:
                  Border.all(color: const Color(0xFF6D4C41), width: 2.5),
                ),
                child: Row(
                  children: [
                    /// 왼쪽 (결과)
                    Expanded(
                      flex: 7,
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _fetchResultData(),
                          // 기존 FutureBuilder<Map<String, dynamic>> 안에서
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final players = snapshot.data!['players'] as List<Map<String, dynamic>>;
                            final bool isBankruptcyWin = snapshot.data!['isBankruptcyWin'];

                            // ✅ 승자 계산: 파산이 아닌 사람 중 잔액 최대
                            String winnerName = '';
                            final nonBankruptPlayers = players.where((p) => p['isBankrupt'] == false).toList();
                            if (nonBankruptPlayers.isNotEmpty) {
                              nonBankruptPlayers.sort((a, b) => (b['money'] as int).compareTo(a['money'] as int));
                              winnerName = nonBankruptPlayers.first['name'];
                            }

                            return Column(
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
                                  "🏆 전국을 여행하며 문화재를 지켜낸 $winnerName 당신이 바로 최후의 승자입니다!",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                if (isBankruptcyWin)
                                  const Text(
                                    "🎉 파산승리!",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                _buildRankTable(players),
                              ],
                            );
                          }

                      ),
                    ),

                    /// 오른쪽 (버튼)
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildActionButton(
                            text: "다시 시작",
                            onTap: () async {
                              // 1️⃣ 현재 유저 타입 저장
                              final String typesQuery =
                              await _saveUserTypesBeforeReset();



                              // 3️⃣ 대기방으로 전달
                              context.go(
                                  '/gameWaitingRoom?types=$typesQuery');
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
        _buildRankRow(rank: "순위", name: "이름", money: "잔액", isHeader: true),
        for (final p in players)
          _buildRankRow(
            rank: p['isBankrupt']
                ? "${p['rank']}위 (파산)"
                : "${p['rank']}위",
            name: p['name'],
            money: "₩${p['money']}",
          ),
      ],
    );
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
