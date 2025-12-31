import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ================= 버튼 타입 =================
enum DetailPopupActionType {
  close, // 확인 버튼
  next,  // 다음 화살표 버튼
}

class DetailPopup extends StatefulWidget {
  final int boardNum;
  final VoidCallback? onNext;

  const DetailPopup({
    super.key,
    required this.boardNum,
    this.onNext,
  });

  @override
  State<DetailPopup> createState() => _DetailPopupPopupState();
}

class _DetailPopupPopupState extends State<DetailPopup> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  Map<String, dynamic> detail = {};
  bool isLoading = true;
  List<int> nums = [3, 7, 10, 14, 17, 21, 24, 26];

  Future<void> getDetail() async {
    final snap = await fs.collection("games").doc("quiz").get();
    int boardNum = widget.boardNum;
    if (!snap.exists) return;
    int minusCount = nums.where((n) => n < boardNum).length;

    int quizNum = boardNum - minusCount;

    final data = snap.data();
    final key = "q${quizNum}";

    if (data != null && data[key] != null) {
      setState(() {
        detail = Map<String, dynamic>.from(data[key]);
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getDetail();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: size.height * 0.85,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF5E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF5D4037),
                    width: 6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            /// ================= 왼쪽 : 이미지 =================
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF5D4037),
                                    width: 2,
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      detail["img"] ?? "",
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),

                            /// 구분선
                            Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              color: const Color(0xFFD4C4A8),
                            ),

                            /// ================= 오른쪽 : 설명 =================
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: _buildExplanationContent(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: _buildActionButton(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  /// ================= 상단 헤더 =================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Center(
        child: Text(
          "상세설명",
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// ================= 버튼 분기 로직 =================
  Widget _buildActionButton(BuildContext context) {
    final Map<String, dynamic> resultData = {
      "img": detail["img"],
      "name": detail["name"],
      "times": detail["times"], // 추가 정보가 필요할 경우
    };
    // 1. onNext 콜백이 전달된 경우 -> 화살표 버튼 표시

    if (widget.onNext != null) {
      return IconButton(
        tooltip: "다음",
        icon: const Icon(
          Icons.arrow_circle_right_rounded,
          size: 40, // 화살표 크기를 조금 더 키워 가독성 확보
          color: Color(0xFF5D4037),
        ),
        onPressed:()=> Navigator.pop(context,resultData), // 전달받은 함수 실행
      );
    }

    // 2. onNext가 null인 경우 -> 기본 "확인" 버튼 표시
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => Navigator.pop(context),
      child: const Text(
        "확인",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// ================= 설명 영역 =================
  Widget _buildExplanationContent() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4C4A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: Color(0xFF5D4037),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: detail["name"] ?? "",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                      const TextSpan(
                        text: "  ·  ",
                        style: TextStyle(color: Colors.grey),
                      ),
                      TextSpan(
                        text: "(${detail["times"] ?? ""})",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8D6E63),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFEFEBE9)),
          Text(
            detail["description"] ?? "",
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
