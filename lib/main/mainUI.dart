import 'package:flutter/material.dart';
import 'package:teamproject/main/game_waiting_room.dart';
import 'package:teamproject/main/game_rule.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final isLandscape = media.orientation == Orientation.landscape;

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

          // ================= UI =================
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isLandscape
                    ? _buildLandscapeLayout(context, size)
                    : _buildPortraitLayout(context, size),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ===================== 세로 모드 ===================== */

  Widget _buildPortraitLayout(BuildContext context, Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/Logo.png',
          width: size.width * 1, // 🔺 기존 0.65 → 더 크게
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        _buildButtonPanel(
          context: context,
          maxWidth: size.width * 0.65,
        ),
      ],
    );
  }

  /* ===================== 가로 모드 ===================== */

  Widget _buildLandscapeLayout(BuildContext context, Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ---------- 로고 (더 크게) ----------
        Image.asset(
          'assets/Logo.png',
          width: size.width * 1.0,   // 🔺 기존 0.7
          height: size.height * 0.55, // 🔺 기존 0.35
          fit: BoxFit.contain,
        ),

        // ---------- 버튼 패널 ----------
        _buildButtonPanel(
          context: context,
          maxWidth: size.width * 0.75,
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
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 25),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6).withOpacity(0.85),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFD7C0A1), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
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
            const SizedBox(width: 15),
            _buildCircleButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GameRulePage(),
                  ),
                );
              },
            ),
          ],
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
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE6AD5C), width: 2),
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* ===================== 룰 버튼 ===================== */

  Widget _buildCircleButton({
    required VoidCallback onTap,
  }) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: const Color(0xFFE6AD5C), width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: ClipOval(
            child: SizedBox.expand(
              child: Image.asset(
                'assets/game_rule.png',
                fit: BoxFit.cover, // 🔥 원을 꽉 채움
              ),
            ),
          ),
        ),
      ),
    );
  }

}
