library eml_parse;

import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'address.dart';
import 'charset.dart';
import 'data_classes.dart';
import 'utils.dart';

const defaultCharset = 'utf-8';

Future<EmlParseResult> parseEml(String eml,
    {EmlParseOptions options = const EmlParseOptions()}) async {
  final map = await _read(_parse(eml, options));
  return EmlParseResult(
    date: map['date'] as DateTime,
    subject: map['subject'] as String? ?? "",
    from: _createEmailAddresses(map["from"]),
    to: _createEmailAddresses(map["to"]),
    cc: _createEmailAddresses(map["cc"]),
    headers: toEmailHeaders(map['headers'] as Map<String, dynamic>?),
    text: map['text'],
    textheaders: toEmailHeaders(map['textheaders'] as Map<String, dynamic>?),
    html: map['html'] ?? "",
    htmlheaders: toEmailHeaders(map['htmlheaders'] as Map<String, dynamic>?),
    attachments: (map['attachments'] as List?)
        ?.map((attachment) => EmlEmailAttachment(
              id: attachment['id'],
              name: attachment['name'],
              contentType: attachment['contentType'],
              inline: attachment['inline'],
              data: attachment['data'],
              data64: attachment['data64'],
            ))
        .toList(),
  );
}

toEmailHeaders(Map<String, dynamic>? map) {
  if (map == null) {
    return null;
  }
  return map.entries
      .map((entry) => EmlEmailHeader(
          name: entry.key,
          value: entry.value is List
              ? entry.value.join('\r\n')
              : entry.value.toString()))
      .toList();
}

List<EmlEmailAddress>? _createEmailAddresses(dynamic mapOrList) {
  if (mapOrList == null ||
      (mapOrList is Map &&
          mapOrList["name"] == null &&
          mapOrList["email"] == null) ||
      (mapOrList is List && mapOrList.isEmpty)) {
    return null;
  }
  if (mapOrList is! Map) {
    final list = mapOrList
        .map((emailMap) => EmlEmailAddress(
              name: emailMap["name"] ?? '',
              email: emailMap["email"] ?? "",
            ))
        .cast<EmlEmailAddress>();
    return list.toList();
  }
  return [
    EmlEmailAddress(
      name: mapOrList['name'] ?? '',
      email: mapOrList['email'] ?? "",
    )
  ];
}

Map<String, dynamic> _parse(
  String eml,
  EmlParseOptions options,
) {
  Map<String, dynamic> result = {};
  final lines = eml.split(RegExp("\\r?\\n"));

  result = _parseRecursive(
    lines,
    0,
    result,
    options,
  );
  return result;
}

