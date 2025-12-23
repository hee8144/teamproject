import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 화면 크기 및 방향 정보 가져오기
    final size = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Stack(
        children: [
          // 1. 배경 이미지 (background.png)
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover, // 화면에 꽉 차게 배경 배치
              ),
            ),
          ),

          // 2. 콘텐츠 레이어
          SafeArea(
            child: Center(
              child: SingleChildScrollView( // 가로 모드에서 세로 공간 부족 시 스크롤 허용
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로고 (app_project.png)
                    // 가로 모드일 때는 높이 기준으로 크기를 조절하여 화면을 너무 많이 차지하지 않게 함
                    Image.asset(
                      'assets/app_project.png',
                      height: isLandscape ? size.height * 0.45 : null,
                      width: isLandscape ? null : size.width * 0.6,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 15),

                    // 메인 제어 패널
                    Container(
                      // 가로 모드일 때 너무 넓어지지 않도록 너비 조정
                      width: isLandscape ? size.width * 0.5 : size.width * 0.8,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
                      decoration: BoxDecoration(
                        // 투명도를 살짝 주어 배경과 조화롭게 설정
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // '방 만들기' 버튼
                          Expanded(
                            flex: 4,
                            child: _buildMainButton(
                              text: "방 만들기",
                              onTap: () => print("방 만들기 클릭"),
                            ),
                          ),

                          const SizedBox(width: 15),

                          // '?' (도움말) 버튼
                          _buildCircleButton(
                            text: "?",
                            onTap: () => print("도움말 클릭"),
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

  // 가로로 긴 타원형 버튼 (방 만들기용)
  Widget _buildMainButton({required String text, required VoidCallback onTap}) {
    return Container(
      height: 55, // 가로 모드 높이에 맞춰 소폭 조정
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE6AD5C), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
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
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 동그란 버튼 (? 도움말용)
  Widget _buildCircleButton({required String text, required VoidCallback onTap}) {
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
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
}