import 'dart:typed_data';

class EmlParseOptions {
  final bool headersOnly;

  const EmlParseOptions({
    this.headersOnly = false,
  });

  @override
  String toString() {
    return 'EmlParseOptions{headersOnly: $headersOnly}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EmlParseOptions && other.headersOnly == headersOnly;
  }

  @override
  int get hashCode => headersOnly.hashCode;
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

  @override
  String toString() {
    return '$name $contentType ${data.length} ${data64.substring(0, 32)}...';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EmlEmailAttachment &&
        other.id == id &&
        other.name == name &&
        other.contentType == contentType &&
        other.inline == inline &&
        other.data == data &&
        other.data64 == data64;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        contentType.hashCode ^
        inline.hashCode ^
        data.hashCode ^
        data64.hashCode;
  }
}

class EmlEmailAddress {
  final String name;
  final String email;

  EmlEmailAddress({
    required this.name,
    required this.email,
  });

  @override
  String toString() {
    return '$name <$email>';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EmlEmailAddress &&
        other.name == name &&
        other.email == email;
  }

  @override
  int get hashCode => name.hashCode ^ email.hashCode;
}

class EmlEmailHeader {
  final String name;
  final String value;

  EmlEmailHeader({
    required this.name,
    required this.value,
  });

  @override
  String toString() {
    return '$name: $value';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EmlEmailHeader &&
        other.name == name &&
        other.value == value;
  }

  @override
  int get hashCode => name.hashCode ^ value.hashCode;
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

  @override
  String toString() {
    return 'EmlParseResult:\ndate: $date\nsubject: $subject\nfrom: $from\nto: $to cc: $cc \nheaders:\n\t${headers?.join('\n\t')}\n\ntext:\n$text\n\ntextheaders:\n\t${textheaders?.join('\n\t')}\n\nhtml:\n$html\n\nhtmlheaders:\n\t${htmlheaders?.join('\n\t')}\nattachments:\n\t${attachments?.join('\n\t')}';
  }
}
