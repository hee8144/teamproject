import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart'; // ✅ 추가
import '../auth/login_dialog.dart';
import '../auth/auth_service.dart'; // ✅ 추가

class Login extends StatefulWidget { // ✅ StatefulWidget으로 변경
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _isAutoLoginReady = false; // ✅ 추가

  @override
  void initState() {
    super.initState();
    // ✅ 자동 로그인 체크만 하고 대기
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final uid = await AuthService.instance.tryAutoLogin();
    if (uid != null && mounted) {
      setState(() {
        _isAutoLoginReady = true; // ✅ 정보가 있으면 플래그만 설정
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginScreen(isAutoLoginReady: _isAutoLoginReady);
  }
}

class LoginScreen extends StatelessWidget {
  final bool isAutoLoginReady;
  const LoginScreen({super.key, this.isAutoLoginReady = false});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. 배경 이미지
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
          // 2. 콘텐츠 레이어
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isLandscape
                      ? _buildLandscapeLayout(context, size)
                      : _buildPortraitLayout(context, size),
                ),
              ),
            ),
          ),

          // 3. 회원가입 유도 버튼 (자동 로그인 준비 상태가 아닐 때만 표시)
          if (!isAutoLoginReady)
            Positioned(
              bottom: 23,
              left: 20,
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const LoginDialog(isSignUpMode: true),
                  );
                },
                icon: const Icon(Icons.person_add, color: Colors.black, size: 20),
                label: const Text(
                  "아직 회원이 아니신가요?",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogo(size.width * 0.7),
        const SizedBox(height: 30),
        _buildLoginPanel(context, size.width * 0.85),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: _buildLogo(size.height * 0.8),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Center(
            child: _buildLoginPanel(context, size.width * 0.45),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(double width) {
    return Image.asset(
      'assets/Logo.png',
      width: width,
      fit: BoxFit.contain,
    );
  }

  Widget _buildLoginPanel(BuildContext context, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7C0A1), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "주사위로 떠나는",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "우리 문화유산 여행",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 20),
          _buildCustomButton(
            text: "로그인",
            textColor: const Color(0xFF5D4037),
            startColor: const Color(0xFFFFE0B2),
            endColor: const Color(0xFFFFCC80),
            borderColor: const Color(0xFFA1887F),
            onTap: () async {
              // if (isAutoLoginReady) {
              //   // ✅ 자동 로그인 정보가 있으면 닉네임 가져와서 인사 후 입장
              //   final String? uid = AuthService.instance.currentUid;
              //   if (uid != null) {
              //     final String nickname = await AuthService.instance.getNickname(uid);
              //     Fluttertoast.showToast(
              //       msg: "🏯 $nickname님, 다시 오신 것을 환영합니다!",
              //       gravity: ToastGravity.TOP,
              //       backgroundColor: const Color(0xFF5D4037),
              //       textColor: Colors.white,
              //     );
              //   }
              //   context.go('/onlinemain');
              // } else {
              //   // ❌ 없으면 기존처럼 다이얼로그 표시
              //   showDialog(
              //     context: context,
              //     builder: (context) => const LoginDialog(),
              //   );
              // }
              context.go('/onlinemain');

            },
          ),
          const SizedBox(height: 10),
          _buildCustomButton(
            text: "비회원으로 시작하기",
            textColor: Colors.white,
            startColor: const Color(0xFFFF7043),
            endColor: const Color(0xFFE64A19),
            borderColor: const Color(0xFFBF360C),
            onTap: () => context.go('/main'), // ✅ GoRouter 이동
          ),
        ],
      ),
    );
  }

  Widget _buildCustomButton({
    required String text,
    required Color textColor,
    required Color startColor,
    required Color endColor,
    required Color borderColor,
    required VoidCallback? onTap, // nullable
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onTap != null ? [startColor, endColor] : [Colors.grey.shade400, Colors.grey.shade400],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap, // null이면 클릭 불가
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: onTap != null ? textColor : Colors.grey.shade700, // 비활성화 시 색 변경
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

}
