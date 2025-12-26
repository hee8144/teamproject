import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'gameMain.dart';


// 기존 CreateApp 클래스를 아래 코드로 교체하세요.

// 이 코드를 기존 CreateApp 대신 사용하세요.

class DiceApp extends StatefulWidget {
  final Function(int, int) onRoll;

  const DiceApp({super.key, required this.onRoll});
  @override
  DiceAppState createState() => DiceAppState();
}

class DiceAppState extends State<DiceApp> with TickerProviderStateMixin {
  final double _size = 40.0; // 주사위 크기
  int turn = 1;

  double _x1 = 0.0, _y1 = 0.0;
  double _x2 = 0.0, _y2 = 0.0;
  int _totalResult = 2;
  bool _isDouble = false;
  bool _isRolling = false;

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

    _controller2.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _calculateResult();
      }
    });
  }

  int _getFaceValue(double x, double y) {
    int iX = (x / (pi / 2)).round() % 4;
    int iY = (y / (pi / 2)).round() % 4;
    if (iX < 0) iX += 4;
    if (iY < 0) iY += 4;

    if (iX == 0) {
      if (iY == 0) return 1; if (iY == 1) return 4; if (iY == 2) return 6; return 3;
    } else if (iX == 1) return 5;
    else if (iX == 2) {
      if (iY == 0) return 6; if (iY == 1) return 3; if (iY == 2) return 1; return 4;
    } else {
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

      widget.onRoll(_totalResult, turn);

      if(!_isDouble && turn != 4){
        turn++;
      } else if(!_isDouble && turn == 4){
        turn = 1;
      } else {
        turn = turn;
      }


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
    double end = ((cur / (pi / 2)).round() + (Random().nextInt(4) + 6)) * (pi / 2);
    return Tween<double>(begin: cur, end: end).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut));
  }

  @override
  Widget build(BuildContext context) {
    List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        // [수정] 모달창 느낌을 위한 배경 디자인 추가
        width: 260, // 모달의 고정 너비 (FittedBox가 알아서 축소함)
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75), // 반투명 검은색 배경
          borderRadius: BorderRadius.circular(20), // 둥근 모서리
          border: Border.all(color: Colors.white24, width: 1.5), // 연한 테두리
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 차지
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // "더블!!" 텍스트 영역
            SizedBox(
              height: 20,
              child: _isDouble && !_isRolling
                  ? const Text("✨ DOUBLE!! ✨", style: TextStyle(color: Colors.yellowAccent, fontSize: 16, fontWeight: FontWeight.bold))
                  : null,
            ),
            // 점수 표시 영역
            Text(
              "user$turn님의 턴",
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)
            ),
            Text(
                _isRolling ? "Rolling..." : "TOTAL: $_totalResult",
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDice(1, _x1, _y1),
                const SizedBox(width: 25),
                _buildDice(2, _x2, _y2),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: runAllDice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                backgroundColor: colors[turn - 1], // 버튼 색상을 눈에 띄게 변경
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 5,
              ),
              child: const Text("ROLL DICE 🎲", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
    faces.sort((a, b) => _calcZ(a['x'], a['y'], a['z']).compareTo(_calcZ(b['x'], b['y'], b['z'])));
    return Stack(children: faces.map((f) => _side(f['x'], f['y'], f['z'], f['v'])).toList());
  }

  double _calcZ(double rx, double ry, double rz) {
    final m = Matrix4.identity()..rotateX(rx)..rotateY(ry)..rotateZ(rz)..translate(0.0, 0.0, size / 2);
    final v = Vector3(0, 0, 0); m.perspectiveTransform(v); return v.z;
  }

  Widget _side(double rx, double ry, double rz, int val) {
    // [수정] 그림자 계산 로직과 foregroundDecoration을 완전히 삭제했습니다.
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateX(rx)..rotateY(ry)..rotateZ(rz)..translate(0.0, 0.0, size / 2),
      child: Center(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            // 테두리를 얇게 유지
            border: Border.all(width: 1.0, color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(size * 0.15),
          ),
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
    final paint = Paint()..color = Colors.black; // 점 색상 (완전 검정)
    final r = size.width * 0.1;
    final w = size.width, h = size.height;
    void draw(double x, double y) => canvas.drawCircle(Offset(x, y), r, paint);
    if (value % 2 != 0) draw(w / 2, h / 2);
    if (value >= 2) { draw(w * 0.25, h * 0.25); draw(w * 0.75, h * 0.75); }
    if (value >= 4) { draw(w * 0.75, h * 0.25); draw(w * 0.25, h * 0.75); }
    if (value == 6) { draw(w * 0.25, h * 0.5); draw(w * 0.75, h * 0.5); }
  }
  @override bool shouldRepaint(CustomPainter old) => false;
}