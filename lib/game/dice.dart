import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

final GlobalKey<DiceAppState> diceAppKey = GlobalKey<DiceAppState>();

class DiceApp extends StatefulWidget {
  final Function(int, int) onRoll;
  final int turn;
  final int totalTurn;
  final bool isBot;
  final int? targetSum; // 💡 [발표용] 치트 값

  const DiceApp({
    Key? key,
    required this.onRoll,
    required this.turn,
    required this.totalTurn,
    required this.isBot,
    this.targetSum, // 💡 [발표용]
  }) : super(key: key);

  @override
  DiceAppState createState() => DiceAppState();
}

class DiceAppState extends State<DiceApp> with TickerProviderStateMixin {
  // ... (변수 및 initState, 함수들은 기존과 동일) ...
  final double _size = 40.0;

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

  void rollDiceForBot(int target1, int target2) {
    if (_isRolling) return;
    setState(() {
      _isDouble = false;
      _isRolling = true;
    });
    _animationX1 = _createTargetAnim(_controller1, _x1, target1, true);
    _animationY1 = _createTargetAnim(_controller1, _y1, target1, false);
    _animationX2 = _createTargetAnim(_controller2, _x2, target2, true);
    _animationY2 = _createTargetAnim(_controller2, _y2, target2, false);
    _controller1.forward(from: 0.0);
    _controller2.forward(from: 0.0);
  }

  Map<String, double> _getTargetAngle(int value) {
    switch (value) {
      case 1: return {'x': 0, 'y': 0};
      case 2: return {'x': -pi / 2, 'y': 0};
      case 3: return {'x': 0, 'y': -pi / 2};
      case 4: return {'x': 0, 'y': pi / 2};
      case 5: return {'x': pi / 2, 'y': 0};
      case 6: return {'x': 0, 'y': pi};
      default: return {'x': 0, 'y': 0};
    }
  }

  Animation<double> _createTargetAnim(AnimationController c, double current, int targetVal, bool isX) {
    var angles = _getTargetAngle(targetVal);
    double targetBase = isX ? angles['x']! : angles['y']!;
    double rotations = (current / (2 * pi)).floorToDouble();
    double nextBase = rotations * (2 * pi) + targetBase;
    if (nextBase < current) nextBase += (2 * pi);
    double end = nextBase + (2 * pi * 2);
    return Tween<double>(begin: current, end: end).animate(
      CurvedAnimation(parent: c, curve: Curves.easeOutBack),
    );
  }

  void runAllDice() {
    if (_controller1.isAnimating || _controller2.isAnimating) return;
    setState(() {
      _isDouble = false;
      _isRolling = true;
    });
    if (widget.targetSum != null) {
      int sum = widget.targetSum!;
      int t1 = (sum / 2).floor();
      int t2 = sum - t1;

      // _createTargetAnim은 이미 파일 내부에 정의되어 있습니다.
      _animationX1 = _createTargetAnim(_controller1, _x1, t1, true);
      _animationY1 = _createTargetAnim(_controller1, _y1, t1, false);
      _animationX2 = _createTargetAnim(_controller2, _x2, t2, true);
      _animationY2 = _createTargetAnim(_controller2, _y2, t2, false);
    } else {
      // 일반적인 랜덤 굴리기
      _animationX1 = _createRandomAnim(_controller1, _x1);
      _animationY1 = _createRandomAnim(_controller1, _y1);
      _animationX2 = _createRandomAnim(_controller2, _x2);
      _animationY2 = _createRandomAnim(_controller2, _y2);
    }
    _controller1.forward(from: 0.0);
    _controller2.forward(from: 0.0);
  }

  Animation<double> _createRandomAnim(AnimationController c, double cur) {
    double end = ((cur / (pi / 2)).round() + (Random().nextInt(4) + 6)) * (pi / 2);
    return Tween<double>(begin: cur, end: end).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut));
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

  void _calculateResult() async {
    int val1, val2;
    
    // 💡 [발표용] 치트 로직
    if (widget.targetSum != null) {
      val1 = (widget.targetSum! / 2).floor();
      val2 = widget.targetSum! - val1;
      // 짝수일 경우 더블이 되도록 단순 계산 (예: 4 -> 2,2)
    } else {
      val1 = _getFaceValue(_x1, _y1);
      val2 = _getFaceValue(_x2, _y2);
    }
    
    setState(() {
      _totalResult = val1 + val2;
      _isDouble = (val1 == val2);
      _isRolling = false;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      widget.onRoll(val1, val2);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.purple];
    int currentTurnIndex = (widget.turn - 1).clamp(0, 3);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
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
            SizedBox(
              height: 20,
              child: _isDouble && !_isRolling
                  ? const Text("✨ DOUBLE!! ✨", style: TextStyle(color: Colors.yellowAccent, fontSize: 16, fontWeight: FontWeight.bold))
                  : null,
            ),
            Text("남은턴 : ${widget.totalTurn}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            Text(widget.isBot ? "Bot ${widget.turn}의 턴" : "Player ${widget.turn}님의 턴", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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

            // 💡 [수정] 봇(isBot == true)이면 버튼을 숨김
            if (!widget.isBot)
              ElevatedButton(
                onPressed: runAllDice,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  backgroundColor: colors[currentTurnIndex],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                ),
                child: const Text("ROLL DICE 🎲", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            else
            // 버튼이 사라져서 레이아웃이 확 줄어드는게 싫다면 빈 공간을 둘 수 있음
              const SizedBox(height: 48),
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

// ... (Cube, DiceDotsPainter 클래스는 기존과 동일) ...
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
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateX(rx)..rotateY(ry)..rotateZ(rz)..translate(0.0, 0.0, size / 2),
      child: Center(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: Colors.white,
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
    final paint = Paint()..color = Colors.black;
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