import 'package:flutter/material.dart';

class GameBoardTile extends StatelessWidget {
  final int index;
  final double size;
  final Map<String, dynamic>? tileData; // boardList["b$index"] 데이터
  final bool shouldGlow; // 반짝임 여부
  final Animation<double> glowAnimation; // 반짝임 애니메이션
  final int itsFestival; // 축제 개최지 인덱스
  final VoidCallback onTap; // 탭 했을 때 실행할 함수 (메인에서 전달받음)

  const GameBoardTile({
    super.key,
    required this.index,
    required this.size,
    required this.tileData,
    required this.shouldGlow,
    required this.glowAnimation,
    required this.itsFestival,
    required this.onTap,
  });

  // 내부용 숫자 포맷 함수
  String _formatMoney(dynamic number) {
    if (number == null) return "0";
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    // 1. 타일 종류에 따른 색상 및 아이콘 결정
    Color barColor = Colors.grey;
    IconData? icon;
    String label = "";
    bool isSpecial = false;

    if (index == 0) { label = "출발"; icon = Icons.flag_circle; barColor = Colors.white; isSpecial = true; }
    else if (index == 7) { label = "무인도"; icon = Icons.lock_clock; isSpecial = true; }
    else if (index == 14) { label = "축제"; icon = Icons.celebration; isSpecial = true; }
    else if (index == 21) { label = "여행"; icon = Icons.flight_takeoff; isSpecial = true; }
    else if (index == 26) { label = "국세청"; icon = Icons.account_balance; isSpecial = true; }
    else if ([3, 10, 17, 24].contains(index)) { label = "찬스"; icon = Icons.question_mark_rounded; barColor = Colors.orange; isSpecial = true; }

    else if (index < 3) barColor = const Color(0xFFCFFFE5);
    else if (index < 7) barColor = const Color(0xFF66BB6A);
    else if (index < 10) barColor = const Color(0xFF42A5F5);
    else if (index < 14) barColor = const Color(0xFFAB47BC);
    else if (index < 17) barColor = const Color(0xFFFFEB00);
    else if (index < 21) barColor = const Color(0xFF808080);
    else if (index < 24) barColor = const Color(0xFFFF69B4);
    else barColor = const Color(0xFFEF5350);

    String tileName = tileData?["name"] ?? "";
    int tollPrice = tileData?["tollPrice"] ?? 0;
    int owner = int.tryParse(tileData?["owner"].toString() ?? "0") ?? 0;
    int level = tileData?["level"] ?? 0;

    // 2. 실제 타일 렌더링
    return GestureDetector(
      onTap: onTap, // 메인에서 전달받은 로직 실행
      child: Container(
        width: size, height: size, padding: const EdgeInsets.all(1.5),
        child: AnimatedBuilder(
          animation: glowAnimation,
          builder: (context, child) {
            double glowValue = glowAnimation.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(6.0),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3, offset: const Offset(1, 2))],
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: isSpecial
                      ? _buildSpecialContent(label, icon!, index == 0)
                      : _buildLandContent(barColor, tileName, tollPrice, owner, level),
                ),
                if (shouldGlow)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.8), width: 2.0 + (glowValue * 2.0)),
                        boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.6 * glowValue), blurRadius: 5 + (glowValue * 10), spreadRadius: 2)],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 내부 UI: 일반 땅 내용물
  Widget _buildLandContent(Color color, String name, int price, int owner, int level) {
    String displayName = name.replaceAll(" ", "\n");
    bool isFestivalLocation = itsFestival == index;
    double multiply = (tileData?["multiply"] as num? ?? 0).toDouble();
    if (isFestivalLocation && multiply == 1) multiply *= 2;

    int levelValue = 1;
    if (level == 0) levelValue = 0;
    else if (level == 1) levelValue = 2;
    else if (level == 2) levelValue = 6;
    else if (level == 3) levelValue = 14;
    else if (level == 4) levelValue = 30;

    int finalToll = (price * multiply * levelValue).round();
    final List<Color> ownerColors = [Colors.transparent, Colors.red, Colors.blue, Colors.green, Colors.purple];
    Color badgeColor = (owner >= 1 && owner <= 4) ? ownerColors[owner] : Colors.transparent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6.0),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 3.0),
                  decoration: BoxDecoration(color: color),
                  child: (multiply != 1)
                      ? Text("X${multiply == multiply.toInt() ? multiply.toInt() : multiply}",
                      style: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 6, fontWeight: FontWeight.bold))
                      : null,
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(opacity: isFestivalLocation ? 0.5 : 0, child: const Icon(Icons.celebration, size: 30, color: Colors.purple)),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(displayName, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, height: 1, color: Colors.black), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (price > 0)
                            Text(_formatMoney(finalToll), style: TextStyle(fontSize: 6, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (level > 0)
            Positioned(
              top: 0, right: 0,
              child: ClipPath(
                clipper: _TopRightTriangleClipper(),
                child: Container(
                  width: 28, height: 28, color: badgeColor,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(top: 3, right: 5),
                  child: level != 4 ? Text("$level", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))
                      : Icon(Icons.star, size: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 내부 UI: 특수 칸 내용물
  Widget _buildSpecialContent(String label, IconData icon, bool isStart) {
    return Container(
      decoration: BoxDecoration(color: isStart ? Colors.white : Colors.grey[100], borderRadius: BorderRadius.circular(6.0)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20, color: Colors.black87), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)]),
    );
  }
}

class _TopRightTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) { final path = Path()..moveTo(size.width, 0)..lineTo(0, 0)..lineTo(size.width, size.height)..close(); return path; }
  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}