class GameLogManager {
  // 플레이어별 로그 저장소 (user1 ~ user4)
  final Map<String, List<String>> _logs = {
    "user1": [],
    "user2": [],
    "user3": [],
    "user4": []
  };

  // 현재 진행 중인 턴의 임시 로그 버퍼
  String _currentTurnBuffer = "";

  /// 로그 직접 추가 (시스템 메시지 등 단순 기록용)
  void addLog(String playerKey, String message) {

    if (_logs.containsKey(playerKey)) {
      // 최신순으로 맨 앞에 추가
      _logs[playerKey]!.insert(0, message);
    }
  }

  // ================= 턴 로그 빌더 기능 =================

  /// 1. 턴 시작 (턴 번호만 먼저 기록 가능)
  void startTurnLog(int turn, [int? dice]) {
    String diceStr = dice != null ? "주사위 $dice " : "";
    _currentTurnBuffer = "[$turn턴] $diceStr";
  }

  /// 주사위 결과만 나중에 추가 (보석금 지불 후 주사위 굴릴 때 사용)
  void addDiceLog(int dice) {
    if (!_currentTurnBuffer.contains("주사위")) {
      _currentTurnBuffer = _currentTurnBuffer.replaceFirst("] ", "] 주사위 $dice ");
    } else {
      // 이미 주사위 정보가 있다면 (예: 0에서 업데이트)
      _currentTurnBuffer = _currentTurnBuffer.replaceFirst(RegExp(r"주사위 \d+"), "주사위 $dice");
    }
  }

  /// 2. 도착지 설정 (이동 완료 후 호출)
  void setArrivalLog(String landName) {
    _currentTurnBuffer += "→ $landName 도착\n";
  }

  /// 3. 행동 결과 추가 (건설, 지불, 인수, 카드 등)
  void addActionLog(String action) {
    _currentTurnBuffer += "└ $action\n";
  }

  /// 4. 턴 종료 시 로그 저장 (다음 턴 넘기기 직전 호출)
  void commitLog(String playerKey) {
    if (_currentTurnBuffer.isNotEmpty) {
      addLog(playerKey, _currentTurnBuffer.trim());
      _currentTurnBuffer = ""; // 버퍼 초기화
    }
  }

  // ====================================================

  /// 특정 플레이어의 로그 리스트 반환
  List<String> getLogs(String playerKey) {
    return _logs[playerKey] ?? [];
  }

  /// 게임 재시작 시 로그 초기화
  void clearLogs() {
    _logs.forEach((key, value) => value.clear());
    _currentTurnBuffer = "";
  }
}
