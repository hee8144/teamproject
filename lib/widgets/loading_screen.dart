import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Vector3;

enum LoadingType { dice, inkBrush }

class LoadingScreen extends StatefulWidget {
  final String message;
  final bool isOverlay;
  final LoadingType type;

  const LoadingScreen({
    super.key,
    this.message = "데이터를 불러오는 중입니다...",
    this.isOverlay = false,
    this.type = LoadingType.dice,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final double _diceSize = 35.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget loadingWidget;
    
    switch (widget.type) {
      case LoadingType.inkBrush:
        loadingWidget = const RepaintBoundary(child: InkBrushLoading());
        break;
      case LoadingType.dice:
      default:
        loadingWidget = SizedBox(
          width: 60,
          height: 60,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double x = _controller.value * 2 * math.pi;
              double y = _controller.value * 4 * math.pi;
              return RepaintBoundary(child: _build3DCube(x, y));
            },
          ),
        );
    }

    Widget content = Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF5D4037), width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 5),
            SizedBox(
              height: 65,
              child: Center(child: loadingWidget),
            ),
            const SizedBox(height: 10),
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                backgroundColor: Colors.brown[100],
                color: const Color(0xFF8D6E63),
                minHeight: 2,
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );

    if (widget.isOverlay) {
      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {},
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
            content,
          ],
        ),
      );
    }

    return content;
  }

  Widget _build3DCube(double x, double y) {
    List<Map<String, dynamic>> faces = [
      {'v': 1, 'x': x, 'y': y, 'z': 0.0},
      {'v': 6, 'x': x, 'y': y + math.pi, 'z': 0.0},
      {'v': 2, 'x': x + math.pi / 2, 'y': 0.0, 'z': -y},
      {'v': 5, 'x': x - math.pi / 2, 'y': 0.0, 'z': y},
      {'v': 3, 'x': x, 'y': y + math.pi / 2, 'z': 0.0},
      {'v': 4, 'x': x, 'y': y - math.pi / 2, 'z': 0.0},
    ];

    faces.sort((a, b) => _calcZ(a['x'], a['y'], a['z']).compareTo(_calcZ(b['x'], b['y'], b['z'])));

    return Stack(
      children: faces.map((f) => _buildSide(f['x'], f['y'], f['z'], f['v'])).toList(),
    );
  }

  double _calcZ(double rx, double ry, double rz) {
    final m = Matrix4.identity()
      ..rotateX(rx)
      ..rotateY(ry)
      ..rotateZ(rz)
      ..translate(0.0, 0.0, _diceSize / 2);
    final v = Vector3(0, 0, 0);
    m.perspectiveTransform(v);
    return v.z;
  }

  Widget _buildSide(double rx, double ry, double rz, int val) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(rx)
        ..rotateY(ry)
        ..rotateZ(rz)
        ..translate(0.0, 0.0, _diceSize / 2),
      child: Center(
        child: Container(
          width: _diceSize,
          height: _diceSize,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(width: 1, color: Colors.black12),
            borderRadius: BorderRadius.circular(_diceSize * 0.15),
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
    final paint = Paint()..color = Colors.black87;
    final r = size.width * 0.1;
    final w = size.width, h = size.height;
    void draw(double x, double y) => canvas.drawCircle(Offset(x, y), r, paint);
    
    if (value % 2 != 0) draw(w / 2, h / 2);
    if (value >= 2) { draw(w * 0.25, h * 0.25); draw(w * 0.75, h * 0.75); }
    if (value >= 4) { draw(w * 0.75, h * 0.25); draw(w * 0.25, h * 0.75); }
    if (value == 6) { draw(w * 0.25, h * 0.5); draw(w * 0.75, h * 0.5); }
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

/// 수묵화 붓터치 애니메이션 위젯
class InkBrushLoading extends StatefulWidget {
  final double size;
  const InkBrushLoading({super.key, this.size = 50.0});

  @override
  State<InkBrushLoading> createState() => _InkBrushLoadingState();
}

class _InkBrushLoadingState extends State<InkBrushLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: InkBrushPainter(_controller.value),
        );
      },
    );
  }
}

class InkBrushPainter extends CustomPainter {
  final double progress;
  InkBrushPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + (progress * math.pi * 2),
      math.pi * 0.8,
    );

    canvas.drawPath(path, paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    canvas.drawPath(path, paint..maskFilter = null..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant InkBrushPainter oldDelegate) => oldDelegate.progress != progress;
}
