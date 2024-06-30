import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

Future<Uint8List> encode(String str, [String fromCharset = 'utf-8']) async {
  try {
    await CharsetConverter.encode(fromCharset, str);
  } catch (e) {
    // do nothing
  }

  return utf8.encode(str);
}

String arr2str(Uint8List bytes) {
  const chunkSz = 0x8000;

  final strs = <String>[];

  for (var i = 0; i < bytes.length; i += chunkSz) {
    strs.add(
        String.fromCharCodes(bytes.sublist(i, min(bytes.length, i + chunkSz))));
  }

  return strs.join('');
}

Future<String> decode(Uint8List buf, [String? fromCharset = 'utf-8']) async {
  List<String> charsets = [
    normalizeCharset(fromCharset),
    'utf-8',
    'iso-8859-15'
  ];

  for (var charset in charsets) {
    try {
      return await CharsetConverter.decode(charset, buf);
      // eslint-disable-next-line no-empty
    } catch (e) {}
  }

  return arr2str(buf); // all else fails, treat it as binary
}

Future<Uint8List> convert(dynamic data,
        [String? fromCharset = 'utf-8']) async =>
    data is String
        ? await encode(data)
        : await encode(await decode(data, fromCharset));

String normalizeCharset([String? charset = 'utf-8']) {
  RegExpMatch? match;

  if ((match = RegExp("^utf[-_]?(\\d+)\$", caseSensitive: false)
          .firstMatch(charset!)) !=
      null) {
    return 'UTF-${match!.group(1) ?? ''}';
  }

  if ((match = RegExp("^win[-_]?(\\d+)\$", caseSensitive: false)
          .firstMatch(charset)) !=
      null) {
    return 'WINDOWS-${match!.group(1) ?? ''}';
  }

  if ((match = RegExp("^latin[-_]?(\\d+)\$", caseSensitive: false)
          .firstMatch(charset)) !=
      null) {
    return 'ISO-8859-${match!.group(1) ?? ''}';
  }

  return charset;
}
