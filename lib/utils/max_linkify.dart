import 'package:flutter_linkify/flutter_linkify.dart';

class MaxSchemeLinkifier extends Linkifier {
  const MaxSchemeLinkifier();

  static final RegExp _regex = RegExp(
    r'(max://max\.ru/[^\s<>()]+)',
    caseSensitive: false,
  );

  @override
  List<LinkifyElement> parse(
    List<LinkifyElement> elements,
    LinkifyOptions options,
  ) {
    final List<LinkifyElement> list = [];

    for (final element in elements) {
      if (element is TextElement) {
        final text = element.text;
        final matches = _regex.allMatches(text);

        if (matches.isEmpty) {
          list.add(element);
          continue;
        }

        var lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            list.add(TextElement(text.substring(lastIndex, match.start)));
          }

          final url = text.substring(match.start, match.end);
          list.add(LinkableElement(url, url));
          lastIndex = match.end;
        }

        if (lastIndex < text.length) {
          list.add(TextElement(text.substring(lastIndex)));
        }
      } else {
        list.add(element);
      }
    }

    return list;
  }
}

