import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DetailPopup extends StatefulWidget {
  final int boardNum;

  const DetailPopup({
    super.key,
    required this.boardNum,
  });

  @override
  State<DetailPopup> createState() => _DetailPopupPopupState();
}

class _DetailPopupPopupState extends State<DetailPopup> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  Map<String, dynamic> detail = {};
  bool isLoading = true;

  Future<void> getDetail() async {
    final snap = await fs.collection("games").doc("quiz").get();
    if (!snap.exists) return;

    final data = snap.data();
    final key = "q${widget.boardNum}";

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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        children: [
          // 배경 오버레이
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),

          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 800,
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
                    // 상단 타이틀
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF5D4037),
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(8)),
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
                    ),

                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // ======================
                            // 왼쪽 : 이미지 영역
                            // ======================
                            Expanded(
                              flex: 4,
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 3 / 4,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                          const Color(0xFF5D4037),
                                          width: 2,
                                        ),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            detail["image"] ??
                                                "https://via.placeholder.com/300",
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    detail["title"] ?? "",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    detail["summary"] ?? "",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            // 구분선
                            Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              color: const Color(0xFFD4C4A8),
                            ),

                            // ======================
                            // 오른쪽 : 설명 영역
                            // ======================
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child:
                                      _buildExplanationContent(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        const Color(0xFF5D4037),
                                        foregroundColor: Colors.white,
                                        padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text(
                                        "확인",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                            FontWeight.bold),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          const Row(
            children: [
              Icon(Icons.menu_book_rounded,
                  size: 18, color: Color(0xFF5D4037)),
              SizedBox(width: 8),
              Text(
                "문화재 정보",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
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
