import 'package:flutter/material.dart';

void main() {
  runApp(const MarbleApp());
}

class MarbleApp extends StatelessWidget {
  const MarbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MarblePopupPage(),
    );
  }
}

class MarblePopupPage extends StatelessWidget {
  const MarblePopupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ===== 보드 대체 배경 =====
          Container(
            color: const Color(0xFF2F3E34),
          ),

          // ===== 어두운 오버레이 =====
          Container(
            color: Colors.black.withOpacity(0.45),
          ),

          // ===== 팝업 =====
          SafeArea(
            child: Center(
              child: Container(
                width: size.width * 0.65,
                height: size.height * 0.70,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE6C9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFF4A261),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // ===== 왼쪽: 이미지 =====
                    Container(
                      width: size.width * 0.30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: const Center(
                        child: Text(
                          "이미지",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 20),

                    // ===== 오른쪽: 텍스트 + 버튼 =====
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 상단 안내 문구
                          const Text(
                            "이로운 효과 확률상승",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 카드 이름
                          const Text(
                            "카드 이름",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 카드 설명
                          const Text(
                            "카드 설명이 들어가는 영역입니다.\n너무 길지 않게 2~3줄 정도로 표시됩니다.",
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),

                          const Spacer(),

                          // 확인 버튼
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                side: const BorderSide(
                                  color: Colors.black54,
                                ),
                              ),
                              child: const Text(
                                "확인",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
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
}
