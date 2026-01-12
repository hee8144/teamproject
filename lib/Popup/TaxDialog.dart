import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Bankruptcy.dart';

class TaxDialog extends StatefulWidget {
  final int user;
  final int? taxAmount; // 값이 있으면 온라인 모드
  final int? currentMoney; // 온라인 모드일 때 보여줄 현재 잔액

  const TaxDialog({
    super.key,
    required this.user,
    this.taxAmount,
    this.currentMoney,
  });

  @override
  State<TaxDialog> createState() => _TaxDialogState();
}

class _TaxDialogState extends State<TaxDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  int tax = 0;
  int userMoney = 0;
  int remainMoney = 0;
  bool isPaying = false;

  // ✅ [수정] 명시적인 로딩 상태 변수 추가
  bool _isLoading = true;

  // ⏱️ 타이머 변수
  Timer? _timer;
  int _timeLeft = 5;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initData() {
    // 1. [온라인 모드] 데이터가 이미 있으므로 로딩 필요 없음
    if (widget.taxAmount != null) {
      tax = widget.taxAmount!;
      userMoney = widget.currentMoney ?? 0;
      remainMoney = userMoney - tax;

      _isLoading = false; // 로딩 즉시 해제
      if (mounted) {
        setState(() {});
        _startAutoPayTimer();
      }
    }
    // 2. [로컬 모드] DB에서 읽어와야 함
    else {
      _readLocalUser();
    }
  }

  void _startAutoPayTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
      });
      if (_timeLeft <= 0) {
        timer.cancel();
        _payTax();
      }
    });
  }

  Future<void> _payTax() async {
    if (isPaying) return;

    // [온라인 모드]
    if (widget.taxAmount != null) {
      setState(() => isPaying = true);
      if (mounted) Navigator.pop(context, tax);
      return;
    }

    // [로컬 모드]
    if (userMoney < tax) {
      final lackMoney = tax - userMoney;
      if (mounted) {
        Navigator.pop(context, 0);
        Future.microtask(() {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => BankruptDialog(
              lackMoney: lackMoney,
              reason: "tax",
              user: widget.user,
            ),
          );
        });
      }
      return;
    }

    setState(() => isPaying = true);

    try {
      await fs.collection("games").doc("users").update({
        "user${widget.user}.money": FieldValue.increment(-tax),
        "user${widget.user}.totalMoney": FieldValue.increment(-tax),
      });

      if (mounted) Navigator.pop(context, tax);
    } catch (e) {
      print("세금 납부 오류: $e");
    }
  }

  // ✅ [수정] 로컬 데이터 로드 함수 개선
  Future<void> _readLocalUser() async {
    int totalTollPrice = 0;
    try {
      // 로컬 모드는 'games' 컬렉션을 사용한다고 가정
      final userSnap = await fs.collection("games").doc("users").get();
      final boardSnap = await fs.collection("games").doc("board").get();

      if (boardSnap.exists && boardSnap.data() != null) {
        Map<String, dynamic> boardData = boardSnap.data()!;
        boardData.forEach((key, value) {
          if (value is Map && value["owner"] == widget.user.toString()) {
            totalTollPrice += (value["tollPrice"] as int? ?? 0);
          }
        });
      }

      if (userSnap.exists && userSnap.data() != null) {
        final userData = userSnap.data()!;
        if (userData.containsKey("user${widget.user}")) {
          final user = userData["user${widget.user}"];
          userMoney = user["money"] ?? 0;
        }
      }

      // 세금 계산 (자산의 10%)
      tax = (totalTollPrice * 0.1).toInt();
      remainMoney = userMoney - tax;

    } catch (e) {
      print("로컬 데이터 로드 실패: $e");
    } finally {
      // ✅ [핵심] 성공하든 실패하든 로딩 상태 해제 및 타이머 시작
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startAutoPayTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ [수정] 명시적인 로딩 변수 사용
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.brown));
    }

    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5D4037), width: 6),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // 좌측 UI
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
                            const Icon(Icons.account_balance, size: 80, color: Color(0xFF5D4037)),
                            const SizedBox(height: 16),
                            const Text(
                              "보유하신 건물의\n세금을 징수합니다.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723), height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            const Text("(전체 보유 건물 가액의 10%)", style: TextStyle(fontSize: 12, color: Colors.brown)),
                            const SizedBox(height: 20),
                            Text(
                              "$_timeLeft초 후 자동 납부",
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // 우측 UI
                    Expanded(
                      flex: 6,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF8D6E63)),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
                            ),
                            child: Column(
                              children: [
                                _infoRow("현재 보유 금액", userMoney),
                                const Divider(height: 24, color: Color(0xFF8D6E63)),
                                _infoRow("납부할 세금", tax, isHighlight: true),
                                const Divider(height: 24, color: Color(0xFF8D6E63)),
                                _infoRow("납부 후 예상 잔액", remainMoney, isWarning: remainMoney < 0),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: _actionButton(
                              label: "세금 납부 ($_timeLeft)",
                              color: const Color(0xFF5D4037),
                              onTap: isPaying ? null : _payTax,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- 기존 위젯 헬퍼 메서드들 ---
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Text("국 세 청", style: TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _infoRow(String title, int value, {bool isHighlight = false, bool isWarning = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.w500)),
        Text(
          "${formatMoney(value)}원",
          style: TextStyle(
            fontSize: isHighlight ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.red : (isHighlight ? const Color(0xFF5D4037) : Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({required String label, required Color color, required VoidCallback? onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  String formatMoney(int value) {
    return value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }
}