import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chance_card.dart';

class ChanceCardRepository {
  static Future<ChanceCard> fetchRandom({required bool quizCorrect}) async {
    final doc = await FirebaseFirestore.instance
        .collection('meta_data')
        .doc('card_list')
        .get();

    final data = doc.data();
    if (data == null || data.isEmpty) {
      throw Exception('card_list document is empty');
    }

    // 모든 카드 Map → ChanceCard 리스트로 변환
    final allCards = data.values
        .map((e) => ChanceCard.fromMap(e as Map<String, dynamic>))
        .toList();

    // 타입별 분리
    final benefitCards =
    allCards.where((c) => c.type == 'benefit').toList();
    final harmCards =
    allCards.where((c) => c.type == 'harm').toList();

    final rand = Random().nextInt(100);

    // 퀴즈 정답이면 70 / 30
    if (quizCorrect) {
      if (rand < 70 && benefitCards.isNotEmpty) {
        return benefitCards[Random().nextInt(benefitCards.length)];
      } else {
        return harmCards[Random().nextInt(harmCards.length)];
      }
    }

    // 오답이면 전체 랜덤
    return allCards[Random().nextInt(allCards.length)];
  }
}
