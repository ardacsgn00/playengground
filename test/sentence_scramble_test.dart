import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/data/sentence_scramble_data.dart';

String clean(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\w\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

void main() {
  group('Sentence Scramble Pool Integrity', () {
    test('every question scrambled tiles match correct sentence', () {
      for (int i = 0; i < sentenceScramblePool.length; i++) {
        final item = sentenceScramblePool[i];
        final correct = item['correct'] as String;
        final scrambled = (item['scrambled'] as List<dynamic>).cast<String>();

        final cWords = clean(correct).split(' ')..sort();
        final sWords = scrambled.map(clean).toList()..sort();

        expect(
          sWords.join(' '),
          equals(cWords.join(' ')),
          reason: 'Item $i ("$correct") has scrambled tiles that do not match correct words',
        );
      }
    });

    test('every alternative answer matches scrambled tiles exactly', () {
      for (int i = 0; i < sentenceScramblePool.length; i++) {
        final item = sentenceScramblePool[i];
        final alts = (item['alternatives'] as List<dynamic>?)?.cast<String>() ?? [];
        final scrambled = (item['scrambled'] as List<dynamic>).cast<String>();
        final sWords = scrambled.map(clean).toList()..sort();

        for (final alt in alts) {
          final altWords = clean(alt).split(' ')..sort();
          expect(
            altWords.join(' '),
            equals(sWords.join(' ')),
            reason: 'Item $i alt "$alt" does not match scrambled tiles',
          );
        }
      }
    });
  });
}

