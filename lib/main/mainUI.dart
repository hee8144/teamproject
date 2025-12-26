import 'package:flutter/material.dart';
import 'package:teamproject/main/game_waiting_room.dart';
import 'package:teamproject/main/game_rule.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ================= 배경 =================
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

          // ================= UI (가로 전용) =================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: _buildLandscapeLayout(context, size),
            ),
          ),
        ],
      ),
    );
  }

  /* ===================== 가로 모드 전용 ===================== */

  Widget _buildLandscapeLayout(BuildContext context, Size size) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ---------- 왼쪽 : 로고 ----------
        Expanded(
          flex: 6, // 🔥 로고 영역 자체를 키움
          child: Image.asset(
            'assets/Logo.png',
            fit: BoxFit.contain,
            height: size.height * 0.75, // 🔥 로고 높이 증가
          ),
        ),

        const SizedBox(width: 30),

        // ---------- 오른쪽 : 버튼 영역 ----------
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔼 게임 규칙 버튼 (대폭 확대)
              _buildRuleButtonLarge(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GameRulePage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // 🔽 방 만들기 버튼 패널
              _buildButtonPanel(
                context: context,
                maxWidth: size.width * 0.45,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /* ===================== 버튼 패널 ===================== */

  Widget _buildButtonPanel({
    required BuildContext context,
    required double maxWidth,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 30),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6).withOpacity(0.88),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFD7C0A1), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          width: 360,
          child: _buildMainButton(
            text: "방 만들기",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GameWaitingRoom(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /* ===================== 메인 버튼 ===================== */

  Widget _buildMainButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE6AD5C), width: 2.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* ===================== 룰 버튼 (초대형) ===================== */

  Widget _buildRuleButtonLarge({
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: const Color(0xFFE6AD5C),
            width: 3.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Image.asset(
            'assets/game_rule.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
