/* ================= GameState ================= */

class GameState {
  final Map<int, UserState> users;
  final Map<int, TileState> board;
  final int currentTurn;
  final int totalTurn;
  final int doubleCount;
  final bool finished;

  GameState({
    required this.users,
    required this.board,
    required this.currentTurn,
    required this.totalTurn,
    required this.doubleCount,
    required this.finished,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    final users = <int, UserState>{};
    final board = <int, TileState>{};

    json['users'].forEach((key, value) {
      final index = int.parse(key.replaceAll('user', ''));
      users[index] = UserState.fromJson(value);
    });

    json['board'].forEach((key, value) {
      final index = int.parse(key.replaceAll('b', ''));
      board[index] = TileState.fromJson(value);
    });

    return GameState(
      users: users,
      board: board,
      currentTurn: json['currentTurn'],
      totalTurn: json['totalTurn'],
      doubleCount: json['doubleCount'],
      finished: json['finished'],
    );
  }
}

/* ================= User ================= */

class UserState {
  final int money;
  final int totalMoney;
  final int position;
  final String type; // P | D | I
  final int islandTurn;
  final bool isDoubleToll;
  final int rank;

  const UserState({
    required this.money,
    required this.totalMoney,
    required this.position,
    required this.type,
    required this.islandTurn,
    required this.isDoubleToll,
    required this.rank,
  });

  factory UserState.fromJson(Map<String, dynamic> json) {
    return UserState(
      money: json['money'],
      totalMoney: json['totalMoney'],
      position: json['position'],
      type: json['type'],
      islandTurn: json['islandTurn'],
      isDoubleToll: json['isDoubleToll'],
      rank: json['rank'],
    );
  }

  bool get isAlive => type == 'P';
  bool get isIsland => type == 'I';
}

/* ================= Tile ================= */

class TileState {
  final int index;
  final String type; // land | island | chance
  final int owner;
  final int level;
  final int price;
  final int multiply;

  const TileState({
    required this.index,
    required this.type,
    required this.owner,
    required this.level,
    required this.price,
    required this.multiply,
  });

  factory TileState.fromJson(Map<String, dynamic> json) {
    return TileState(
      index: json['index'],
      type: json['type'],
      owner: json['owner'],
      level: json['level'],
      price: json['price'],
      multiply: json['multiply'],
    );
  }

  bool get isLand => type == 'land';
  bool get isIsland => type == 'island';
  bool get isChance => type == 'chance';
}
