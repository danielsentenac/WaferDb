import 'package:flutter_test/flutter_test.dart';
import 'package:waferdb_app/linkified_text.dart';

void main() {
  test('parseLinkifiedText keeps plain text untouched', () {
    final segments = parseLinkifiedText('No links here.');

    expect(segments, hasLength(1));
    expect(segments.single.text, 'No links here.');
    expect(segments.single.isLink, isFalse);
  });

  test('parseLinkifiedText extracts clickable http and https urls', () {
    final segments = parseLinkifiedText(
      'Docs: https://example.com/a and http://example.org/b',
    );

    expect(segments, hasLength(4));
    expect(segments[0].text, 'Docs: ');
    expect(segments[0].isLink, isFalse);
    expect(segments[1].text, 'https://example.com/a');
    expect(segments[1].url, 'https://example.com/a');
    expect(segments[2].text, ' and ');
    expect(segments[2].isLink, isFalse);
    expect(segments[3].text, 'http://example.org/b');
    expect(segments[3].url, 'http://example.org/b');
  });

  test('parseLinkifiedText keeps trailing punctuation outside urls', () {
    final segments = parseLinkifiedText(
      'See https://example.com/test., then continue.',
    );

    expect(segments, hasLength(3));
    expect(segments[0].text, 'See ');
    expect(segments[1].text, 'https://example.com/test');
    expect(segments[1].url, 'https://example.com/test');
    expect(segments[2].text, '., then continue.');
    expect(segments[2].isLink, isFalse);
  });
}
