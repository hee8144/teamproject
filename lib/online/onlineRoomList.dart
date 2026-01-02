import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  Map<String, dynamic> rooms = {};
  bool isJoining = false;

  @override
  void initState() {
    super.initState();
    socketService.connect();
    socket = socketService.socket!;

    socket.on("room_list", (data) {
      if (mounted) {
        setState(() {
          // 서버에서 보내주는 데이터 형식을 확실히 맵으로 변환
          rooms = Map<String, dynamic>.from(data);
          print("방 목록 갱신됨: ${rooms.length}"); // 로그를 찍어보세요
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

  /// [핵심 수정] 서브 컬렉션(users) 구조에 맞춰 빈자리 찾기
  Future<void> _updateFirestoreAndNavigate(String roomId) async {
    final roomRef = FirebaseFirestore.instance.collection('online').doc(roomId);
    final usersCol = roomRef.collection('users');

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. 방 정보가 없으면 초기 생성
        DocumentSnapshot roomSnap = await transaction.get(roomRef);
        if (!roomSnap.exists) {
          transaction.set(roomRef, {'status': 'waiting', 'createdAt': FieldValue.serverTimestamp()});

          // user01~04 문서 미리 생성 (user01은 방장)
          transaction.set(usersCol.doc('user01'), {'type': 'P', 'name': '플레이어 1(방장)', 'id': socket.id});
          transaction.set(usersCol.doc('user02'), {'type': 'N'});
          transaction.set(usersCol.doc('user03'), {'type': 'N'});
          transaction.set(usersCol.doc('user04'), {'type': 'N'});
          return;
        }

        // 2. 빈자리 찾기 (user01 ~ user04 문서 순회)
        String? targetDocId;
        int playerNum = 0;

        for (int i = 1; i <= 4; i++) {
          String docId = 'user0$i';
          DocumentSnapshot userSnap = await transaction.get(usersCol.doc(docId));

          if (userSnap.exists) {
            Map<String, dynamic> userData = userSnap.data() as Map<String, dynamic>;
            // 이미 입장해 있다면 중단
            if (userData['id'] == socket.id) return;

            // 빈자리('N') 발견 시 타겟 지정
            if (targetDocId == null && userData['type'] == 'N') {
              targetDocId = docId;
              playerNum = i;
            }
          }
        }

        // 3. 빈자리에 내 정보 업데이트
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

  void createRoom() {
    if (isJoining) return;
    setState(() => isJoining = true);
    String newId = (Random().nextInt(9000) + 1000).toString();
    socket.emit("create_room", newId);
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
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final roomDocs = snapshot.data!.docs;

          if (roomDocs.isEmpty) {
            return const Center(child: Text("방이 없습니다."));
          }

          return ListView.builder(
            itemCount: roomDocs.length,
            itemBuilder: (context, index) {
              final roomId = roomDocs[index].id;
              return ListTile(
                title: Text("방 번호: $roomId"),
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