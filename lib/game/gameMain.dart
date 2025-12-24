import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class GameMain extends StatefulWidget {
  const GameMain({super.key});

  @override
  State<GameMain> createState() => _GameMainState();
}

class _GameMainState extends State<GameMain> {
  FirebaseFirestore fs = FirebaseFirestore.instance;
  String localName = "";
  int localcode = 0;
  List<Map<String, String>> heritageList = [];
  List<Map<String, dynamic>> localList = [
    {'인천': {'ccbaCtcd': 23}},{'세종': {'ccbaCtcd': 45}},{'울산': {'ccbaCtcd': 26}},
    {'제주': {'ccbaCtcd': 50}},{'대구': {'ccbaCtcd': 22}},{'충북': {'ccbaCtcd': 33}},
    {'대전': {'ccbaCtcd': 25}},{'전북': {'ccbaCtcd': 35}},{'강원': {'ccbaCtcd': 32}},
    {'부산': {'ccbaCtcd': 21}},{'충남': {'ccbaCtcd': 35}},{'경기': {'ccbaCtcd': 31}},
    {'경남': {'ccbaCtcd': 38}},{'전남': {'ccbaCtcd': 36}},{'경북': {'ccbaCtcd': 37}},
    {'광주': {'ccbaCtcd': 24}},{'서울': {'ccbaCtcd': 11}}
  ];

