import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class onlineDiceApp extends StatefulWidget {
  final Function(int, int) onRoll;
  final int turn;
  final int totalTurn;
  final bool isBot;
  final bool isOnline;
  final bool isMyTurn;

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
    _controller2.addStatusListener((status) { if (status == AnimationStatus.completed) _calculateResult(); });
  }

  void rollDiceFromServer(int target1, int target2) {
    if (isRolling) return;
    setState(() {
      isRolling = true;
      _totalResult = 0; // 초기화
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
    setState(() {
      _totalResult = _getFaceValue(_x1, _y1) + _getFaceValue(_x2, _y2);
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
    return Container(
      width: 260, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Player ${widget.turn}님의 턴", style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 10),
          Text(isRolling ? "굴러가는 중..." : "합계: $_totalResult", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Cube(x: _x1, y: _y1, size: _size), const SizedBox(width: 30), Cube(x: _x2, y: _y2, size: _size)]),
          const SizedBox(height: 20),
          if (widget.isMyTurn && !isRolling) ElevatedButton(onPressed: () => widget.onRoll(0, 0), child: const Text("주사위 던지기"))
        ],
      ),
    );
  }

  @override
  void dispose() { _controller1.dispose(); _controller2.dispose(); super.dispose(); }
}

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