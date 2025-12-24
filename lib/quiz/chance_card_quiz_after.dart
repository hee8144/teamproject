import 'package:flutter/material.dart';
import 'chance_card.dart';              // 🔹 Firestore 카드 데이터를 담는 모델
import 'chance_card_repository.dart';   // 🔹 Firestore에서 카드 가져오는 로직

// 찬스카드 결과 화면
class ChanceCardQuizAfter extends StatelessWidget {
  // 퀴즈 정답 여부 (정답이면 true)
  final bool quizEffect;

  const ChanceCardQuizAfter({
    super.key,
    required this.quizEffect,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,

      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,

        child: Stack(
          children: [
            Container(
              width: size.width,
              height: size.height,
              // 부루마블 판 위를 어둡게 덮는 역할
              color: Colors.black.withOpacity(0.45),
            ),

            // ===============================
            // 2️⃣ 찬스 카드 본체
            // ===============================
            Positioned(
              // 화면 상단/하단 여백 조절
              top: size.height * 0.02,
              bottom: size.height * 0.05,
              left: 0,
              right: 0,

              child: Center(
                child: AspectRatio(
                  aspectRatio: 2 / 3,

                  child: Container(
                    padding: const EdgeInsets.all(18),

                    // 카드 외형 스타일
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

                    child: Column(
                      children: [
                        // ===============================
                        // 3️⃣ 카드 이미지 영역
                        // ===============================
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black26),
                            ),
                            // 실제 이미지 들어가기 전 더미
                            child: const Center(
                              child: Placeholder(strokeWidth: 1),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ===============================
                        // 4️⃣ 텍스트 영역
                        // ===============================
                        Expanded(
                          // Firestore에서 비동기로 카드 데이터를 가져옴
                          child: FutureBuilder<ChanceCard>(
                            // 🔹 찬스카드 1장 랜덤으로 가져오는 함수
                            future: ChanceCardRepository.fetchRandom(
                              quizCorrect: quizEffect,
                            ),

                            builder: (context, snapshot) {
                              // ---------- 에러 상태 ----------
                              if (snapshot.hasError) {
                                return Text(
                                  'ERROR: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                );
                              }

                              // ---------- 로딩 상태 ----------
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              // ---------- 데이터 수신 완료 ----------
                              final card = snapshot.data!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 퀴즈 정답
                                  if (quizEffect)
                                    const Text(
                                      "이로운 효과 확률상승",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                  if (quizEffect)
                                    const SizedBox(height: 12),

                                  // 카드 제목 (Firestore: title)
                                  Text(
                                    card.title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // 카드 설명 (Firestore: description)
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Text(
                                        card.description,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // ===============================
                                  // 5️⃣ 확인 버튼 (카드 닫기)
                                  // ===============================
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, card.description), // 카드 효과 텍스트를 메인으로 넘김
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(18),
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
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
