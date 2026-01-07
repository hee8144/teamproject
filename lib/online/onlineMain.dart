import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teamproject/main/login.dart';
import 'package:teamproject/main/game_rule.dart';
import 'package:teamproject/main/game_waiting_room.dart';
import '../auth/auth_service.dart';
import '../widgets/loading_screen.dart';

class onlineMainScreen extends StatefulWidget {
  const onlineMainScreen({super.key});

  @override
  State<onlineMainScreen> createState() => _onlineMainScreenState();
}

class _onlineMainScreenState extends State<onlineMainScreen> {
  String nickname = "불러오는 중...";
  int points = 0;
  String tier = "초보 여행자";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final String? uid = AuthService.instance.currentUid;
    if (uid != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('members').doc(uid).get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final int userPoints = data['point'] ?? 0;
          setState(() {
            nickname = data['nickname'] ?? "여행자";
            points = userPoints;
            tier = AuthService.getTierName(userPoints); // 포인트로 티어 자동 계산
            isLoading = false;
          });
        } else {
          // 문서가 없는 경우 (만약의 상황 대비)
          setState(() {
            nickname = "정보 없음";
            isLoading = false;
          });
        }
      } catch (e) {
        print("유저 정보 로드 실패: $e");
        setState(() => isLoading = false);
      }
    } else {
      // UID 자체가 없는 경우
      setState(() {
        nickname = "게스트";
        isLoading = false;
      });
    }
  }

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

          // 프로필 카드 위치
          Positioned(
            left: 5,
            child: SafeArea(
              child: _buildProfileCard(),
            ),
          ),
        ],
      ),
    );
  }


  // 로그인 사용자 프로필 카드
  Widget _buildProfileCard() {
    final Color tierColor = AuthService.getTierColor(points); // 티어 색상 가져오기

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7C0A1), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFFDF5E6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF5D4037), size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nickname,
                style: const TextStyle(
                  color: Color(0xFFFDF5E6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.stars, color: tierColor, size: 12), // 아이콘 색상 적용
                  const SizedBox(width: 4),
                  Text(
                    "$tier ($points P)",
                    style: TextStyle(
                      color: tierColor.withOpacity(0.9), // 텍스트 색상 적용
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
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
                onTap: () => context.go('/onlineRoom', extra: nickname), // ✅ GoRouter 이동
              ),
              const SizedBox(height: 12),
              _buildMainButton(
                text: "로그아웃",
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const LoadingScreen(
                      isOverlay: true,
                      message: "로그아웃 중입니다...",
                      type: LoadingType.inkBrush,
                    ),
                  );

                  await AuthService().signOut();

                  if (context.mounted) {
                    context.go('/');
                  }
                },
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
