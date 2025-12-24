import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConstructionDialog extends StatefulWidget {
  final String buildingId; // 예: "b1", "b2"

  const ConstructionDialog({super.key, required this.buildingId});

  @override
  State<ConstructionDialog> createState() => _ConstructionDialogState();
}

class _ConstructionDialogState extends State<ConstructionDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  // 선택된 건물들 (체크박스 상태)
  List<bool> selectedItems = [false, false, false, false];

  // 각 항목별 가격 (Firebase에서 가져올 값들)
  List<int> costs = [200, 200, 300, 400];
  List<String> itemNames = ["별장", "빌딩", "호텔", "랜드마크"];

  // 내가 직접 넣을 이미지 경로들
  List<String> itemImages = [
    "assets/blue-building1.PNG",
    "assets/blue-building2.PNG",
    "assets/blue-building3.PNG",
    "assets/landmark.png",
  ];

  int totalCost = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Firebase에서 해당 땅의 건설 비용 데이터를 가져오는 로직
    // 예: snapshot.data()["costs"] -> [100, 200, 300, 400]
    setState(() => loading = false);
  }

  void _calculateTotal() {
    int sum = 0;
    for (int i = 0; i < selectedItems.length; i++) {
      if (selectedItems[i]) sum += costs[i];
    }
    setState(() => totalCost = sum);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 450,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6), // 연한 베이지색 배경
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC0A060), width: 4), // 금색 테두리
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- 1. 헤더 (보라색 타이틀바) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFBC58B1), // 이미지의 보라색
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    "건설 팝업",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
                  ),
                  Positioned(
                    right: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.cancel, color: Color(0xFF5D4037), size: 30),
                    ),
                  )
                ],
              ),
            ),

            // --- 2. 건설 항목 리스트 (가로 배치) ---
            Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) => _buildConstructionItem(index)),
              ),
            ),

            // --- 3. 중간 정보 (보유머니 등) ---
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Text("건설 비용 합계: 229만 5000", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
            ),

            // --- 4. 하단 지불 버튼 ---
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              child: InkWell(
                onTap: () {
                  // _updateMoney(totalCost); // 이전 질문의 업데이트 함수 연결
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA726), Color(0xFFFB8C00)], // 주황색 그라데이션
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 4))]
                  ),
                  child: Text(
                    "건설 비용: $totalCost",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 각 항목 (별장, 빌딩 등) 위젯
  Widget _buildConstructionItem(int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedItems[index] = !selectedItems[index];
          _calculateTotal();
        });
      },
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedItems[index] ? Colors.orange : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFD2B48C), // 갈색 헤더
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Text("건설 비용", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(height: 5),
            // --- 여기에 내가 넣고 싶은 건물 이미지 ---
            Image.asset(itemImages[index], height: 50, fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.home, size: 50, color: Colors.green)),
            const SizedBox(height: 5),
            Text("${costs[index]}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}