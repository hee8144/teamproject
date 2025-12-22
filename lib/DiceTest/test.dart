import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

void main() => runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(backgroundColor: Color(0xFF2C2F33), body: CreateApp())
));

class CreateApp extends StatefulWidget {
  const CreateApp({super.key});
  @override
  CreateAppState createState() => CreateAppState();
}

class CreateAppState extends State<CreateApp> with TickerProviderStateMixin {
  final double _size = 110.0;
  double _x1 = 0.0, _y1 = 0.0;
  double _x2 = 0.0, _y2 = 0.0;
  int _totalResult = 2;
  bool _isDouble = false;
  bool _isRolling = false; // 주사위가 돌아가는 중인지 확인

  late AnimationController _controller1, _controller2;
  late Animation<double> _animationX1, _animationY1, _animationX2, _animationY2;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _controller2 = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);

    _animationX1 = AlwaysStoppedAnimation(_x1); _animationY1 = AlwaysStoppedAnimation(_y1);
    _animationX2 = AlwaysStoppedAnimation(_x2); _animationY2 = AlwaysStoppedAnimation(_y2);

    // 리스너 등록: 값이 변할 때마다 화면 갱신
    _controller1.addListener(() => setState(() { _x1 = _animationX1.value; _y1 = _animationY1.value; }));
    _controller2.addListener(() => setState(() { _x2 = _animationX2.value; _y2 = _animationY2.value; }));

    // 두 주사위가 모두 멈추면 결과 계산
    _controller2.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _calculateResult();
      }
    });
  }

  // 각도에서 현재 정면 숫자를 정확히 추출하는 로직
  int _getFaceValue(double x, double y) {
    // 각도를 90도 단위의 정수로 변환 (0~3 범위로 정규화)
    int iX = (x / (pi / 2)).round() % 4;
    int iY = (y / (pi / 2)).round() % 4;
    if (iX < 0) iX += 4;
    if (iY < 0) iY += 4;

    // 주사위 전개도 기준 판별
    if (iX == 0) {
      if (iY == 0) return 1; if (iY == 1) return 4; if (iY == 2) return 6; return 3;
    } else if (iX == 1) return 5;
    else if (iX == 2) {
      if (iY == 0) return 6; if (iY == 1) return 3; if (iY == 2) return 1; return 4;
    } else { // iX == 3
      return 2;
    }
  }

  void _calculateResult() {
    int val1 = _getFaceValue(_x1, _y1);
    int val2 = _getFaceValue(_x2, _y2);
    setState(() {
      _totalResult = val1 + val2;
      _isDouble = (val1 == val2);
      _isRolling = false;
    });
  }

  void runAllDice() {
    if (_controller1.isAnimating || _controller2.isAnimating) return;

    setState(() {
      _isDouble = false;
      _isRolling = true;
    });

    _animationX1 = _createDiceAnim(_controller1, _x1);
    _animationY1 = _createDiceAnim(_controller1, _y1);
    _animationX2 = _createDiceAnim(_controller2, _x2);
    _animationY2 = _createDiceAnim(_controller2, _y2);

    _controller1.forward(from: 0.0);
    _controller2.forward(from: 0.0);
  }

  Animation<double> _createDiceAnim(AnimationController c, double cur) {
    // 무작위성을 위해 최소 4바퀴 이상 돌게 함
    double end = ((cur / (pi / 2)).round() + (Random().nextInt(4) + 6)) * (pi / 2);
    return Tween<double>(begin: cur, end: end).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // "더블!!" 텍스트 영역 (공간 유지)
          SizedBox(
            height: 40,
            child: _isDouble && !_isRolling
                ? const Text("더블!! ✨", style: TextStyle(color: Colors.yellowAccent, fontSize: 32, fontWeight: FontWeight.bold))
                : null,
          ),
          // 점수 표시 영역
          Text(
              _isRolling ? "굴러가는 중..." : "TOTAL: $_totalResult",
              style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDice(1, _x1, _y1),
              _buildDice(2, _x2, _y2),
            ],
          ),
          const SizedBox(height: 80),
          ElevatedButton(
            onPressed: runAllDice,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              backgroundColor: Colors.indigoAccent,
              shape: const StadiumBorder(),
            ),
            child: const Text("ROLL DICE 🎲", style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDice(int id, double x, double y) {
    return GestureDetector(
      onPanUpdate: (u) => setState(() {
        _isDouble = false;
        if (id == 1) { _x1 -= u.delta.dy / 100; _y1 -= u.delta.dx / 100; }
        else { _x2 -= u.delta.dy / 100; _y2 -= u.delta.dx / 100; }
      }),
      child: Cube(x: x, y: y, size: _size),
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
      {'v': 1, 'x': x, 'y': y, 'z': 0.0},
      {'v': 6, 'x': x, 'y': y + pi, 'z': 0.0},
      {'v': 2, 'x': x + pi / 2, 'y': 0.0, 'z': -y},
      {'v': 5, 'x': x - pi / 2, 'y': 0.0, 'z': y},
      {'v': 3, 'x': x, 'y': y + pi / 2, 'z': 0.0},
      {'v': 4, 'x': x, 'y': y - pi / 2, 'z': 0.0},
    ];
    // Z-Buffer: 멀리 있는 면부터 그리기
    faces.sort((a, b) => _calcZ(a['x'], a['y'], a['z']).compareTo(_calcZ(b['x'], b['y'], b['z'])));
    return Stack(children: faces.map((f) => _side(f['x'], f['y'], f['z'], f['v'])).toList());
  }

  double _calcZ(double rx, double ry, double rz) {
    final m = Matrix4.identity()..rotateX(rx)..rotateY(ry)..rotateZ(rz)..translate(0.0, 0.0, size / 2);
    final v = Vector3(0, 0, 0); m.perspectiveTransform(v); return v.z;
  }

  Widget _side(double rx, double ry, double rz, int val) {
    double shading = (cos(ry).abs() * 0.15) + (cos(rx).abs() * 0.15);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateX(rx)..rotateY(ry)..rotateZ(rz)..translate(0.0, 0.0, size / 2),
      child: Center(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(color: Colors.white, border: Border.all(width: 2), borderRadius: BorderRadius.circular(15)),
          foregroundDecoration: BoxDecoration(color: Colors.black.withOpacity(shading.clamp(0.0, 0.4))),
          child: CustomPaint(painter: DiceDotsPainter(val)),
        ),
      ),
    );
  }
}

class DiceDotsPainter extends CustomPainter {
  final int value;
  DiceDotsPainter(this.value);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final r = size.width * 0.09;
    final w = size.width, h = size.height;
    void draw(double x, double y) => canvas.drawCircle(Offset(x, y), r, paint);
    if (value % 2 != 0) draw(w / 2, h / 2);
    if (value >= 2) { draw(w * 0.25, h * 0.25); draw(w * 0.75, h * 0.75); }
    if (value >= 4) { draw(w * 0.75, h * 0.25); draw(w * 0.25, h * 0.75); }
    if (value == 6) { draw(w * 0.25, h * 0.5); draw(w * 0.75, h * 0.5); }
  }
  @override bool shouldRepaint(CustomPainter old) => false;
}