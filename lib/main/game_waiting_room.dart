import 'package:flutter/material.dart';
import '../game/gameMain.dart';

class GameWaitingRoom extends StatefulWidget {
  const GameWaitingRoom({super.key});

  @override
  State<GameWaitingRoom> createState() => _GameWaitingRoomState();
}

class _GameWaitingRoomState extends State<GameWaitingRoom> {
  /// 슬롯 상태: N = 비어있음, P = 플레이어, B = 봇
  final List<String> userTypes = ["N", "N", "N", "P"]; // 4번 슬롯 기본 플레이어

  /// 참가 순서 (index 저장)
  final List<int> joinOrder = [];

  /// [좌상, 우상, 좌하, 우하] 표시용 번호
  final List<int> displayOrder = [2, 4, 3, 1];

  @override
  void initState() {
    super.initState();

    /// ✅ 기본 플레이어는 항상 1번
    joinOrder.add(3); // index 3 = 4번 슬롯
  }

  void _addUser(int index, String type) {
    setState(() {
      userTypes[index] = type;
      joinOrder.add(index);
    });
  }

  void _removeUser(int index) {
    setState(() {
      userTypes[index] = "N";
      joinOrder.remove(index);
    });
  }

  int _getDisplayNumber(int index) {
    final order = joinOrder.indexOf(index);
    return order == -1 ? 0 : order + 1; // ✅ 항상 1부터 시작
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final int activeCount =
        userTypes.where((type) => type != "N").length;

    final bool canStart = activeCount >= 2;

    return Scaffold(
      body: Stack(
        children: [
          // ================= 배경 =================
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.05)),

          // ================= 메인 =================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Stack(
                  children: [
                    isLandscape
                        ? _buildLandscapeGrid()
                        : _buildPortraitGrid(),

                    Center(
                      child: _buildStartButton(canStart),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ================= 나가기 버튼 =================
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: _buildCircleIcon(Icons.arrow_back),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ================== 세로 ================== */
  Widget _buildPortraitGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 1.2,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return _buildPlayerSlot(index);
      },
    );
  }

  /* ================== 가로 ================== */
  Widget _buildLandscapeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const int crossCount = 2;
        const double spacing = 12;

        final double slotWidth =
            (constraints.maxWidth - spacing) / crossCount;
        final double slotHeight =
            (constraints.maxHeight - spacing) / crossCount;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: slotWidth / slotHeight,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            return _buildPlayerSlot(index);
          },
        );
      },
    );
  }

  /* ================== 슬롯 ================== */
  Widget _buildPlayerSlot(int index) {
    final String type = userTypes[index];
    final bool isEmpty = type == "N";
    final int number = _getDisplayNumber(index);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6).withOpacity(isEmpty ? 0.6 : 1.0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFD7C0A1),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isEmpty
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _addUser(index, "B"),
                  child: _buildAddButton(Icons.android),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addUser(index, "P"),
                  child: _buildAddButton(Icons.person_add),
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == "B" ? Icons.android : Icons.person,
                  size: 30,
                  color: const Color(0xFF5D4037),
                ),
                const SizedBox(height: 6),
                Text(
                  type == "B"
                      ? "봇$number"
                      : "플레이어$number",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (!isEmpty && !(index == 3 && type == "P"))
          Positioned(
            top: 14,
            right: 8,
            child: GestureDetector(
              onTap: () => _removeUser(index),
              child: _buildCircleIcon(Icons.close),
            ),
          ),
      ],
    );
  }

  Widget _buildStartButton(bool canStart) {
    return ElevatedButton(
      onPressed: canStart
          ? () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameMain()),
        );
      }
          : null,
      child: const Text("게임 시작!"),
    );
  }

  Widget _buildAddButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.8),
        border: Border.all(color: const Color(0xFFD7C0A1)),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF8D6E63)),
    );
  }

  Widget _buildCircleIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFDF5E6).withOpacity(0.9),
        border: Border.all(color: const Color(0xFFD7C0A1), width: 2),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF5D4037)),
    );
  }
}