  Future<void> _setLocal() async{
    int random = Random().nextInt(localList.length);
    setState(() {
      localName = localList[random].keys.first;
      localcode = localList[random][localName]['ccbaCtcd'];
    });
    var heritage = await _loadHeritage();
    setState(() {
      heritageList = heritage;
    });
    var detail = await _loadHeritageDetail();
    setState(() {
      heritageList = detail;
    });

    // await _insertLocal();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartDialog(localName);
    });
  }
  // ///////////////////// 이거 해야됨!!!!!!!!!!!!!!!!
  // Future<void> _insertLocal() async{
  //   for(int i = 1; i<=24; i++) {
  //     await fs.collection("games").doc("quiz").update({
  //       "q$i.name" : heritageList[i-1]["이름"],
  //       "q$i.description" : heritageList[i-1]["상세설명"],
  //       "q$i.times" : heritageList[i-1]["시대"],
  //       "q$i.img" : heritageList[i-1]["이미지링크"]
  //     });
  //   }
  //   int boardNum = 1;
  //   for(int i = 1; i<=24; i++) {
  //     await fs.collection("games").doc("board").update({
  //       "b$boardNum.name" : heritageList[i]["이름"]
  //     });
  //     if((boardNum+1) % 4 == 0){
  //       boardNum += 2;
  //     } else {
  //       boardNum += 1;
  //     }
  //   }
  // }
  
  
  // 문화재 상세정보 불러오는 함수
  Future<List<Map<String, String>>> _loadHeritageDetail() async{
    final detailList = heritageList.map((item) async{
      final String detailUrl =
          "https://www.khs.go.kr/cha/SearchKindOpenapiDt.do?ccbaKdcd=${item["종목코드"]}&ccbaAsno=${item["관리번호"]}&ccbaCtcd=${item["시도코드"]}";

      try {
        print(detailUrl);
        final res = await http.get(Uri.parse(detailUrl));
        if (res.statusCode == 200) {
          final doc = xml.XmlDocument.parse(res.body);
          final detailItem = doc.findAllElements('item').firstOrNull;
          // '상세설명' 키를 추가합니다.
          item['상세설명'] = detailItem != null ? getXmlText(detailItem, 'content') : "설명이 없습니다.";
          item['이미지링크'] = detailItem != null ? getXmlText(detailItem, 'imageUrl') : "이미지가 없습니다.";
          item['시대'] = detailItem != null ? getXmlText(detailItem, 'ccceName') : "시대가 없습니다.";
        } else {
          item['상세설명'] = "상세 정보를 불러오지 못했습니다.";
          item['이미지링크'] = "상세 정보를 불러오지 못했습니다.";
          item['시대'] = "상세 정보를 불러오지 못했습니다.";
        }
      } catch (e) {
        item['상세설명'] = "에러 발생";
        item['이미지링크'] = "에러 발생";
        item['시대'] = "에러 발생";
      }
      return item;
    });

    return await Future.wait(detailList);
  }

  // xml 변환 함수
  String getXmlText(xml.XmlElement parent, String tagName) {
    final elements = parent.findElements(tagName);
    return elements.isNotEmpty ? elements.first.innerText.trim() : "";
  }

  // 문화재 리스트 불러오는 함수
  Future<List<Map<String, String>>> _loadHeritage() async {
    final String url =
        "https://www.khs.go.kr/cha/SearchKindOpenapiList.do?ccbaCtcd=$localcode&pageIndex=1&pageUnit=24";

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

  void _showStartDialog(String localName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Future.delayed(const Duration(seconds: 3), () {
          // 3초 뒤에 다이얼로그가 여전히 화면에 있는지 확인(mounted) 후 닫기
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        });
        return AlertDialog(
          title: const Text("게임 시작" ,textAlign: TextAlign.center),
          content: SizedBox(
            width: double.infinity * 0.5,
            child: Text("이번 문화재 보유 지역은\n'$localName' 입니다!", textAlign: TextAlign.center,)
          ),
        );
      },
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _setLocal();
  }

  @override
  Widget build(BuildContext context) {
    // 1. 화면의 높이를 기준으로 정사각형 크기 설정 (가로 모드 가정)
    final double screenHeight = MediaQuery.of(context).size.height;
    final double boardSize = screenHeight;
    final double tileSize = boardSize / 9;

    return Scaffold(
      backgroundColor: Colors.grey[900], // 배경을 어둡게 해서 보드가 돋보이게 함 (원하는대로 변경 가능)
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // [배경 이미지]
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/board-background.PNG'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // [보드판 영역]
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: Stack(
                children: [
                  // 중앙 영역 (투명한 흰색 박스로 살짝 구분감을 줌 - 선택사항)
                  Center(
                    child: Container(
                      width: boardSize * 0.75,
                      height: boardSize * 0.75,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  // [0번 ~ 31번 타일 생성]
                  ...List.generate(32, (index) {
                    return _buildGameTile(index, tileSize);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🟦 타일 디자인 함수
  Widget _buildGameTile(int index, double size) {
    // 위치 변수
    double? top, bottom, left, right;

    // 📍 위치 계산 로직 (기존 유지)
    if (index >= 0 && index <= 8) { // 하단
      bottom = 0;
      right = index * size;
    } else if (index >= 9 && index <= 16) { // 좌측
      left = 0;
      bottom = (index - 8) * size;
    } else if (index >= 17 && index <= 24) { // 상단
      top = 0;
      left = (index - 16) * size;
    } else if (index >= 25 && index <= 31) { // 우측
      right = 0;
      top = (index - 24) * size;
    }

    // 🎨 디자인 설정
    Color barColor = Colors.grey; // 상단 컬러띠 색상
    IconData? icon; // 특수 블록 아이콘
    String label = "";
    bool isSpecial = false; // 특수 블록 여부

    // 특수 블록 설정
    if (index == 0) {
      label = "출발";
      icon = Icons.flag_circle;
      barColor = Colors.white; // 출발지는 전체가 흰색이거나 디자인 다르게
      isSpecial = true;
    }
    else if (index == 8) { label = "무인도"; icon = Icons.lock_clock; isSpecial = true; }
    else if (index == 16) { label = "축제"; icon = Icons.celebration; isSpecial = true; }
    else if (index == 24) { label = "여행"; icon = Icons.flight_takeoff; isSpecial = true; }
    else if (index == 30) { label = "국세청"; icon = Icons.account_balance; isSpecial = true; }
    else if ([4, 12, 20, 28].contains(index)) {
      label = "찬스";
      icon = Icons.question_mark_rounded;
      barColor = Colors.orange; // 찬스는 주황색 테마
      isSpecial = true;
    }
    // 일반 땅 컬러 설정 (라인별 테마)
    else if (index < 4) { barColor = const Color(0xFFCFFFE5); }   // 민트
    else if (index < 8) { barColor = const Color(0xFF66BB6A); }  // 초록
    else if (index < 12) { barColor = const Color(0xFF42A5F5); }  // 파랑
    else if (index < 16) { barColor = const Color(0xFFAB47BC); }  // 보라
    else if (index < 20) { barColor = const Color(0xFFFFEB00); } // 노랑
    else if (index < 24) { barColor = const Color(0xFF808080); } // 회색
    else if (index < 28) { barColor = const Color(0xFFFF69B4); } // 분홍
    else { barColor = const Color(0xFFEF5350); }                  // 빨강

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        // 타일 간의 간격을 주기 위해 margin 추가
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.0), // 둥근 모서리
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3,
                offset: const Offset(1, 2),
              ),
            ],
            border: Border.all(color: Colors.grey.shade400, width: 0.5),
          ),
          child: isSpecial
              ? _buildSpecialContent(label, icon!, index == 0) // 특수 블록 디자인
              : _buildLandContent(barColor, index),           // 일반 땅 디자인
        ),
      ),
    );
  }

  // 🏗️ 일반 땅 내부 디자인 (컬러띠 + 내용)
  Widget _buildLandContent(Color color, int index) {
    return Column(
      children: [
        // 상단 컬러 띠
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6.0),
                topRight: Radius.circular(6.0),
              ),
            ),
          ),
        ),
        // 하단 내용 (이름, 가격 등)
        Expanded(
          flex: 5,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 임시 지역명 (나중에 DB 데이터로 교체)
                Text(
                  "지역 $index",
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "100만",
                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✨ 특수 블록 내부 디자인 (아이콘 + 텍스트)
  Widget _buildSpecialContent(String label, IconData icon, bool isStart) {
    return Container(
      decoration: BoxDecoration(
        color: isStart ? Colors.white : Colors.grey[100], // 출발지만 흰색, 나머진 연회색
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


}