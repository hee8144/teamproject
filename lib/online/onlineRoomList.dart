import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../network/socket_service.dart';

class OnlineRoomListPage extends StatefulWidget {
  final String userNickname; // 💡 외부에서 받아온 닉네임

  const OnlineRoomListPage({
    super.key,
    required this.userNickname,
  });

  @override
  State<OnlineRoomListPage> createState() => _OnlineRoomListPageState();
}

class _OnlineRoomListPageState extends State<OnlineRoomListPage> {
  final socketService = SocketService();
  late IO.Socket socket;
  int localcode = 0;
  List<Map<String, String>> heritageList = [];
  Map<String, dynamic> boardList = {};
  Map<String, dynamic> players = {};

  // 지역 리스트
  List<Map<String, dynamic>> localList = [
    {'인천': {'ccbaCtcd': 23}},{'세종': {'ccbaCtcd': 45}},{'울산': {'ccbaCtcd': 26}},
    {'제주': {'ccbaCtcd': 50}},{'대구': {'ccbaCtcd': 22}},{'충북': {'ccbaCtcd': 33}},
    {'전북': {'ccbaCtcd': 35}},{'강원': {'ccbaCtcd': 32}},
    {'부산': {'ccbaCtcd': 21}},{'충남': {'ccbaCtcd': 35}},{'경기': {'ccbaCtcd': 31}},
    {'경남': {'ccbaCtcd': 38}},{'전남': {'ccbaCtcd': 36}},{'경북': {'ccbaCtcd': 37}},
    {'광주': {'ccbaCtcd': 24}},{'서울': {'ccbaCtcd': 11}}
  ];

  List<dynamic> rooms = [];
  bool isJoining = false;

  @override
  void initState() {
    super.initState();
    socketService.connect();
    socket = socketService.socket!;

    socket.on("room_list", (data) {
      if (mounted) {
        setState(() {
          if (data is List) {
            rooms = data;
          } else if (data is Map && data.containsKey('rooms')) {
            rooms = data['rooms'];
          }
          print("방 목록 갱신됨: ${rooms.length}개");
        });
      }
    });

    socket.on("join_success", (roomId) {
      _updateFirestoreAndNavigate(roomId);
    });

    socket.on("join_failed", (message) {
      setState(() => isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });

    socket.emit("get_rooms");
  }

  /// Firestore 업데이트 및 이동 (닉네임 저장 로직 포함)
  Future<void> _updateFirestoreAndNavigate(String roomId) async {
    final roomRef = FirebaseFirestore.instance.collection('online').doc(roomId);
    final usersCol = roomRef.collection('users');

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot roomSnap = await transaction.get(roomRef);

        // 방이 없으면 초기화 (보통 서버가 하지만 안전장치)
        if (!roomSnap.exists) {
          transaction.set(roomRef, {'status': 'waiting', 'createdAt': FieldValue.serverTimestamp()});
          transaction.set(usersCol.doc('user1'), {
            'type': 'P',
            'name': widget.userNickname, // 💡 내 닉네임 사용
            'id': socket.id
          });
          transaction.set(usersCol.doc('user2'), {'type': 'N'});
          transaction.set(usersCol.doc('user3'), {'type': 'N'});
          transaction.set(usersCol.doc('user4'), {'type': 'N'});
          return;
        }

        String? targetDocId;

        // 빈 자리 찾기
        for (int i = 1; i <= 4; i++) {
          String docId = 'user$i';
          DocumentSnapshot userSnap = await transaction.get(usersCol.doc(docId));

          if (userSnap.exists) {
            Map<String, dynamic> userData = userSnap.data() as Map<String, dynamic>;
            if (userData['id'] == socket.id) return; // 이미 접속 중이면 패스
            if (targetDocId == null && userData['type'] == 'N') {
              targetDocId = docId;
            }
          }
        }

        // 빈 자리에 내 정보 업데이트
        if (targetDocId != null) {
          transaction.update(usersCol.doc(targetDocId), {
            'type': 'P',
            'name': widget.userNickname, // 💡 내 닉네임 사용
            'id': socket.id,
          });
        }
      });

