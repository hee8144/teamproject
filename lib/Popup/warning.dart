import 'dart:async';

import 'package:flutter/material.dart';

class WarningDialog extends StatefulWidget {
  final List<int> players;
  final String type; // "triple" | "line"

  const WarningDialog({
    super.key,
    required this.players,
    required this.type,
  });

  static final Set<String> _shownWarnings = {};

  static bool canShow(List<int> players, String type) {
    final key = _makeKey(players, type);
    if (_shownWarnings.contains(key)) return false;

    _shownWarnings.add(key);
    return true;
  }

  static String _makeKey(List<int> players, String type) {
    final sorted = [...players]..sort();
    return "$type-${sorted.join("_")}";
  }

  @override
  State<WarningDialog> createState() => _WarningDialogState();
}

class _WarningDialogState extends State<WarningDialog> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final playerText = widget.players.join(", ");
    final typeText = widget.type == "triple" ? "트리플 독점" : "라인 독점";

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: size.width * 0.35,
        height: size.height * 0.65,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F6F1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF8D6E63), width: 2),
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              height: 64,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF3E4A59),
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
              ),
              alignment: Alignment.center,
              child: const Text(
                "⚠️ 독점 경고!",
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFFFE082),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // 본문
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "플레이어 $playerText\n\n"
                        "$typeText 직전 상태입니다!\n"
                        "다음 턴에 승리할 수 있습니다.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
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