Map<String, dynamic> _parseRecursive(List<String> lines, int start,
    Map<String, dynamic> parent, EmlParseOptions options) {
  complete(Map<String, dynamic> boundary) {
    boundary['part'] = <String, dynamic>{};
    _parseRecursive(boundary['lines'] as List<String>, 0,
        boundary['part'] as Map<String, dynamic>, options);
    boundary.remove('lines');
  }

  Map<String, dynamic>? boundary;

  String lastHeaderName = '';
  String findBoundary = '';
  bool insideBody = false;
  bool insideBoundary = false;
  bool isMultiHeader = false;
  bool isMultipart = false;
  bool checkedForCt = false;
  bool ctInBody = false;

  parent['headers'] = <String, dynamic>{};

  //Read line by line
  for (int i = start; i < lines.length; i++) {
    final line = lines[i];

    //Header
    if (!insideBody) {
      //Search for empty line
      if (line == '') {
        insideBody = true;

        if (options.headersOnly) {
          break;
        }

        //Expected boundary
        String? ct = parent['headers']['Content-Type'] ??
            parent['headers']['Content-type'];
        if (ct == null) {
          if (checkedForCt) {
            insideBody = !ctInBody;
          } else {
            checkedForCt = true;
            final lineClone = lines.toList();
            final string = slice(lineClone, i).join('\r\n');
            final trimmedString = string.trim();
            if (trimmedString.indexOf('Content-Type') == 0 ||
                trimmedString.indexOf('Content-type') == 0) {
              insideBody = false;
              ctInBody = true;
            }
          }
        } else if (RegExp("^multipart/").hasMatch(ct)) {
          final b = getBoundary(ct);
          if (b?.isNotEmpty == true) {
            findBoundary = b!;
            isMultipart = true;
            parent['body'] = [];
          }
        }

        continue;
      }

      //Header value with new line
      var match = RegExp("^\\s+([^\\r\\n]+)", multiLine: true).allMatches(line);
      if (match.isNotEmpty) {
        if (isMultiHeader) {
          parent['headers'][lastHeaderName]
                  [parent['headers'][lastHeaderName].length - 1] +=
              '\r\n${match.first.group(1) ?? ""}';
        } else {
          parent['headers'][lastHeaderName] +=
              '\r\n${match.first.group(1) ?? ""}';
        }
        continue;
      }

      //Header name and value
      match = RegExp("^([\\w\\d\\-]+):\\s*([^\\r\\n]*)",
              multiLine: true, caseSensitive: true)
          .allMatches(line);
      if (match.isNotEmpty) {
        lastHeaderName = match.first.group(1) ?? '';
        if (parent['headers'][lastHeaderName] != null) {
          //Multiple headers with the same name
          isMultiHeader = true;
          if (parent['headers'][lastHeaderName] is String) {
            parent['headers']
                [lastHeaderName] = [parent['headers'][lastHeaderName]];
          }
          parent['headers'][lastHeaderName].add(match.first.group(2) ?? '');
        } else {
          //Header first appeared here
          isMultiHeader = false;
          parent['headers'][lastHeaderName] = match.first.group(2) ?? '';
        }
        continue;
      }
    }
    //Body
    else {
      //Multipart body
      if (isMultipart) {
        //Search for boundary start

        if (line.indexOf('--$findBoundary') == 0 &&
            !RegExp("\\-\\-(\\r?\\n)?\$", multiLine: true).hasMatch(line)) {
          insideBoundary = true;

          //Complete the previous boundary
          if (boundary != null && boundary['lines'] != null) {
            complete(boundary);
          }

          //Start a new boundary
          final match =
              RegExp("^\\-\\-([^\\r\\n]+)(\\r?\\n)?\$", multiLine: true)
                  .allMatches(line);
          boundary = {"boundary": match.first.group(1), "lines": <String>[]};
          parent['body'].add(boundary);

          continue;
        }

        if (insideBoundary) {
          //Search for boundary end
          if (boundary?['boundary'] != null &&
              lines[i - 1] == '' &&
              line.indexOf('--$findBoundary--') == 0) {
            insideBoundary = false;
            complete(boundary!);
            continue;
          }
          if (boundary?['boundary'] != null &&
              line.indexOf('--$findBoundary--') == 0) {
            continue;
          }
          boundary?['lines'].add(line);
        }
      } else {
        //Solid string body
        parent['body'] = slice(lines, i).join('\r\n');
        break;
      }
    }
  }

  //Complete the last boundary
  if (parent['body'] is List &&
      parent['body'].isNotEmpty &&
      parent['body'][parent['body'].length - 1] is Map &&
      parent['body'][parent['body'].length - 1]['lines'] != null) {
    complete(parent['body'][parent['body'].length - 1]);
  }

  return parent;
}

String? _getCharset(String contentType) {
  final match = RegExp("charset\\s*=\\W*([\\w\\-]+)", multiLine: true)
      .allMatches(contentType);
  return match.firstOrNull?.group(1);
}

Future _getEmailAddress(String rawStr) async {
  var raw = await _unquoteString(rawStr);
  var parseList = addressparser(raw);
  var list =
      parseList.map((v) => {"name": v[0]["name"], "email": v[0]["address"]});

  //Return result
  if (list.isEmpty) {
    return null; //No e-mail address
  }
  if (list.length == 1) {
    return list
        .first; //Only one record, return as object, required to preserve backward compatibility
  }
  return list; //Multiple e-mail addresses as array
}

Future<String> decodeJoint(String str) async {
  var match = RegExp("=\\?([^?]+)\\?(B|Q)\\?(.+?)(\\?=)",
          multiLine: true, caseSensitive: false)
      .allMatches(str)
      .firstOrNull;
  if (match != null) {
    var charset = getCharsetName(match.group(1) ??
        defaultCharset); //eq. match[1] = 'iso-8859-2'; charset = 'iso88592'
    var type = match.group(2)?.toUpperCase() ?? '';
    var value = match.group(3) ?? '';
    if (type == 'B') {
      //Base64
      if (charset == 'utf8') {
        return decode(
            await encode(
                value.replaceAll(RegExp("\\r?\\n", multiLine: true), '')),
            'utf8');
      } else {
        return decode(
            base64Decode(
                value.replaceAll(RegExp("\\r?\\n", multiLine: true), '')),
            charset);
      }
    } else if (type == 'Q') {
      //Quoted printable
      return _unquotePrintable(value, charset, true);
    }
  }
  return str;
}

