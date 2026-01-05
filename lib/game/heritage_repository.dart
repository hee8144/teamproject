import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:cloud_firestore/cloud_firestore.dart';

class HeritageRepository {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// 1. 지역별 문화재 리스트 가져오기 (API)
  Future<List<Map<String, String>>> loadHeritage(int localCode, String localName) async {
    final String url = "https://www.khs.go.kr/cha/SearchKindOpenapiList.do?ccbaCtcd=$localCode&pageIndex=1&pageUnit=40";
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        List<Map<String, String>> resultList = [];
        Set<String> duplicateCheckSet = {};

        for (var node in items) {
          if (resultList.length >= 24) break;

          String rawName = _getXmlText(node, 'ccbaMnm1');
          String ccsiName = _getXmlText(node, 'ccsiName');

          // 지역명 제거 로직
          String cleanName = rawName.replaceAll(localName, "").trim();
          cleanName = cleanName.replaceAll(ccsiName, "").trim();
          String simpleCcsi = ccsiName.replaceAll(RegExp(r'(시|군|구)$'), "");
          if (simpleCcsi.length >= 2) {
            cleanName = cleanName.replaceAll(simpleCcsi, "").trim();
          }
          cleanName = cleanName.replaceAll(RegExp(r'^[\(\)\s\-\_\.\,]+'), "").trim();
          if (cleanName.isEmpty) cleanName = rawName;

          // 중복 필터링
          String baseName = cleanName.replaceAll(RegExp(r'\(.*\)|\d+|[-_]'), "").trim();
          if (baseName.isEmpty) baseName = cleanName;

          if (duplicateCheckSet.contains(baseName)) continue;

          duplicateCheckSet.add(baseName);
          resultList.add({
            '이름': cleanName,
            '원래이름': rawName,
            '종목코드': _getXmlText(node, 'ccbaKdcd'),
            '관리번호': _getXmlText(node, 'ccbaAsno'),
            '시도코드': _getXmlText(node, 'ccbaCtcd'),
            '시군구명': ccsiName,
          });
        }
        return resultList;
      }
    } catch (e) {
      print("문화재 리스트 로딩 에러: $e");
    }
    return [];
  }

  /// 2. 문화재 상세 정보(설명, 이미지) 가져오기 (API)
  Future<List<Map<String, String>>> loadHeritageDetail(List<Map<String, String>> list) async {
    final detailList = list.map((item) async {
      final String detailUrl =
          "https://www.khs.go.kr/cha/SearchKindOpenapiDt.do?ccbaKdcd=${item["종목코드"]}&ccbaAsno=${item["관리번호"]}&ccbaCtcd=${item["시도코드"]}";
      try {
        final res = await http.get(Uri.parse(detailUrl));
        if (res.statusCode == 200) {
          final doc = xml.XmlDocument.parse(res.body);
          final detailItem = doc.findAllElements('item').firstOrNull;
          item['상세설명'] = detailItem != null ? _getXmlText(detailItem, 'content') : "설명 없음";
          item['이미지링크'] = detailItem != null ? _getXmlText(detailItem, 'imageUrl') : "이미지 없음";
          item['시대'] = detailItem != null ? _getXmlText(detailItem, 'ccceName') : "시대 없음";
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

  /// 3. 게임 데이터(퀴즈, 보드)에 문화재 정보 주입하기 (Firebase)
  Future<void> updateGameDataWithHeritage(List<Map<String, String>> heritageList) async {
    if (heritageList.isEmpty) return;

    // 1) 퀴즈 데이터 업데이트
    WriteBatch batch = _fs.batch();

    for (int i = 1; i <= 24; i++) {
      if (i - 1 < heritageList.length) {
        var item = heritageList[i - 1];
        batch.update(_fs.collection("games").doc("quiz"), {
          "q$i.name": item["이름"],
          "q$i.fullName": item["원래이름"],
          "q$i.description": item["상세설명"],
          "q$i.times": item["시대"],
          "q$i.img": item["이미지링크"]
        });
      }
    }
    await batch.commit(); // 퀴즈 일괄 업데이트

    // 2) 보드 데이터 업데이트 (이름 변경)
    DocumentSnapshot boardSnap = await _fs.collection("games").doc("board").get();
    if (boardSnap.exists) {
      Map<String, dynamic> boardData = boardSnap.data() as Map<String, dynamic>;
      Map<String, dynamic> updates = {};
      int heritageIndex = 0;

      for (int i = 1; i <= 27; i++) {
        String key = "b$i";
        // 땅(land) 타입인 경우에만 이름 교체
        if (boardData[key] != null && boardData[key]['type'] == 'land') {
          if (heritageIndex < heritageList.length) {
            updates["$key.name"] = heritageList[heritageIndex]["이름"];
            updates["$key.fullName"] = heritageList[heritageIndex]["원래이름"];
            heritageIndex++;
          }
        }
      }
      if (updates.isNotEmpty) {
        await _fs.collection("games").doc("board").update(updates);
      }
    }
  }

  // XML 파싱 헬퍼
  String _getXmlText(xml.XmlElement parent, String tagName) {
    final elements = parent.findElements(tagName);
    return elements.isNotEmpty ? elements.first.innerText.trim() : "";
  }
}