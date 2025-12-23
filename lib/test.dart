import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.brown, useMaterial3: true),
      home: const HeritageMainPage(),
    );
  }
}

class HeritageMainPage extends StatefulWidget {
  const HeritageMainPage({super.key});

  @override
  State<HeritageMainPage> createState() => _HeritageMainPageState();
}

class _HeritageMainPageState extends State<HeritageMainPage> {
  List<Map<String, String>> heritageList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  String getXmlText(xml.XmlElement parent, String tagName) {
    final elements = parent.findElements(tagName);
    return elements.isNotEmpty ? elements.first.innerText.trim() : "";
  }

  // 여러 페이지를 호출하여 24개를 맞추는 함수
  Future<void> fetchAllData() async {
    setState(() => isLoading = true);

    try {
      // 10개씩 3번 호출 (1~10, 11~20, 21~30) 하여 24개 이상 확보
      final results = await Future.wait([
        fetchSinglePage(1)
      ]);
      print(results);
      // 리스트 합치기
      List<Map<String, String>> combined = results.expand((x) => x).toList();
      print(combined);
      setState(() {
        // 정확히 24개만 슬라이스
        heritageList = combined;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  // 특정 페이지의 데이터를 가져오는 단위 함수
  Future<List<Map<String, String>>> fetchSinglePage(int pageIndex) async {
    final String url =
        "https://www.khs.go.kr/cha/SearchKindOpenapiList.do?ccbaCtcd=11&pageIndex=$pageIndex&pageUnit=24";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final document = xml.XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      return items.map((node) => {
        'name': getXmlText(node, 'ccbaMnm1'),
        'kdcd': getXmlText(node, 'ccbaKdcd'),
        'asno': getXmlText(node, 'ccbaAsno'),
        'ctcd': getXmlText(node, 'ccbaCtcd'),
        'ccsi': getXmlText(node, 'ccsiName'),
        'img': getXmlText(node, 'imageUrl'),
      }).toList();
    }
    return [];
  }

  // 상세 설명 조회
  Future<String> fetchDescription(String kdcd, String asno, String ctcd) async {
    final String detailUrl =
        "https://www.khs.go.kr/cha/SearchKindOpenapiDt.do?ccbaKdcd=$kdcd&ccbaAsno=$asno&ccbaCtcd=$ctcd";

    final response = await http.get(Uri.parse(detailUrl));
    if (response.statusCode == 200) {
      final document = xml.XmlDocument.parse(response.body);
      final item = document.findAllElements('item').firstOrNull;
      print(item);
      return item != null ? getXmlText(item, 'content') : "설명이 없습니다.";
    }
    return "에러 발생";
  }

  void showDetailDialog(Map<String, String> item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String description = await fetchDescription(item['kdcd']!, item['asno']!, item['ctcd']!);
    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name']!),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Text(description)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("닫기"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('국가유산 목록 (24개)')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: heritageList.length,
        itemBuilder: (context, index) {
          final item = heritageList[index];
          return ListTile(
            leading: Text("${index + 1}"),
            title: Text(item['name']!),
            subtitle: const Text("상세보기"),
            onTap: () => showDetailDialog(item),
          );
        },
      ),
    );
  }
}