Future<String> _unquoteString(String? str) async {
  var regex = RegExp("=\\?([^?]+)\\?(B|Q)\\?(.+?)(\\?=)",
      multiLine: true, caseSensitive: false);
  var decodedString = str ?? '';
  var spinOffMatch = regex.allMatches(decodedString);
  if (spinOffMatch.isNotEmpty) {
    for (var spin in spinOffMatch) {
      decodedString = decodedString.replaceAll(
          spin.group(0) ?? "", await decodeJoint(spin.group(0) ?? ''));
    }
  }

  return decodedString.replaceAll(RegExp("\\r?\\n", multiLine: true), '');
}

Future<String> _unquotePrintable(String value, String? charset,
    [bool qEncoding = false]) async {
  var rawString = value
      .replaceAll(RegExp("[\\t ]+\$", multiLine: true), '')
      .replaceAll(RegExp("=(?:\\r?\\n|\$)", multiLine: true), '');

  if (qEncoding) {
    rawString = rawString.replaceAll(RegExp("_", multiLine: true),
        await decode(Uint8List.fromList([0x20]), charset));
  }

  return await mimeDecode(rawString, charset);
}

Future<Map<String, dynamic>> read(
  Map<String, dynamic> eml,
) async {
  Map<String, dynamic> result = {};
  result = await _read(eml);
  return result;
}

//Appends the boundary to the result
Future _append(Map<String, dynamic> headers, dynamic content,
    Map<String, dynamic> result) async {
  final contentType = headers['Content-Type'] ?? headers['Content-type'];
  final contentDisposition = headers['Content-Disposition'];

  final charset = getCharsetName(_getCharset(contentType) ?? defaultCharset);
  var encoding = headers['Content-Transfer-Encoding'] ??
      headers['Content-transfer-encoding'];
  if (encoding is String) {
    encoding = encoding.toLowerCase();
  }
  if (encoding == 'base64') {
    if (contentType != null && contentType.indexOf('gbk') >= 0) {
      // is work?  I'm not sure
      content = await encode(GB2312UTF8.GB2312ToUTF8((content as String)
          .replaceAll(RegExp("\\r?\\n", multiLine: true), '')));
    } else {
      // string to Uint8Array by TextEncoder
      content = await encode((content as String)
          .replaceAll(RegExp("\\r?\\n", multiLine: true), ''));
    }
  } else if (encoding == 'quoted-printable') {
    content = await _unquotePrintable(content as String, charset);
  } else if (encoding != null &&
          charset != 'utf8' &&
          encoding.indexOf('binary') == 0 ||
      encoding.indexOf('8bit') == 0) {
    //'8bit', 'binary', '8bitmime', 'binarymime'
    content = await decode(content as Uint8List, charset);
  }

  if (contentDisposition == null &&
      contentType != null &&
      contentType.indexOf('text/html') >= 0) {
    if (content is! String) {
      content = await decode(content as Uint8List, charset);
    }

    var htmlContent = content
        .replaceAll(RegExp("\\r\\n|(&quot;)", multiLine: true), '')
        .replaceAll(RegExp("\"", multiLine: true), "\"");

    try {
      if (encoding == 'base64') {
        htmlContent = utf8.decode(base64Decode(htmlContent));
      }
    } catch (error) {
      // ignore
    }

    if (result['html'] != null) {
      result['html'] += htmlContent;
    } else {
      result['html'] = htmlContent;
    }

    result['htmlheaders'] = {
      'Content-Type': contentType,
      'Content-Transfer-Encoding': encoding ?? '',
    };
    // self boundary Not used at conversion
  } else if (contentDisposition == null &&
      contentType != null &&
      contentType.indexOf('text/plain') >= 0) {
    if (content is! String) {
      content = await decode(content as Uint8List, charset);
    }
    if (encoding == 'base64') {
      content = utf8.decode(base64Decode(content));
    }
    //Plain text message

    if (result['text'] != null) {
      result['text'] += content;
    } else {
      result['text'] = content;
    }

    result['textheaders'] = {
      'Content-Type': contentType,
      'Content-Transfer-Encoding': encoding ?? '',
    };
    // self boundary Not used at conversion
  } else {
    //Get the attachment
    if (result['attachments'] == null) {
      result['attachments'] = [];
    }

    final attachment = <String, dynamic>{};

    final id = headers['Content-ID'] ?? headers['Content-Id'];
    if (id != null) {
      attachment['id'] = id;
    }

    final nameContainer = [
      'Content-Disposition',
      'Content-Type',
      'Content-type'
    ];

    String? resultName;
    for (var key in nameContainer) {
      String? name = headers[key];
      if (name != null) {
        resultName = name
            .replaceAll(
                RegExp("(\\s|'|utf-8|\\*[0-9]\\*)", multiLine: true), '')
            .split(';')
            .map((v) => RegExp("name[\\*]?=\"?(.+?)\"?\$",
                    multiLine: true, caseSensitive: false)
                .firstMatch(v))
            .fold('', (prev, curr) {
          if (curr != null) {
            return curr.group(1) ?? prev;
          } else {
            return prev;
          }
        });

        if (resultName != null) {
          break;
        }
      }
    }
    if (resultName != null) {
      attachment['name'] = Uri.decodeComponent(resultName);
    }

    final ct = headers['Content-Type'] ?? headers['Content-type'];
    if (ct != null) {
      attachment['contentType'] = ct;
    }

    final cd = headers['Content-Disposition'];
    if (cd != null) {
      attachment['inline'] =
          RegExp("^\\s*inline", multiLine: true).hasMatch(cd);
    }

    attachment['data'] = content as Uint8List;
    attachment['data64'] = await decode(content, charset);
    result['attachments'].add(attachment);
  }
}

