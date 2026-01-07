import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chance_card.dart';

class ChanceCardRepository {
  static List<ChanceCard>? _cachedCards; // 💡 카드 리스트 캐싱용

  static Future<ChanceCard> fetchRandom({required bool quizCorrect}) async {
    // 💡 캐시가 비어있을 때만 Firestore에서 로드
    if (_cachedCards == null) {
      final doc = await FirebaseFirestore.instance
          .collection('meta_data')
          .doc('card_list')
          .get();

      final data = doc.data();
      if (data == null || data.isEmpty) {
        throw Exception('card_list document is empty');
      }

      _cachedCards = data.values
          .map((e) => ChanceCard.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    final allCards = _cachedCards!;
    
    // 타입별 분리
    final benefitCards = allCards.where((c) => c.type == 'benefit').toList();
    final harmCards = allCards.where((c) => c.type == 'harm').toList();

    final rand = Random().nextInt(100);

    // 퀴즈 정답이면 70 / 30
    if (quizCorrect) {
      if (rand < 70 && benefitCards.isNotEmpty) {
        return benefitCards[Random().nextInt(benefitCards.length)];
      } else if (harmCards.isNotEmpty) {
        return harmCards[Random().nextInt(harmCards.length)];
      }
    }

    // 오답이면 전체 랜덤
    return allCards[Random().nextInt(allCards.length)];
  }
}
