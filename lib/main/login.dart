import 'package:flutter/material.dart';
import 'mainUI.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'NanumMyeongjo',
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
                      ? _buildLandscapeLayout(context, size) // context 추가 전달
                      : _buildPortraitLayout(context, size), // context 추가 전달
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
        _buildLoginPanel(context, size.width * 0.85), // context 추가
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
            child: _buildLoginPanel(context, size.width * 0.45), // context 추가
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
          const Text("주사위로 떠나는", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          const SizedBox(height: 5),
          const Text("우리 문화유산 여행", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
          const SizedBox(height: 20),
          _buildCustomButton(
            text: "로그인 (추후 제작 예정...)",
            textColor: const Color(0xFF5D4037),
            startColor: const Color(0xFFFFE0B2),
            endColor: const Color(0xFFFFCC80),
            borderColor: const Color(0xFFA1887F),
            onTap: () => print("로그인 버튼 클릭"),
          ),
          const SizedBox(height: 10),
          _buildCustomButton(
            text: "비회원으로 시작하기",
            textColor: Colors.white,
            startColor: const Color(0xFFFF7043),
            endColor: const Color(0xFFE64A19),
            borderColor: const Color(0xFFBF360C),
            onTap: () {
              // Navigator를 사용하여 MainScreen(mainUI.dart)으로 이동
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            },
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
    required VoidCallback onTap, // onTap 파라미터 추가
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap, // 전달받은 함수 호출
          child: Center(
            child: Text(text, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}