import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RoomSelectPage(),
    );
  }
}

/* ================= 방 선택 화면 ================= */

class RoomSelectPage extends StatefulWidget {
  const RoomSelectPage({super.key});

  @override
  State<RoomSelectPage> createState() => _RoomSelectPageState();
}

class _RoomSelectPageState extends State<RoomSelectPage> {
  late IO.Socket socket;
  Map<String, dynamic> rooms = {};

  @override
  void initState() {
    super.initState();
    connectSocket();
  }

  void connectSocket() {
    socket = IO.io(
      // 🔹 Web → localhost
      // 🔹 Android Emulator → 10.0.2.2
      'http://localhost:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print("소켓 연결됨");
      socket.emit("get_rooms");
    });

    socket.on("room_list", (data) {
      setState(() {
        rooms = Map<String, dynamic>.from(data);
      });
    });

    socket.on("join_success", (roomId) {
      enterRoom(roomId);
    });

    socket.onDisconnect((_) {
      print("소켓 끊김");
    });
  }

  void createRoom() {
    socket.emit("create_room");
  }

  void joinRoom(String roomId) {
    socket.emit("join_room", roomId);
  }

  void enterRoom(String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomPage(roomId: roomId, socket: socket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("방 선택")),
      floatingActionButton: FloatingActionButton(
        onPressed: createRoom,
        child: const Icon(Icons.add),
      ),
      body: rooms.isEmpty
          ? const Center(child: Text("방이 없습니다"))
          : ListView(
        children: rooms.keys.map((roomId) {
          final count = rooms[roomId]["players"].length;
          return ListTile(
            title: Text("방 ID : $roomId"),
            subtitle: Text("인원 : $count"),
            trailing: ElevatedButton(
              onPressed: () => joinRoom(roomId),
              child: const Text("입장"),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* ================= 방 내부 화면 ================= */

class RoomPage extends StatelessWidget {
  final String roomId;
  final IO.Socket socket;

  const RoomPage({
    super.key,
    required this.roomId,
    required this.socket,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("방 $roomId")),
      body: const Center(
        child: Text(
          "게임 대기중...",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
