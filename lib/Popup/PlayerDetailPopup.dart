import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';

class PlayerDetailPopup extends StatefulWidget {
  final String playerKey; // "user1", "user2" ...
  final Map<String, dynamic> playerData;
  final Map<String, dynamic> boardData;
  final List<String> logs; // ✅ 로그 데이터 추가
  final Color playerColor;
  final bool isTestMode;

  const PlayerDetailPopup({
    super.key,
    required this.playerKey,
    required this.playerData,
    required this.boardData,
    required this.logs, // ✅ 필수 인자로 추가
    required this.playerColor,
    this.isTestMode = false,
  });

  @override
  State<PlayerDetailPopup> createState() => _PlayerDetailPopupState();
}

class _PlayerDetailPopupState extends State<PlayerDetailPopup> {
  List<Map<String, dynamic>> ownedLands = [];
  String? realNickname;
  int? realPoints;
  String? realTier;
  int winCount = 0;
  int totalGames = 0;

  @override
  void initState() {
    super.initState();
    _calculateOwnedLands();
    if (widget.isTestMode) {
      _injectMockData();
    } else {
      _fetchRealUserInfo();
    }
  }

  void _injectMockData() {
    setState(() {
      realNickname = "테스트_전설_여행자";
      realPoints = 12500;
      realTier = "전설의 유람객";
      winCount = 45;
      totalGames = 50;
    });
  }

  // 소유한 땅 목록 및 레벨 계산
  void _calculateOwnedLands() {
    List<Map<String, dynamic>> lands = [];
    int playerNum = int.parse(widget.playerKey.replaceAll('user', ''));
    
    widget.boardData.forEach((key, value) {
      if (value['owner'].toString() == playerNum.toString()) {
        lands.add({
          'name': value['name'] ?? "알 수 없는 땅",
          'level': value['level'] ?? 0,
        });
      }
    });
    setState(() {
      ownedLands = lands;
    });
  }

  // 로그인 유저일 경우 실제 정보 가져오기
  Future<void> _fetchRealUserInfo() async {
    if (widget.playerKey == "user1") {
      final uid = AuthService.instance.currentUid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('members').doc(uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            realNickname = data['nickname'];
            realPoints = data['point'];
            realTier = AuthService.getTierName(realPoints ?? 0);
            winCount = data['winCount'] ?? 0;
            totalGames = data['totalGames'] ?? 0;
          });
        }
      }
    }
  }

  String get winRate {
    if (totalGames == 0) return "0%";
    return "${((winCount / totalGames) * 100).toStringAsFixed(1)}%";
  }

  String _formatMoney(dynamic number) {
    if (number == null) return "0";
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    String type = widget.playerData['type'] ?? "P";
    String displayName = (type == "B") ? "인공지능 봇" : (realNickname ?? "여행자 ${widget.playerKey.replaceAll('user', '')}");

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 450,
        height: 320, // 탭 공간 확보를 위해 높이 약간 증가
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF8D6E63), width: 4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15)],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Image.asset('assets/Logo.png', fit: BoxFit.contain),
              ),
            ),

            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // 1. 탭 바
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF8D6E63), width: 2)),
                    ),
                    child: const TabBar(
                      labelColor: Color(0xFF5D4037),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFF5D4037),
                      indicatorWeight: 3,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: [
                        Tab(text: "정보"),
                        Tab(text: "기록"),
                      ],
                    ),
                  ),

                  // 2. 탭 내용
                  Expanded(
                    child: TabBarView(
                      children: [
                        // [정보 탭] - 기존 UI
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              // 왼쪽: 프로필 및 요약
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 33,
                                      backgroundColor: widget.playerColor,
                                      child: const Icon(Icons.person, size: 40, color: Colors.white),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      displayName,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                                    ),
                                    if (realTier != null)
                                      Column(
                                        children: [
                                          Text(
                                            "$realTier (${_formatMoney(realPoints)}P)",
                                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            "승률: $winRate ($winCount승 / $totalGames판)",
                                            style: TextStyle(fontSize: 11, color: Colors.brown.withOpacity(0.8)),
                                          ),
                                        ],
                                      ),
                                    const Divider(color: Colors.brown, height: 20),
                                    _infoRow("보유 현금", "${_formatMoney(widget.playerData['money'])}원"),
                                    _infoRow("총 자산", "${_formatMoney(widget.playerData['totalMoney'])}원"),
                                  ],
                                ),
                              ),

                              const VerticalDivider(color: Colors.brown, width: 30),

                              // 오른쪽: 보유 문화재 목록
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "📜 보유 문화재 목록",
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: ownedLands.isEmpty
                                          ? const Center(child: Text("보유한 문화재가 없습니다.", style: TextStyle(fontSize: 12, color: Colors.grey)))
                                          : ListView.builder(
                                        itemCount: ownedLands.length,
                                        itemBuilder: (context, index) {
                                          final land = ownedLands[index];
                                          final int level = land['level'];

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    land['name'],
                                                    style: const TextStyle(fontSize: 13, color: Color(0xFF3E2723), fontWeight: FontWeight.w500),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // 건설 단계 표시
                                                _buildLevelBadge(level),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // [기록] 탭 - 실제 로그 표시
                        widget.logs.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.history_edu, size: 40, color: Colors.grey),
                                    SizedBox(height: 10),
                                    Text("아직 기록된 활동이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(15),
                                itemCount: widget.logs.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE0C9A6)),
                                itemBuilder: (context, index) {
                                  final log = widget.logs[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.arrow_right, size: 16, color: Colors.brown),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            log,
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037), height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 닫기 버튼
            Positioned(
              top: 5,
              right: 5,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.brown),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.brown)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
        ],
      ),
    );
  }

  // 💡 레벨별 배지 생성 위젯
  Widget _buildLevelBadge(int level) {
    if (level <= 0) return const SizedBox();
    
    bool isLandmark = level >= 4;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isLandmark ? const Color(0xFFFFD700) : Colors.brown[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isLandmark ? Colors.orange : Colors.brown, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLandmark) const Icon(Icons.stars, size: 10, color: Colors.white),
          if (!isLandmark) const Icon(Icons.home, size: 10, color: Colors.brown),
          const SizedBox(width: 2),
          Text(
            isLandmark ? "랜드마크" : "$level단계",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isLandmark ? Colors.white : Colors.brown[800],
            ),
          ),
        ],
      ),
    );
  }
}
