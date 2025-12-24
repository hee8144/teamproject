import 'package:flutter/material.dart';

class GameWaitingRoom extends StatefulWidget {
  const GameWaitingRoom({super.key});

  @override
  State<GameWaitingRoom> createState() => _GameWaitingRoomState();
}

class _GameWaitingRoomState extends State<GameWaitingRoom> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Stack(
        children: [
          // ================== 배경 ==================
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

          // ================== 메인 콘텐츠 ==================
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: isLandscape ? 20 : 100,
              ),
              child: isLandscape
                  ? _buildLandscapeGrid(size)
                  : _buildPortraitGrid(),
            ),
          ),

          // ================== X 버튼 ==================
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: _buildCircleIcon(Icons.close),
              ),
            ),
          ),

          // ================== 게임 시작 버튼 ==================
          Positioned(
            bottom: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: _buildStartButton(),
            ),
          ),
        ],
      ),
    );
  }

  /* ================== 플레이어 그리드 - 세로 ================== */
  Widget _buildPortraitGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.2,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          // 호스트만 Master, 나머지는 empty
          String type = index == 0 ? "player" : "empty";
          return _buildPlayerSlot(index, type);
        },
      ),
    );
  }

  /* ================== 플레이어 그리드 - 가로 ================== */
  Widget _buildLandscapeGrid(Size size) {
    final double padding = 20;
    final double spacing = 10;
    final int crossCount = 2;

    final double totalWidth = size.width - padding * 2 - spacing * (crossCount - 1);
    final double slotWidth = totalWidth / crossCount;

    final double totalHeight = size.height - padding * 2 - spacing * (crossCount - 1) - 80;
    final double slotHeight = totalHeight / crossCount;

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
        // 호스트만 Master, 나머지는 empty
        String type = index == 0 ? "player" : "empty";
        return _buildPlayerSlot(index, type);
      },
    );
  }

  /* ================== 플레이어 슬롯 ================== */
  Widget _buildPlayerSlot(int index, String type) {
    final isHost = index == 0;
    final isEmpty = type == "empty";

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6).withOpacity(isEmpty ? 0.6 : 1.0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHost ? const Color(0xFFE6AD5C) : const Color(0xFFD7C0A1),
          width: isHost ? 3 : 1.5,
        ),
      ),
      child: Center(
        child: isEmpty
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAddButton(Icons.android),
            const SizedBox(width: 8),
            _buildAddButton(Icons.person_add),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.stars,
              size: 30,
              color: Color(0xFF5D4037),
            ),
            const SizedBox(height: 6),
            const Text(
              "Master",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
      ),
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

  /* ================== 게임 시작 버튼 ================== */
  Widget _buildStartButton() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6).withOpacity(0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD7C0A1), width: 2),
      ),
      child: SizedBox(
        height: 42,
        child: ElevatedButton(
          onPressed: () {
            debugPrint("게임 시작!");
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            backgroundColor: const Color(0xFFFFCC80),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: const Text(
            "게임 시작!",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  /* ================== 공통 ================== */
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
