import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/models/navigation_assist_text.dart';
import 'package:orbit/models/orbit_feature_text.dart';

void main() {
  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  const hans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  group('isTraditionalChinese', () {
    test('honours the explicit script', () {
      expect(isTraditionalChinese(hant), isTrue);
      expect(isTraditionalChinese(hans), isFalse);
    });

    test('falls back to the region when the script is missing', () {
      expect(isTraditionalChinese(const Locale('zh', 'TW')), isTrue);
      expect(isTraditionalChinese(const Locale('zh', 'HK')), isTrue);
      expect(isTraditionalChinese(const Locale('zh', 'MO')), isTrue);
      expect(isTraditionalChinese(const Locale('zh', 'CN')), isFalse);
      expect(isTraditionalChinese(const Locale('zh')), isFalse);
    });

    test('only Chinese locales qualify', () {
      expect(isTraditionalChinese(const Locale('en')), isFalse);
      expect(isTraditionalChinese(const Locale('ja', 'JP')), isFalse);
    });
  });

  group('pickLocalized', () {
    test('returns English outside Chinese', () {
      expect(
        pickLocalized(const Locale('en'), 'Archive', '归档', '歸檔'),
        'Archive',
      );
    });

    test('returns the matching Chinese variant', () {
      expect(pickLocalized(hant, 'Archive', '归档', '歸檔'), '歸檔');
      expect(pickLocalized(hans, 'Archive', '归档', '歸檔'), '归档');
      expect(
        pickLocalized(const Locale('zh', 'TW'), 'Archive', '归档', '歸檔'),
        '歸檔',
      );
    });
  });

  group('feature copy agrees on the script', () {
    test('every picker resolves zh-HK as traditional', () {
      const hk = Locale('zh', 'HK');
      const en = 'Archive';
      const simplified = '归档';
      const traditional = '歸檔';

      expect(
        OrbitFeatureText(hk).pick(en, simplified, traditional),
        traditional,
      );
      expect(DeadlineText(hk).pick(en, simplified, traditional), traditional);
      expect(
        NavigationAssistText(hk).pick(en, simplified, traditional),
        traditional,
      );
    });

    test('a bare zh locale resolves as simplified everywhere', () {
      const bare = Locale('zh');
      const en = 'Archive';
      const simplified = '归档';
      const traditional = '歸檔';

      expect(
        OrbitFeatureText(bare).pick(en, simplified, traditional),
        simplified,
      );
      expect(DeadlineText(bare).pick(en, simplified, traditional), simplified);
      expect(
        NavigationAssistText(bare).pick(en, simplified, traditional),
        simplified,
      );
    });
  });
}
