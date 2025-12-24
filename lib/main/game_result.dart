import 'package:flutter/material.dart';
import 'package:teamproject/main/mainUI.dart'; // ⭐ MainScreen import

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GameResultPage(),
  ));
}

class GameResultPage extends StatelessWidget {
  const GameResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // 테스트용 예시 데이터
    const bool isVictory = true;
    const int playerScore = 1250;
    const int playTime = 345; // 초 단위

    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Container(color: Colors.black.withOpacity(0.25)),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    _buildResultHeader(isVictory),

                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child:
                      _buildScoreBoard(playerScore, playTime, isVictory),
                    ),

                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 0, 25, 40),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              text: "다시 하기",
                              isPrimary: false,
                              onTap: () {
                                print("Retry 클릭");
                              },
                            ),
                          ),
                          const SizedBox(width: 15),

                          // ⭐ 메인으로 버튼 (수정된 부분)
                          Expanded(
                            child: _buildActionButton(
                              text: "메인으로",
                              isPrimary: true,
                              onTap: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MainScreen(),
                                  ),
                                      (route) => false,
                                );
                              },
                            ),
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

  /* ================== 결과 헤더 ================== */

  Widget _buildResultHeader(bool isVictory) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isVictory
                    ? const Color(0xFFE6AD5C)
                    : Colors.black)
                    .withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            isVictory
                ? Icons.emoji_events_rounded
                : Icons.mood_bad_rounded,
            size: 100,
            color: isVictory
                ? const Color(0xFFE6AD5C)
                : const Color(0xFFBCAAA4),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          isVictory ? "VICTORY" : "GAME OVER",
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color:
            isVictory ? const Color(0xFFE6AD5C) : Colors.white,
            letterSpacing: 3.0,
            shadows: const [
              Shadow(
                  offset: Offset(0, 4),
                  blurRadius: 8,
                  color: Colors.black54),
            ],
          ),
        ),
      ],
    );
  }

  /* ================== 스코어 보드 ================== */

  Widget _buildScoreBoard(int score, int time, bool isVictory) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6).withOpacity(0.95),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: isVictory
              ? const Color(0xFFE6AD5C)
              : const Color(0xFFD7C0A1),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "FINAL SCORE",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8D6E63),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            score.toString(),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 15),
          _buildDetailRow(
              Icons.timer_outlined,
              "Play Time",
              "${time ~/ 60}m ${time % 60}s"),
          _buildDetailRow(
              Icons.auto_awesome_outlined, "Experience", "+450 XP"),
          _buildDetailRow(Icons.military_tech_outlined, "Final Rank",
              isVictory ? "S Class" : "B Class"),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFE6AD5C)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF8D6E63),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
        ],
      ),
    );
  }

  /* ================== 버튼 ================== */

  Widget _buildActionButton({
    required String text,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: isPrimary
            ? const LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFE6AD5C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
            : null,
        color: isPrimary ? null : Colors.white.withOpacity(0.9),
        border: Border.all(
          color: isPrimary
              ? const Color(0xFFC6A700)
              : const Color(0xFFD7C0A1),
          width: 2.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
