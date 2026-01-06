import 'dart:async'; // 타이머를 위해 추가
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Bankruptcy.dart';

class TaxDialog extends StatefulWidget {
  final int user;

  const TaxDialog({
    super.key,
    required this.user,
  });

  @override
  State<TaxDialog> createState() => _TaxDialogState();
}

class _TaxDialogState extends State<TaxDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  int totalTollPrice = 0;
  int tax = 0;
  int userMoney = 0;
  int remainMoney = 0;
  bool isPaying = false;

  // ⏱️ 타이머 변수
  Timer? _timer;
  int _timeLeft = 5;

  Map<String, dynamic> boardData = {};

  @override
  void initState() {
    super.initState();
    // 데이터 로딩 후 타이머 시작
    _readUser().then((_) {
      if (mounted) _startAutoPayTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 위젯 종료 시 타이머 해제
    super.dispose();
  }

  /// 5초 카운트다운 및 자동 납부
  void _startAutoPayTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _timeLeft--;
      });

      if (_timeLeft <= 0) {
        timer.cancel();
        _payTax(); // 시간 종료 시 자동 납부 실행
      }
    });
  }

  /// 납부 로직 (버튼 & 자동 공용)
  Future<void> _payTax() async {
    if (isPaying) return; // 중복 실행 방지

    // 잔액 부족 시 파산 다이얼로그로 이동
    if (userMoney < tax) {
      final lackMoney = tax - userMoney;
      if (mounted) {
        Navigator.pop(context, 0); // 못 냈으므로 0 리턴 (혹은 null)
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

    // DB 업데이트
    await fs.collection("games").doc("users").update({
      "user${widget.user}.money": FieldValue.increment(-tax),
      "user${widget.user}.totalMoney": FieldValue.increment(-tax),
    });

    if (mounted) {
      // 💰 [핵심] 납부한 세금 금액을 리턴하며 닫기
      Navigator.pop(context, tax);
    }
  }

  Future<void> _readUser() async {
    totalTollPrice = 0;
    try {
      final userSnap = await fs.collection("games").doc("users").get();
      final boardSnap = await fs.collection("games").doc("board").get();

      if (boardSnap.exists) {
        boardData = boardSnap.data()!;
        boardData.forEach((key, value) {
          if (value is Map && value["owner"] == widget.user) {
            totalTollPrice += (value["tollPrice"] as int? ?? 0);
          }
        });
      }

      if (userSnap.exists) {
        final user = userSnap.data()!["user${widget.user}"];
        userMoney = user["money"] ?? 0;
        tax = (totalTollPrice * 0.1).toInt();
        remainMoney = userMoney - tax;
      }

      // 데이터 로드 후 화면 갱신
      if (mounted) setState(() {});

    } catch (e) {
      print("User load error: $e");
    }
  }

  String formatMoney(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    // _readUser는 initState에서 호출하므로 FutureBuilder 제거 가능하지만
    // 기존 구조 유지를 위해 데이터가 로드되었는지(tax > 0 등) 체크하거나
    // 로딩 상태 변수를 두는 것이 좋습니다. 여기선 간단히 userMoney로 체크합니다.
    if (userMoney == 0 && tax == 0 && totalTollPrice == 0) {
      // 데이터 로딩 중
      return const Center(child: CircularProgressIndicator(color: Colors.brown));
    }

    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.85;
    final dialogHeight = size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
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
                    // 좌측
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
                            // ⏳ 남은 시간 표시
                            Text(
                              "$_timeLeft초 후 자동 납부",
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // 우측
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
                          Row(
                            children: [
                              Expanded(
                                child: _actionButton(
                                  label: "세금 납부 ($_timeLeft)", // 버튼에도 시간 표시
                                  color: const Color(0xFF5D4037),
                                  onTap: isPaying ? null : _payTax, // 공통 함수 호출
                                ),
                              ),
                              const SizedBox(width: 12)
                            ],
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

  // (이하 _header, _infoRow, _actionButton 위젯 코드는 기존과 동일하므로 생략하거나 그대로 두시면 됩니다)
  Widget _header() { /* ... 기존 코드 ... */ return Container( /* ... */ child: const Center(child: Text("국 세 청", style: TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.bold)))); }
  Widget _infoRow(String title, int value, {bool isHighlight = false, bool isWarning = false}) { /* ... 기존 코드 ... */ return Row(children: [Text(title), Text("$value")]); }
  Widget _actionButton({required String label, required Color color, required VoidCallback? onTap, bool isOutline = false}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}