import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'url_opener.dart';

final RegExp _urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
const String _trailingLinkPunctuation = '.,;:!?)]}';

@immutable
class LinkifiedSegment {
  const LinkifiedSegment({required this.text, this.url});

  final String text;
  final String? url;

  bool get isLink => url != null;
}

List<LinkifiedSegment> parseLinkifiedText(String text) {
  if (text.isEmpty) return const [];

  final segments = <LinkifiedSegment>[];
  var cursor = 0;

  for (final match in _urlPattern.allMatches(text)) {
    if (match.start > cursor) {
      _appendPlainText(segments, text.substring(cursor, match.start));
    }

    final rawMatch = match.group(0)!;
    final normalized = _normalizeUrlMatch(rawMatch);
    if (normalized.url.isNotEmpty) {
      segments.add(LinkifiedSegment(text: normalized.url, url: normalized.url));
    }
    if (normalized.trailingText.isNotEmpty) {
      _appendPlainText(segments, normalized.trailingText);
    }

    cursor = match.end;
  }

  if (cursor < text.length) {
    _appendPlainText(segments, text.substring(cursor));
  }

  return segments;
}

class LinkifiedText extends StatefulWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.linkStyle,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextStyle? linkStyle;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final baseStyle = DefaultTextStyle.of(context).style.merge(widget.style);
    final linkStyle = baseStyle
        .copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        )
        .merge(widget.linkStyle);

    final spans = parseLinkifiedText(widget.text)
        .map((segment) {
          if (!segment.isLink) {
            return TextSpan(text: segment.text);
          }

          final recognizer = TapGestureRecognizer()
            ..onTap = () => _openUrl(segment.url!);
          _recognizers.add(recognizer);
          return TextSpan(
            text: _breakableUrl(segment.text),
            style: linkStyle,
            recognizer: recognizer,
            mouseCursor: SystemMouseCursors.click,
          );
        })
        .toList(growable: false);

    return RichText(
      textAlign: widget.textAlign ?? TextAlign.start,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  Future<void> _openUrl(String url) async {
    final opened = await openExternalUrl(url);
    if (!mounted || opened) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text('Could not open $url')));
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

_NormalizedUrl _normalizeUrlMatch(String rawMatch) {
  var end = rawMatch.length;
  while (end > 0 && _trailingLinkPunctuation.contains(rawMatch[end - 1])) {
    end -= 1;
  }
  return _NormalizedUrl(
    url: rawMatch.substring(0, end),
    trailingText: rawMatch.substring(end),
  );
}

class _NormalizedUrl {
  const _NormalizedUrl({required this.url, required this.trailingText});

  final String url;
  final String trailingText;
}

String _breakableUrl(String url) =>
    url.replaceAllMapped(RegExp(r'([/?=&])'), (m) => '${m[1]}\u200B');

void _appendPlainText(List<LinkifiedSegment> segments, String text) {
  if (text.isEmpty) return;
  if (segments.isNotEmpty && !segments.last.isLink) {
    final previous = segments.removeLast();
    segments.add(LinkifiedSegment(text: previous.text + text));
    return;
  }
  segments.add(LinkifiedSegment(text: text));
}