Future<Map<String, dynamic>> _read(Map<String, dynamic> data) async {
  final result = <String, dynamic>{};
  if (!data.containsKey('headers')) {
    return {};
  }
  if (data['headers'].containsKey('Date')) {
    DateFormat format = DateFormat("EEE, dd MMM yyyy hh:mm:ss +zzzz");

    try {
      result['date'] =
          DateTime.tryParse(data['headers']['Date'] as String? ?? "") ??
              format.parse(data['headers']['Date'] as String? ?? "");
    } catch (error) {
      result['date'] = DateTime.now();
    }
  }
  if (data['headers'].containsKey('Subject')) {
    result['subject'] = await _unquoteString(data['headers']['Subject']);
  }
  if (data['headers'].containsKey('From')) {
    result['from'] = await _getEmailAddress(data['headers']['From']);
  }
  if (data['headers'].containsKey('To')) {
    result['to'] = await _getEmailAddress(data['headers']['To']);
  }
  if (data['headers'].containsKey('CC')) {
    result['cc'] = await _getEmailAddress(data['headers']['CC']);
  }
  if (data['headers'].containsKey('Cc')) {
    result['cc'] = await _getEmailAddress(data['headers']['Cc']);
  }
  result['headers'] = data['headers'];

  //Content mime type
  String? boundary;
  final ct = data['headers']['Content-Type'] ?? data['headers']['Content-type'];
  if (ct != null && RegExp("^multipart/", multiLine: true).hasMatch(ct)) {
    var b = getBoundary(ct);
    if (b?.isNotEmpty == true) {
      boundary = b;
    }
  }

  if (boundary != null && data['body'] is List) {
    for (var i = 0; i < data['body'].length; i++) {
      final boundaryBlock = data['body'][i];
      if (boundaryBlock == null) {
        continue;
      }
      //Get the message content
      if (!boundaryBlock.containsKey('part')) {
      } else if (boundaryBlock['part'] is String) {
        result['data'] = boundaryBlock['part'];
      } else {
        if (!boundaryBlock['part'].containsKey('body')) {
        } else if (boundaryBlock['part']['body'] is String) {
          _append(boundaryBlock['part']['headers'],
              boundaryBlock['part']['body'], result);
        } else {
          // keep multipart/alternative
          final currentHeaders = boundaryBlock['part']['headers'];
          final currentHeadersContentType =
              currentHeaders['Content-Type'] ?? currentHeaders['Content-type'];
          // Hasmore ?
          if (currentHeadersContentType != null &&
              currentHeadersContentType.indexOf('multipart') >= 0 &&
              result['multipartAlternative'] == null) {
            result['multipartAlternative'] = {
              'Content-Type': currentHeadersContentType,
            };
          }
          for (var j = 0; j < boundaryBlock['part']['body'].length; j++) {
            final selfBoundary = boundaryBlock['part']['body'][j];
            if (selfBoundary is String) {
              result['data'] = selfBoundary;
              continue;
            }

            final headers = selfBoundary['part']['headers'];
            final content = selfBoundary['part']['body'];
            if (content is List) {
              for (var bound in content) {
                await _append(
                    bound['part']['headers'], bound['part']['body'], result);
              }
            } else {
              await _append(headers, content, result);
            }
          }
        }
      }
    }
  } else if (data['body'] is String) {
    await _append(data['headers'], data['body'], result);
  }
  return result;
}
