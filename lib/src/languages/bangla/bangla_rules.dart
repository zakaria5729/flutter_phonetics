/// Author: Zakaria Hossain
/// Description: Phonetic substitution rules and sound-alike mappings for Bangla.
library;

import '../../core/phonetic_rule.dart';

// ড় and ঢ় are escaped because they look the same as ড + nukta and ঢ + nukta.
final List<PhoneticRule> banglaRules = [
  PhoneticRule(['স', 'শ', 'ষ'], 0.95),
  PhoneticRule(['ছ', 'স', 'শ'], 0.85),
  PhoneticRule(['ছ', 'ষ'], 0.80),
  PhoneticRule(['চ', 'ছ'], 0.85),
  PhoneticRule(['চ', 'স', 'শ', 'ষ'], 0.75),
  PhoneticRule(['ন', 'ণ'], 0.95),
  PhoneticRule(['ঞ', 'ন'], 0.80),
  PhoneticRule(['ং', 'ঙ'], 0.95),
  PhoneticRule(['জ', 'য'], 0.95),
  PhoneticRule(['জ', 'ঝ'], 0.80),
  PhoneticRule(['য', 'ঝ'], 0.75),
  PhoneticRule(['\u09DC', '\u09DD'], 0.90),
  PhoneticRule(['র', '\u09DC'], 0.85),
  PhoneticRule(['র', '\u09DD'], 0.80),
  PhoneticRule(['ৎ', 'ত'], 0.95),
  PhoneticRule(['ত', 'ট'], 0.75),
  PhoneticRule(['থ', 'ঠ'], 0.75),
  PhoneticRule(['দ', 'ড'], 0.75),
  PhoneticRule(['ধ', 'ঢ'], 0.75),
  PhoneticRule(['ক', 'খ'], 0.75),
  PhoneticRule(['গ', 'ঘ'], 0.75),
  PhoneticRule(['ট', 'ঠ'], 0.75),
  PhoneticRule(['ড', 'ঢ'], 0.75),
  PhoneticRule(['ত', 'থ'], 0.75),
  PhoneticRule(['দ', 'ধ'], 0.75),
  PhoneticRule(['প', 'ফ'], 0.75),
  PhoneticRule(['ব', 'ভ'], 0.75),
  PhoneticRule(['ক্ষ', 'খ'], 0.90),
  PhoneticRule(['জ্ঞ', 'গ্গ'], 0.85),
  PhoneticRule(['ই', 'ঈ'], 0.97),
  PhoneticRule(['উ', 'ঊ'], 0.97),
  PhoneticRule(['ঋ', 'রি'], 0.95),
  PhoneticRule(['ঐ', 'অই', 'ওই'], 0.90),
  PhoneticRule(['ঔ', 'অউ', 'ওউ'], 0.90),
  PhoneticRule(['অ', 'ও'], 0.80),
  PhoneticRule(['ি', 'ী'], 0.97),
  PhoneticRule(['ু', 'ূ'], 0.97),
  PhoneticRule(['ৃ', '্রি'], 0.95),
  PhoneticRule(['ৈ', 'োই'], 0.90),
  PhoneticRule(['ৌ', 'োউ'], 0.90),
  PhoneticRule(['ো', 'ু'], 0.80),
  PhoneticRule(['ঞ্জ', 'নজ'], 0.90),
  PhoneticRule(['ঞ্চ', 'নচ'], 0.90),
  for (final consonant in _consonantsThatTakeFinalO)
    PhoneticRule([consonant, '$consonant$_oKar'], 0.85,
        position: RulePosition.wordEnd),
  PhoneticRule(['ই', 'ি'], 0.90, scoreOnly: true),
  PhoneticRule(['ই', 'ী'], 0.90, scoreOnly: true),
  PhoneticRule(['উ', 'ু'], 0.90, scoreOnly: true),
  PhoneticRule(['উ', 'ূ'], 0.90, scoreOnly: true),
  PhoneticRule(['ও', 'ো'], 0.90, scoreOnly: true),
  PhoneticRule(['এ', 'ে'], 0.90, scoreOnly: true),
  PhoneticRule(['আ', 'া'], 0.90, scoreOnly: true),
  PhoneticRule(['ঐ', 'ৈ'], 0.90, scoreOnly: true),
  PhoneticRule(['ঔ', 'ৌ'], 0.90, scoreOnly: true),
  PhoneticRule(['ঋ', 'ৃ'], 0.90, scoreOnly: true),
];

final String _oKar = String.fromCharCode(0x09CB);

final List<String> _consonantsThatTakeFinalO = [
  ...'কখগঘঙচছজঝঞটঠডঢণতথদধনপফবভমযরলশষসহ'.split(''),
  String.fromCharCode(0x09DC),
  String.fromCharCode(0x09DD),
  String.fromCharCode(0x09DF),
];
