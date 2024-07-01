import 'dart:io';

import 'package:flutter_eml_parse/flutter_eml_parse.dart';
import 'package:flutter_test/flutter_test.dart';

Future main() async {
  String eml = await File('test/test.eml').readAsString();

  EmlParseResult result = await parseEml(eml);

  expect(result.from, '');
  expect(result.to, '');
  expect(result.subject, '');


}
