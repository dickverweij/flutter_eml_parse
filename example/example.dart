import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_eml_parse/src/data_classes.dart';
import 'package:flutter_eml_parse/src/parser.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: FutureBuilder<EmlParseResult>(
              future: _readEml(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Column(
                    children: <Widget>[
                      Text('From: ${snapshot.data!.from}'),
                      Text('To: ${snapshot.data!.to}'),
                      Text('Subject: ${snapshot.data!.subject}'),
                      Text('Text: ${snapshot.data!.text}'),
                      Text('Html: ${snapshot.data!.html}'),
                    ], // children
                  );
                } else {
                  return const CircularProgressIndicator();
                }
              }),
        ));
  }

  Future<EmlParseResult>? _readEml() async {
    String eml = await File('./sample.eml').readAsString();

    EmlParseResult result = await parseEml(eml);

    print('From: ${result.from}');
    print('To: ${result.to}');
    print('Subject: ${result.subject}');
    print('Text: ${result.text}');
    print('Html: ${result.html}');

    if (result.attachments != null && result.attachments!.isNotEmpty) {
      for (EmlEmailAttachment attachment in result.attachments!) {
        print(
            'Attachment: ${attachment.name} ${attachment.contentType} ${attachment.data.length}');
      }
    }

    if (result.headers != null && result.headers!.isNotEmpty) {
      for (EmlEmailHeader header in result.headers!) {
        print('${header.name}: ${header.value}');
      }
    }
    return result;
  }
}
