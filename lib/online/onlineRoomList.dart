import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../network/socket_service.dart';

class OnlineRoomListPage extends StatefulWidget {
  const OnlineRoomListPage({super.key});

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

  /// Firestore 업데이트 및 이동
  Future<void> _updateFirestoreAndNavigate(String roomId) async {
    final roomRef = FirebaseFirestore.instance.collection('online').doc(roomId);
    final usersCol = roomRef.collection('users');

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot roomSnap = await transaction.get(roomRef);
        if (!roomSnap.exists) {
          transaction.set(roomRef, {'status': 'waiting', 'createdAt': FieldValue.serverTimestamp()});
          transaction.set(usersCol.doc('user1'), {'type': 'P', 'name': '플레이어 1(방장)', 'id': socket.id});
          transaction.set(usersCol.doc('user2'), {'type': 'N'});
          transaction.set(usersCol.doc('user3'), {'type': 'N'});
          transaction.set(usersCol.doc('user4'), {'type': 'N'});
          return;
        }

        String? targetDocId;
        int playerNum = 0;

        for (int i = 1; i <= 4; i++) {
          String docId = 'user$i';
          DocumentSnapshot userSnap = await transaction.get(usersCol.doc(docId));

          if (userSnap.exists) {
            Map<String, dynamic> userData = userSnap.data() as Map<String, dynamic>;
            if (userData['id'] == socket.id) return;
            if (targetDocId == null && userData['type'] == 'N') {
              targetDocId = docId;
              playerNum = i;
            }
          }
        }

        if (targetDocId != null) {
          transaction.update(usersCol.doc(targetDocId), {
            'type': 'P',
            'name': '플레이어 $playerNum',
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

      // 2. 보드 데이터 준비 (생략되지 않도록 주의)
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

              // 💡 [수정됨] 지역 이름 제거 로직
              for (var map in localList) {
                String region = map.keys.first; // '서울', '인천' 등
                if (shortName.startsWith(region)) {
                  // 지역명 길이만큼 자르고 공백 제거 (예: "서울 숭례문" -> "숭례문")
                  shortName = shortName.substring(region.length).trim();
                  break;
                }
              }

              boardData[key]["fullName"] = fullName; // 원래 이름
              boardData[key]["name"] = shortName; // 줄임 이름
              heritageIndex++;
            }
          }
        }
      }
      // 수정된 보드 데이터를 해당 방 문서에 저장
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
      "creator": { "name": "플레이어 1(방장)", "id": socket.id }
    });

    // 3. Firestore 데이터 주입 (지역명 제거 로직 포함됨)
    // await _insertLocal(newId);

    await _readLocal();
    await _readPlayer();
    await rankChange();

    print("📡 방 생성 및 데이터 주입 완료: $newId");
  }

  void joinRoom(String roomId) {
    if (isJoining) return;
    setState(() => isJoining = true);
    socket.emit("join_room", roomId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("온라인 방 목록")),
      floatingActionButton: FloatingActionButton(
        onPressed: createRoom,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('online').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final roomDocs = snapshot.data!.docs;

          if (roomDocs.isEmpty) {
            return const Center(child: Text("방이 없습니다."));
          }

          return ListView.builder(
            itemCount: roomDocs.length,
            itemBuilder: (context, index) {
              final roomId = roomDocs[index].id;
              // 방 상태나 인원 등을 DB에서 추가로 읽어와 표시 가능
              return ListTile(
                leading: const Icon(Icons.meeting_room, color: Colors.blue),
                title: Text("방 번호: $roomId"),
                subtitle: const Text("대기 중..."),
                trailing: ElevatedButton(
                  onPressed: () => joinRoom(roomId),
                  child: const Text("입장"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}