      if (mounted) {
        setState(() => isJoining = false);
        context.go('/onlineWaitingRoom/$roomId');
      }
    } catch (e) {
      debugPrint("DB 에러: $e");
      setState(() => isJoining = false);
    }
  }

  String getXmlText(xml.XmlElement parent, String tagName) {
    final elements = parent.findElements(tagName);
    return elements.isNotEmpty ? elements.first.innerText.trim() : "";
  }

  Future<List<Map<String, String>>> _loadHeritage() async {
    final String url = "https://www.khs.go.kr/cha/SearchKindOpenapiList.do?ccbaCtcd=$localcode&pageIndex=1&pageUnit=24";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final document = xml.XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      return items.map((node) => {
        '이름': getXmlText(node, 'ccbaMnm1'),
        '종목코드': getXmlText(node, 'ccbaKdcd'),
        '관리번호': getXmlText(node, 'ccbaAsno'),
        '시도코드': getXmlText(node, 'ccbaCtcd'),
        '시군구명': getXmlText(node, 'ccsiName'),
      }).toList();
    }
    return [];
  }

  Future<List<Map<String, String>>> _loadHeritageDetail() async{
    final detailList = heritageList.map((item) async{
      final String detailUrl =
          "https://www.khs.go.kr/cha/SearchKindOpenapiDt.do?ccbaKdcd=${item["종목코드"]}&ccbaAsno=${item["관리번호"]}&ccbaCtcd=${item["시도코드"]}";
      try {
        final res = await http.get(Uri.parse(detailUrl));
        if (res.statusCode == 200) {
          final doc = xml.XmlDocument.parse(res.body);
          final detailItem = doc.findAllElements('item').firstOrNull;
          item['상세설명'] = detailItem != null ? getXmlText(detailItem, 'content') : "설명 없음";
          item['이미지링크'] = detailItem != null ? getXmlText(detailItem, 'imageUrl') : "이미지 없음";
          item['시대'] = detailItem != null ? getXmlText(detailItem, 'ccceName') : "시대 없음";
        } else {
          item['상세설명'] = "정보 없음"; item['이미지링크'] = ""; item['시대'] = "";
        }
      } catch (e) {
        item['상세설명'] = "에러"; item['이미지링크'] = ""; item['시대'] = "에러";
      }
      return item;
    });
    return await Future.wait(detailList);
  }

  Future<void> _insertLocal(String roomId) async {
    try {
      if (heritageList.isEmpty) return;

      final roomRef = FirebaseFirestore.instance.collection("online").doc(roomId);

      // 1. 퀴즈 데이터 준비
      Map<String, dynamic> quizUpdates = {};
      for (int i = 1; i <= 24; i++) {
        if (i - 1 < heritageList.length) {
          quizUpdates["q$i"] = {
            "name": heritageList[i - 1]["이름"],
            "description": heritageList[i - 1]["상세설명"],
            "times": heritageList[i - 1]["시대"],
            "img": heritageList[i - 1]["이미지링크"]
          };
        }
      }

      // 2. 보드 데이터 준비
      DocumentSnapshot boardSnap = await FirebaseFirestore.instance.collection("games").doc("board").get();
      Map<String, dynamic> boardData = {};

      if (boardSnap.exists) {
        boardData = boardSnap.data() as Map<String, dynamic>;
        int heritageIndex = 0;

        for (int i = 1; i <= 27; i++) {
          String key = "b$i";
          if (boardData[key] != null && boardData[key]['type'] == 'land') {
            if (heritageIndex < heritageList.length) {
              String fullName = heritageList[heritageIndex]["이름"]!;
              String shortName = fullName;

              for (var map in localList) {
                String region = map.keys.first;
                if (shortName.startsWith(region)) {
                  shortName = shortName.substring(region.length).trim();
                  break;
                }
              }

              boardData[key]["fullName"] = fullName;
              boardData[key]["name"] = shortName;
              heritageIndex++;
            }
          }
        }
      }
      await roomRef.set({
        "quiz": quizUpdates,
        "board": boardData,
      }, SetOptions(merge: true));

      debugPrint("✅ Firestore에 퀴즈 및 보드 데이터 주입 완료");
    } catch (e) {
      debugPrint("❌ _insertLocal 에러: $e");
    }
  }

  Future<void> _readLocal() async{
    final snap = await FirebaseFirestore.instance.collection("games").doc("board").get();
    if(snap.exists && snap.data() != null){
      Map<String, dynamic> boardData = snap.data() as Map<String, dynamic>;
      if(mounted) {
        setState(() { boardList = boardData; });
      }
    }
  }

  Future<void> _readPlayer() async{
    final snap = await FirebaseFirestore.instance.collection("games").doc("users").get();
    setState(() { players = snap.data() ?? {}; });
  }

  Future<void> rankChange() async {
    List<Map<String, dynamic>> tempUsers = [];
    for (int i = 1; i <= 4; i++) {
      if (players["user$i"] != null && players["user$i"]["type"] != "N" &&
          players["user$i"]["type"] != "D" &&
          players["user$i"]["type"] != "BD") {
        tempUsers.add({
          "key": "user$i",
          "totalMoney": players["user$i"]["totalMoney"] ?? 0,
          "money": players["user$i"]["money"] ?? 0,
        });
      }
    }
  }

  Future<void> createRoom() async {
    if (isJoining) return;
    setState(() => isJoining = true);

    String newId = (Random().nextInt(9000) + 1000).toString();

    // 1. 데이터 준비
    int random = Random().nextInt(localList.length);
    String selectedLocalName = localList[random].keys.first.toString();
    localcode = localList[random][selectedLocalName]['ccbaCtcd'];

    heritageList = await _loadHeritage();
    heritageList = await _loadHeritageDetail();

    // 2. 서버 방 생성 요청
    socket.emit("create_room", {
      "roomId": newId,
      "localName": selectedLocalName,
      "localCode": localcode.toString(),
      // 💡 방 생성 시 방장 닉네임 전송
      "creator": { "name": widget.userNickname, "id": socket.id }
    });

    // 3. Firestore 데이터 주입
    await _insertLocal(newId);
    await _readLocal();
    await _readPlayer();
    await rankChange();

    print("📡 방 생성 완료: $newId");
  }

  void joinRoom(String roomId) {
    if (isJoining) return;
    setState(() => isJoining = true);
    socket.emit("join_room", roomId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "온라인 방 목록",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22),
        ),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        // ✅ [추가] 왼쪽 상단 뒤로가기 버튼
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            context.go('/onlinemain'); // 이전 화면으로 이동
          },
        ),
      ),
      body: Stack(
        children: [
          // 1. 배경 이미지
          Positioned.fill(
            child: Image.asset(
              "assets/board-background.PNG",
              fit: BoxFit.cover,
            ),
          ),
          // 2. 어두운 오버레이
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
          // 3. 메인 컨텐츠
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('online').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                final roomDocs = snapshot.data!.docs;

                if (roomDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.meeting_room_outlined, size: 80, color: Colors.white70),
                        SizedBox(height: 16),
                        Text(
                          "생성된 방이 없습니다.\n새로운 방을 만들어보세요!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: roomDocs.length,
                  itemBuilder: (context, index) {
                    final roomId = roomDocs[index].id;
                    final data = roomDocs[index].data() as Map<String, dynamic>?;
                    final String localName = data?['localName'] ?? "지역 미정";
                    final String status = data?['status'] == 'waiting' ? "대기중" : "게임중";
                    final bool isWaiting = data?['status'] == 'waiting';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF5E6).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF5D4037), width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF5D4037),
                          radius: 24,
                          child: Text(
                            localName.isNotEmpty ? localName.substring(0, 1) : "?",
                            style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          "방 번호 : $roomId",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              "$localName  |  $status",
                              style: TextStyle(
                                fontSize: 14,
                                color: isWaiting ? Colors.green[800] : Colors.red[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: isWaiting ? () => joinRoom(roomId) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isWaiting ? const Color(0xFF5D4037) : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: Text(isWaiting ? "입장" : "진행중"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createRoom,
        backgroundColor: const Color(0xFF5D4037),
        icon: isJoining
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add_circle, color: Color(0xFFFFD700)),
        label: Text(
          isJoining ? "생성 중..." : "방 만들기",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}