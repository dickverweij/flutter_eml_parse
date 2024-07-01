import 'dart:typed_data';

class EmlParseOptions {
  final bool headersOnly;

  const EmlParseOptions({
    this.headersOnly = false,
  });
}

class EmlEmailAttachment {
  final String id;
  final String name;
  final String contentType;
  final bool inline;
  final Uint8List data;
  final String data64;

  EmlEmailAttachment({
    required this.id,
    required this.name,
    required this.contentType,
    required this.inline,
    required this.data,
    required this.data64,
  });
}

class EmlEmailAddress {
  final String name;
  final String email;

  EmlEmailAddress({
    required this.name,
    required this.email,
  });
}

class EmlEmailHeader {
  final String name;
  final String value;

  EmlEmailHeader({
    required this.name,
    required this.value,
  });
}

class EmlParseResult {
  final DateTime date;
  final String subject;
  final List<EmlEmailAddress>? from;
  final List<EmlEmailAddress>? to;
  final List<EmlEmailAddress>? cc;
  final List<EmlEmailHeader>? headers;
  final String? text;
  final List<EmlEmailHeader>? textheaders;
  final String? html;
  final List<EmlEmailHeader>? htmlheaders;
  final List<EmlEmailAttachment>? attachments;

  EmlParseResult({
    required this.date,
    required this.subject,
    this.from,
    this.to,
    this.cc,
    this.headers,
    this.text,
    this.textheaders,
    this.html,
    this.htmlheaders,
    this.attachments,
  });
}
