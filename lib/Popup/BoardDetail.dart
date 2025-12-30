import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BoardDetail extends StatefulWidget {
  final int boardNum;
  final Map<String, dynamic>? data;

  const BoardDetail({
    super.key,
    required this.boardNum,
    this.data,
  });

  @override
  State<BoardDetail> createState() => _BoardDetailPopupState();
}

class _BoardDetailPopupState extends State<BoardDetail> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  Map<String, dynamic> _detail = {};
  Map<String, dynamic> _BoardDetail = {};

  int baseToll = 0;
  int takeoverCost=0;
  int level=0;
  int levelMulti = 0;
  bool isLoading = true;
  int multiply=1;
  int isFestival=1;
  int toll =0;
  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _detail = widget.data!;
      isLoading = false;
    }
    PriceDetail();
  }

  Future<void> PriceDetail() async {
    final snap= await fs.collection("games").doc("board").get();
    if (!snap.exists) return;

    final data = snap.data();
    final key = "b${widget.boardNum}";

    if (data != null && data[key] != null) {
      setState(() {
        _BoardDetail= Map<String, dynamic>.from(data[key]);
        baseToll = _BoardDetail["tollPrice"] ?? 0;
        isLoading = false;
        level = _BoardDetail["level"];
        multiply = _BoardDetail["multiply"];
      });

      switch (level) {
        case 1: levelMulti = 2; break;
        case 2: levelMulti = 6; break;
        case 3: levelMulti = 14; break;
        case 4: levelMulti = 30; break;
      }
      if(_BoardDetail["isFestival"]){
        isFestival=2;
      }
      takeoverCost = baseToll *levelMulti;
      toll = baseToll * isFestival * multiply * levelMulti;

    }
    print(baseToll);
    print(isFestival);
    print(multiply);
    print(levelMulti);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900, // 정보가 많으므로 가로 폭을 조금 넓혔습니다.
            maxHeight: size.height * 0.9,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFDF5E6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5D4037), width: 6),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        /// 1. 왼쪽: 이미지 영역
                        Expanded(flex: 3, child: _buildImageSection()),

                        const SizedBox(width: 20),

                        /// 2. 중앙: 건설 가격 정보
                        Expanded(flex: 3, child: _buildConstructionSection()),

                        const SizedBox(width: 20),

                        /// 3. 오른쪽: 인수/통행료 정보
                        Expanded(flex: 3, child: _buildRentSection()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Center(
        child: Text(
          _detail["name"] ?? "상세 정보",
          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 왼쪽 이미지 섹션
  Widget _buildImageSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5D4037), width: 2),
        image: DecorationImage(
          image: NetworkImage(_detail["img"] ?? ""),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 중앙 건설 섹션
  Widget _buildConstructionSection() {
    return _buildInfoCard(
      title: "건설 비용",
      icon: Icons.foundation,
      content: {
        "대지": baseToll ,
        "빌라": baseToll * 2,
        "빌딩": baseToll * 4,
        "호텔": baseToll * 8,
        "랜드마크": baseToll * 16,
      },
    );
  }

  /// 오른쪽 인수/통행료 섹션
  Widget _buildRentSection() {
    return Column(
      children: [
        Expanded(
          child: _buildInfoCard(
            title: "인수 비용",
            icon: Icons.assignment_return,
            content: {"인수 가격": level ==4 ? "인수불가" : takeoverCost},
            color: const Color(0xFFEFEBE9),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _buildInfoCard(
            title: "현재 통행료",
            icon: Icons.payments,
            content: {"통행료": toll},
            color: const Color(0xFFFFF3E0),
          ),
        ),
        const SizedBox(height: 10),
        _buildBottomButton()
      ],
    );
  }

  /// 공통 정보 카드 스타일
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic> content,
    Color color = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4C4A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF5D4037)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
            ],
          ),
          const Divider(),
          ...content.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                Text("${e.value}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5D4037),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text("확인", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}