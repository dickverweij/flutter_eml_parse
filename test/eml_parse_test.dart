import 'dart:convert';
import 'dart:io';

import 'package:flutter_eml_parse/flutter_eml_parse.dart';
import 'package:flutter_test/flutter_test.dart';

Future main() async {
  String eml = await File('test/sample with pdf.eml').readAsString();
  String pdfBase64 = base64Encode(await File('test/sample.pdf').readAsBytes());

  EmlParseResult result = await parseEml(eml);

  test('From', () {
    print("Testing Eml parse result\n\n$result");

    expect(result.from?.first, EmlEmailAddress(name: 'DickyDick', email: ''));
    expect(
        result.attachments
            ?.where((attachment) => attachment.name == "sample.pdf")
            .first
            .data64,
        pdfBase64);
  });
}
