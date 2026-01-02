import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ 가로모드 고정용
import 'package:go_router/go_router.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp 제거, GoRouter가 최상위에서 관리
    return const LoginScreen();
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
            text: "로그인 (추후 제작 예정...)",
            textColor: const Color(0xFF5D4037),
            startColor: const Color(0xFFFFE0B2),
            endColor: const Color(0xFFFFCC80),
            borderColor: const Color(0xFFA1887F),
            onTap: (){
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
