import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../game/gameMain.dart';
import 'mainUI.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const GameResultTestApp());
}

class GameResultTestApp extends StatelessWidget {
  const GameResultTestApp({super.key});

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    const borderColor = Color(0xFF6D4C41);
    const paperColor = Color(0xFFFFF3E0);

    return Scaffold(
      body: Stack(
        children: [
          /// 배경
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Container(
                // 1. 전체 높이를 내용에 맞게 조절하기 위해 상하 패딩 최적화
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: paperColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 2.5),
                ),
                // 2. MainAxisSize.min을 사용하여 불필요한 수직 확장 방지
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // ================= 왼쪽 =================
                      Expanded(
                        flex: 7,
                        child: Column(
                          mainAxisSize: MainAxisSize.min, // 3. 내용물만큼만 차지
                          children: [
                            /// 🏆 승리 문구
                            Container(
                              width: size.width * 0.36,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE0B2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor, width: 1.8),
                              ),
                              child: const Text(
                                "플레이어 1 우승: 🏆 문화재 독점 달성 🏆",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4E342E),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10), // 여백 소폭 축소

                            const Text(
                              "최종 순위",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E2723),
                              ),
                            ),

                            const SizedBox(height: 6), // 여백 소폭 축소

                            // 4. 고정 높이를 제거하거나 대폭 줄여 표 하단 여백 제거
                            SizedBox(
                              width: double.infinity,
                              child: _buildRankTable(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ================= 오른쪽 =================
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionButton(
                              text: "다시 시작",
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GameMain(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12), // 버튼 사이 간격 소폭 축소
                            _buildActionButton(
                              text: "종료",
                              onTap: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MainScreen(),
                                  ),
                                      (_) => false,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ================= 순위 테이블 =================
  Widget _buildRankTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF6D4C41)),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: const BorderSide(color: Colors.black26),
        ),
        columnWidths: const {
          0: FixedColumnWidth(50), // 너비 소폭 축소
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        children: [
          _buildRankRow(rank: "순위", name: "이름", money: "잔액", isHeader: true),
          _buildRankRow(rank: "1위", name: "플레이어1", money: "₩3,200"),
          _buildRankRow(rank: "2위", name: "봇2", money: "₩2,100"),
          _buildRankRow(rank: "3위", name: "플레이어3", money: "₩900"),
          _buildRankRow(rank: "4위", name: "봇4", money: "₩0"),
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
      decoration: BoxDecoration(
        color: isHeader ? const Color(0xFFFFEFD5) : null,
      ),
      children: [
        _RankCell(text: rank, isHeader: isHeader),
        _RankCell(text: name, isHeader: isHeader),
        _RankCell(text: money, isHeader: isHeader),
      ],
    );
  }

  /// ================= 버튼 =================
  Widget _buildActionButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 130, // 너비 소폭 축소
      height: 44, // 높이 소폭 축소
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 4), // 셀 내부 여백 축소
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? 13 : 12,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF4E342E),
          ),
        ),
      ),
    );
  }
}