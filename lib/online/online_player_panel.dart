import 'package:flutter/material.dart';

class OnlinePlayerInfoPanel extends StatelessWidget {
  final Alignment alignment;
  final Map<String, dynamic> playerData;
  final Color color;
  final String name; // "user1", "user2" ...
  final String? moneyEffect; // 돈 변화 이펙트 텍스트
  final VoidCallback? onTap;

  const OnlinePlayerInfoPanel({
    super.key,
    required this.alignment,
    required this.playerData,
    required this.color,
    required this.name,
    this.moneyEffect,
    this.onTap,
  });

  // 숫자에 콤마 찍기
  String _formatMoney(dynamic number) {
    if (number == null) return "0";
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    String type = playerData['type'] ?? "N";
    // 게임에 참여하지 않는 유저(N)는 표시 안 함
    if (type == "N") return const SizedBox();

    // 파산 여부 확인 (온라인 코드 기준 'D'가 파산/접속종료)
    bool isBankrupt = (type == "D");

    String displayName = "PLAYER${name.replaceAll('user', '')}";
    if (isBankrupt) displayName = "파산";

    // 위치 판단 (위쪽/왼쪽)
    bool isTop = alignment.y < 0; // P2, P4
    bool isLeft = alignment.x < 0; // P2, P3

    String money = _formatMoney(playerData['money']);
    String totalMoney = _formatMoney(playerData['totalMoney']);

    // 온라인 데이터에 랭크나 더블 통행료 정보가 없으면 기본값 처리
    int rank = playerData['rank'] ?? 0;
    bool isDoubleToll = playerData['isDoubleToll'] ?? false;
    String card = playerData['card'] ?? "";

    // 이펙트 텍스트 위치
    double? effectTopPos = isTop ? 90 : -45;

    // 카드 아이콘 설정
    IconData? cardIcon;
    Color cardColor = Colors.transparent;
    if (card == "shield") {
      cardIcon = Icons.shield;
      cardColor = Colors.blueAccent;
    } else if (card == "escape") {
      cardIcon = Icons.vpn_key;
      cardColor = Colors.orangeAccent;
    }

    // 패널 테두리 모양
    var panelBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(15),
      topRight: const Radius.circular(15),
      bottomLeft: isLeft ? const Radius.circular(5) : const Radius.circular(15),
      bottomRight: isLeft ? const Radius.circular(15) : const Radius.circular(5),
    );

    return Positioned(
      top: isTop ? 20 : null,
      bottom: isTop ? null : 20,
      left: isLeft ? 10 : null,
      right: isLeft ? null : 10,
      child: SizedBox(
        width: 170,
        height: 85,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. 카드 아이콘 (파산 시 숨김)
            if (cardIcon != null && !isBankrupt)
              Positioned(
                top: isTop ? null : -12,
                bottom: isTop ? -22 : null,
                left: isLeft ? 10 : null,
                right: isLeft ? null : 10,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 2))
                    ],
                  ),
                  child: Icon(cardIcon, size: 18, color: Colors.white),
                ),
              ),

            // 2. 메인 정보 박스
            Positioned(
              top: 10, bottom: 0,
              left: isLeft ? 0 : 25,
              right: isLeft ? 25 : 0,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isBankrupt
                          ? [Colors.grey.shade800, Colors.black]
                          : [color.withOpacity(0.9), color.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: panelBorderRadius,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                    border: Border.all(
                        color: isBankrupt ? Colors.grey.withOpacity(0.3) : Colors.white.withOpacity(0.6),
                        width: 1.5
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isLeft && isDoubleToll) const SizedBox(width: 1),
                          if (!isLeft && isDoubleToll) _buildDoubleBadge(),
                          if (!isLeft && !isDoubleToll) const SizedBox(width: 1),

                          Text(
                            displayName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isBankrupt ? Colors.grey.shade600 : Colors.white,
                                fontSize: 12
                            ),
                          ),

                          if (isLeft && isDoubleToll) _buildDoubleBadge(),
                          if (isLeft && isDoubleToll) const SizedBox(width: 1)
                        ],
                      ),
                      const SizedBox(height: 4),
                      _moneyText("현금", money, isLeft),
                      _moneyText("자산", totalMoney, isLeft),
                    ],
                  ),
                ),
              ),
            ),

            // 3. 랭킹 배지
            Positioned(
              top: 0,
              left: isLeft ? 125 : 0,
              child: Container(
                width: 45, height: 45,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isBankrupt ? Colors.grey.shade400 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: isBankrupt ? Colors.grey.shade600 : color, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("RANK", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text("$rank", style: TextStyle(fontSize: 18, color: isBankrupt ? Colors.grey.shade600 : color, fontWeight: FontWeight.w900, height: 1.0)),
                  ],
                ),
              ),
            ),

            // 4. 돈 변화 이펙트 (여기선 텍스트만 렌더링, 실제 값은 외부에서 주입 필요)
            if (moneyEffect != null && !isBankrupt)
              Positioned(
                top: effectTopPos,
                left: 0, right: 0,
                child: Center(
                  child: Stack(
                    children: [
                      Text(
                        moneyEffect!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 4
                            ..color = Colors.black,
                        ),
                      ),
                      Text(
                        moneyEffect!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: moneyEffect!.startsWith("-")
                              ? const Color(0xFFFF5252)
                              : const Color(0xFF69F0AE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. 파산 오버레이
            if (isBankrupt)
              Positioned(
                top: 10, bottom: 0,
                left: isLeft ? 0 : 25,
                right: isLeft ? 25 : 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: panelBorderRadius,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _moneyText(String label, String value, bool isLeftPanel) {
    return Row(
      mainAxisAlignment: isLeftPanel ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isLeftPanel) ...[
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
        if (isLeftPanel) ...[
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
        ],
      ],
    );
  }

  Widget _buildDoubleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: const Text(
        "x2",
        style: TextStyle(
            color: Colors.red,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1.0
        ),
      ),
    );
  }
}