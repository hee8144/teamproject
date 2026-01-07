import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;

  void connect() {
    if (socket != null && socket!.connected) return;

    socket = IO.io(
      // 'http://10.0.2.2:3000', // Android 에뮬레이터면 10.0.2.2
      'http://localhost:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ socket connected');
    });
  }
}
