import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teamproject/main/login.dart';
import 'package:teamproject/main/game_rule.dart';
import 'package:teamproject/main/game_waiting_room.dart';

class onlineMainScreen extends StatelessWidget {
  const onlineMainScreen({super.key});

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
          flex: 6,
          child: Image.asset(
            'assets/Logo.png',
            fit: BoxFit.contain,
            height: size.height * 0.75,
          ),
        ),
        const SizedBox(width: 30),
        // ---------- 오른쪽 : 버튼 영역 ----------
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRuleButtonLarge(
                onTap: () => context.go('/gameRule'), // ✅ GoRouter 이동
              ),
              const SizedBox(height: 20), // ⬇ 간격 축소
              _buildButtonPanel(
                context: context,
                maxWidth: size.width * 0.55,
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
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 26,
        ),
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
          child: Column(
            children: [
              _buildMainButton(
                text: "방 목록",
                onTap: () => context.go('/onlineRoom'), // ✅ GoRouter 이동
              ),
              const SizedBox(height: 12),
              _buildMainButton(
                text: "처음으로",
                onTap: () => context.go('/'), // ✅ 초기화 후 Login 화면
              ),
            ],
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
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE6AD5C), width: 2.2),
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
                fontSize: 20,
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
  Widget _buildRuleButtonLarge({required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.brown.withValues(alpha: 0.2),
        highlightColor: Colors.brown.withValues(alpha: 0.12),
        hoverColor: Colors.brown.withValues(alpha: 0.08),
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
                color: Colors.black.withValues(alpha: 0.28),
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
      ),
    );
  }


}
