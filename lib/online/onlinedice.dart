import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class onlineDiceApp extends StatefulWidget {
  final Function(int, int) onRoll;
  final int turn;
  final int totalTurn;
  final bool isBot;
  final bool isOnline;
  final bool isMyTurn; // 💡 내 턴인지 확인

  const onlineDiceApp({
    Key? key,
    required this.onRoll,
    required this.turn,
    required this.totalTurn,
    required this.isBot,
    this.isOnline = false,
    this.isMyTurn = false,
  }) : super(key: key);

  @override
  onlineDiceAppState createState() => onlineDiceAppState();
}

class onlineDiceAppState extends State<onlineDiceApp> with TickerProviderStateMixin {
  final double _size = 40.0;
  double _x1 = 0.0, _y1 = 0.0;
  double _x2 = 0.0, _y2 = 0.0;
  int _totalResult = 2;
  bool _isDouble = false; // ✨ 더블 여부 저장
  bool isRolling = false;

  late AnimationController _controller1, _controller2;
  late Animation<double> _animationX1, _animationY1, _animationX2, _animationY2;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _controller2 = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);

    _animationX1 = AlwaysStoppedAnimation(_x1); _animationY1 = AlwaysStoppedAnimation(_y1);
    _animationX2 = AlwaysStoppedAnimation(_x2); _animationY2 = AlwaysStoppedAnimation(_y2);

    _controller1.addListener(() => setState(() { _x1 = _animationX1.value; _y1 = _animationY1.value; }));
    _controller2.addListener(() => setState(() { _x2 = _animationX2.value; _y2 = _animationY2.value; }));

    // 애니메이션이 끝나면 결과값 계산 및 더블 체크
    _controller2.addStatusListener((status) {
      if (status == AnimationStatus.completed) _calculateResult();
    });
  }

  // 📡 서버에서 온 결과값으로 주사위 굴리기
  void rollDiceFromServer(int target1, int target2) {
    if (isRolling) return;
    setState(() {
      isRolling = true;
      _isDouble = false; // 굴리는 동안은 더블 표시 끔
      _totalResult = 0;
    });

    _animationX1 = _createTargetAnim(_controller1, _x1, target1, true);
    _animationY1 = _createTargetAnim(_controller1, _y1, target1, false);
    _animationX2 = _createTargetAnim(_controller2, _x2, target2, true);
    _animationY2 = _createTargetAnim(_controller2, _y2, target2, false);

    _controller1.forward(from: 0.0);
    _controller2.forward(from: 0.0);
  }

  Animation<double> _createTargetAnim(AnimationController c, double current, int targetVal, bool isX) {
    var angles = _getTargetAngle(targetVal);
    double targetBase = isX ? angles['x']! : angles['y']!;
    double rotations = (current / (2 * pi)).floorToDouble();
    double nextBase = rotations * (2 * pi) + targetBase;
    if (nextBase < current) nextBase += (2 * pi);
    // (2 * pi * 3)을 더해서 3바퀴 더 회전하게 연출
    return Tween<double>(begin: current, end: nextBase + (2 * pi * 3)).animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack));
  }

  Map<String, double> _getTargetAngle(int value) {
    switch (value) {
      case 1: return {'x': 0.0, 'y': 0.0};
      case 2: return {'x': -pi / 2, 'y': 0.0};
      case 3: return {'x': 0.0, 'y': -pi / 2};
      case 4: return {'x': 0.0, 'y': pi / 2};
      case 5: return {'x': pi / 2, 'y': 0.0};
      case 6: return {'x': 0.0, 'y': pi};
      default: return {'x': 0.0, 'y': 0.0};
    }
  }

  void _calculateResult() {
    int v1 = _getFaceValue(_x1, _y1);
    int v2 = _getFaceValue(_x2, _y2);

    setState(() {
      _totalResult = v1 + v2;
      _isDouble = (v1 == v2); // ✨ 더블 체크
      isRolling = false;
    });
  }

  int _getFaceValue(double x, double y) {
    int iX = (x / (pi / 2)).round() % 4;
    int iY = (y / (pi / 2)).round() % 4;
    if (iX < 0) iX += 4; if (iY < 0) iY += 4;
    if (iX == 0) { if (iY == 0) return 1; if (iY == 1) return 4; if (iY == 2) return 6; return 3; }
    else if (iX == 1) return 5;
    else if (iX == 2) { if (iY == 0) return 6; if (iY == 1) return 3; if (iY == 2) return 1; return 4; }
    else return 2;
  }

  @override
  Widget build(BuildContext context) {
    // 플레이어 색상 (1번: 빨강, 2번: 파랑...)
    List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.purple];
    int currentTurnIndex = (widget.turn - 1).clamp(0, 3);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75), // 로컬과 동일한 배경색
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✨ 더블 알림 텍스트
            SizedBox(
              height: 20,
              child: _isDouble && !isRolling
                  ? const Text("✨ DOUBLE!! ✨", style: TextStyle(color: Colors.yellowAccent, fontSize: 16, fontWeight: FontWeight.bold))
                  : null,
            ),

            // 🔄 전체 턴 수 표시
            Text("남은 턴 : ${widget.totalTurn}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2)),

            // 👤 누구 턴인지 표시
            Text("Player ${widget.turn}님의 턴", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),

            // 🎲 합계 결과 표시
            Text(
                isRolling ? "Rolling..." : "TOTAL: $_totalResult",
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)
            ),

            const SizedBox(height: 25),

            // 🎲 주사위 큐브 2개
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Cube(x: _x1, y: _y1, size: _size),
                  const SizedBox(width: 25),
                  Cube(x: _x2, y: _y2, size: _size)
                ]
            ),

            const SizedBox(height: 30),

            // 👇 내 턴일 때만 버튼 표시
            if (widget.isMyTurn && !isRolling)
              ElevatedButton(
                onPressed: () => widget.onRoll(0, 0), // 서버로 roll 요청
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  backgroundColor: colors[currentTurnIndex], // 현재 턴 플레이어 색상
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                ),
                child: const Text("ROLL DICE 🎲", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            else
            // 버튼이 없을 때 레이아웃 꺼짐 방지용 빈 공간
              const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() { _controller1.dispose(); _controller2.dispose(); super.dispose(); }
}

