import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OriginDialog extends StatefulWidget {
  final int user;

  const OriginDialog({
    super.key,
    required this.user,
  });

  @override
  State<OriginDialog> createState() => _OriginDialogState();
}

class _OriginDialogState extends State<OriginDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.8;
    final dialogHeight = size.height * 0.75;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6), // 한지 배경
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF5D4037), width: 6), // 나무 테두리
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))
          ],
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // [좌측] 출발지 비주얼
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF8D6E63), width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flag_circle_rounded, size: 80, color: Color(0xFF5D4037)),
                            const SizedBox(height: 16),
                            const Text(
                              "출발지 도착",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E2723),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // [우측] 정보 및 버튼
                    Expanded(
                      flex: 6,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF8D6E63)),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))
                              ],
                            ),
                            child: const Column(
                              children: [
                                Text(
                                  "✨ 월급을 지급받았습니다!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD84315)),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "보유한 땅을 업그레이드하고\n다시 한번 전진하세요!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF5D4037)),
                                ),
                              ],
                            ),
                          ),
                          
                          const Spacer(),
                          
                          SizedBox(
                            width: double.infinity,
                            child: _actionButton(
                              "확인", 
                              const Color(0xFF5D4037), 
                              () => Navigator.pop(context)
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
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037), // 짙은 갈색
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Text(
          "출 발 지",
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}