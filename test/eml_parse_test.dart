import 'dart:io';

import 'package:flutter_eml_parse/flutter_eml_parse.dart';
import 'package:flutter_test/flutter_test.dart';

Future main() async {
  String eml = await File('test/test.eml').readAsString();

  EmlParseResult result = await parseEml(eml);

  print('From: ${result.from}');
  print('To: ${result.to}');
  print('Subject: ${result.subject}');
  print('Text: ${result.text}');
  print('Html: ${result.html}');

  if (result.attachments != null) {
    for (EmlEmailAttachment attachment in result.attachments!) {
      print('Attachment: ${attachment.name} (${attachment.contentType})');
    }
  }

  if (result.headers != null) {
    for (EmlEmailHeader header in result.headers!) {
      print('${header.name}: ${header.value}');
    }
  }
}