// 📦 Cube 및 DiceDotsPainter 클래스는 로컬과 완전히 동일하게 사용
class Cube extends StatelessWidget {
  const Cube({super.key, required this.x, required this.y, required this.size});
  final double x, y, size;
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> faces = [
      {'v': 1, 'x': x, 'y': y, 'z': 0.0}, {'v': 6, 'x': x, 'y': y + pi, 'z': 0.0},
      {'v': 2, 'x': x + pi / 2, 'y': 0.0, 'z': -y}, {'v': 5, 'x': x - pi / 2, 'y': 0.0, 'z': y},
      {'v': 3, 'x': x, 'y': y + pi / 2, 'z': 0.0}, {'v': 4, 'x': x, 'y': y - pi / 2, 'z': 0.0},
    ];
    faces.sort((a, b) => _calcZ(a['x'], a['y'], a['z']).compareTo(_calcZ(b['x'], b['y'], b['z'])));
    return Stack(children: faces.map((f) => _side(f['x'], f['y'], f['z'], f['v'])).toList());
  }
  double _calcZ(double rx, double ry, double rz) {
    final m = Matrix4.identity()..rotateX(rx)..rotateY(ry)..rotateZ(rz)..translate(0.0, 0.0, size / 2);
    final v = Vector3(0, 0, 0); m.perspectiveTransform(v); return v.z;
  }
  Widget _side(double rx, double ry, double rz, int val) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateX(rx)..rotateY(ry)..rotateZ(rz)..translate(0.0, 0.0, size / 2),
      child: Center(child: Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white, border: Border.all(width: 1.0, color: Colors.grey[300]!), borderRadius: BorderRadius.circular(size * 0.15)), child: CustomPaint(painter: DiceDotsPainter(val)))),
    );
  }
}

class DiceDotsPainter extends CustomPainter {
  final int value;
  DiceDotsPainter(this.value);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final r = size.width * 0.1; final w = size.width, h = size.height;
    void draw(double x, double y) => canvas.drawCircle(Offset(x, y), r, paint);
    if (value % 2 != 0) draw(w / 2, h / 2);
    if (value >= 2) { draw(w * 0.25, h * 0.25); draw(w * 0.75, h * 0.75); }
    if (value >= 4) { draw(w * 0.75, h * 0.25); draw(w * 0.25, h * 0.75); }
    if (value == 6) { draw(w * 0.25, h * 0.5); draw(w * 0.75, h * 0.5); }
  }
  @override bool shouldRepaint(CustomPainter old) => false;
}