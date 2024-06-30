import 'dart:math';
import 'dart:typed_data';

import 'charset.dart';



List slice(List list, [int start = 0, int? end]) {
  int length = list.length;
  if (length <= 0) {
    return [];
  }
  end = end ?? length;
  if (start < 0) {
    start = -start > length ? 0 : (length + start);
  }
  end = end > length ? length : end;
  if (end < 0) {
    end += length;
  }
  length = start > end ? 0 : ((end - start) >> 0);
  start >>= 0;

  int index = -1;
  List result = List.generate(length, (i) => i);
  while (++index < length) {
    result[index] = list[index + start];
  }

  return result;
}

Future<String> mimeDecode(
    [String str = '', String? fromCharset = 'UTF-8']) async {
  var encodedBytesCount =
      RegExp("=[\\da-fA-F]{2}", multiLine: true).allMatches(str).length;
  var buffer = Uint8List(str.length - encodedBytesCount * 2);

  for (var i = 0, len = str.length, bufferPos = 0; i < len; i++) {
    var hex = str.substr(i + 1, 2);
    var chr = str[i];
    if (chr == '=' && hex != '' && RegExp("[\\da-fA-F]{2}").hasMatch(hex)) {
      buffer[bufferPos++] = int.parse(hex, radix: 16);
      i += 2;
    } else {
      buffer[bufferPos++] = chr.codeUnitAt(0);
    }
  }

  return await decode(buffer, fromCharset);
}

String? getBoundary(String contentType) {
  final matches = RegExp(
          "(?:B|b)oundary=(?:'|\")?(.+?)(?:'|\")?(\\s*;[\\s\\S]*)?\$",
          multiLine: true)
      .allMatches(contentType);
  return matches.isNotEmpty ? matches.first.group(1) : null;
}

String getCharsetName(String charset) {
  return charset
      .toLowerCase()
      .replaceAll(RegExp("[^0-9a-z]", multiLine: true), '');
}

//Generates a random id
String guid() {
  return 'xxxxxxxxxxxx-4xxx-yxxx-xxxxxxxxxxxx'
      .replaceAllMapped(RegExp("[xy]", multiLine: true), (c) {
    final r = ((Random().nextDouble() * 16).toInt()) | 0,
        v = c.group(0) == "x" ? r : (r & 0x3) | 0x8;
    return v.toRadixString(16);
  }).replaceAll('-', '');
}

String wrap(String s, int i) {
  List a = [];
  do {
    a.add(s.substring(0, i));
  } while ((s = s.substring(i, s.length)) != '');
  return a.join('\r\n');
}

class GB2312UTF8 {
  static num Dig2Dec(String s) {
    num retV = 0;
    if (s.length == 4) {
      for (var i = 0; i < 4; i++) {
        retV += num.parse(s[i]) * pow(2, 3 - i);
      }
      return retV;
    }
    return -1;
  }

  static String Hex2Utf8(String s) {
    var retS = '';
    var tempS = '';
    var ss = '';
    if (s.length == 16) {
      tempS = '1110${s.substring(0, 4)}';
      tempS += '10${s.substring(4, 10)}';
      tempS += '10${s.substring(10, 16)}';
      var sss = '0123456789ABCDEF';
      for (var i = 0; i < 3; i++) {
        retS += '%';
        ss = tempS.substring(i * 8, (int.parse(i.toString()) + 1) * 8);
        retS += sss[Dig2Dec(ss.substring(0, 4)).toInt()];
        retS += sss[Dig2Dec(ss.substring(4, 8)).toInt()];
      }
      return retS;
    }
    return '';
  }

  static String Dec2Dig(num n1) {
    var s = '';
    num n2 = 0;
    for (var i = 0; i < 4; i++) {
      n2 = pow(2, 3 - i);
      if (n1 >= n2) {
        s += '1';
        n1 = n1 - n2;
      } else {
        s += '0';
      }
    }
    return s;
  }

  static String Str2Hex(String s) {
    var c = '';
    int n;
    var ss = '0123456789ABCDEF';
    var digS = '';
    for (var i = 0; i < s.length; i++) {
      c = s[i];
      n = ss.indexOf(c);
      digS += Dec2Dig(num.parse(n.toString()));
    }
    return digS;
  }

  static String GB2312ToUTF8(String s1) {
    var s = Uri.encodeComponent(s1);
    var sa = s.split('%');
    var retV = '';
    if (sa[0] != '') {
      retV = sa[0];
    }
    for (var i = 1; i < sa.length; i++) {
      if (sa[i].substring(0, 1) == 'u') {
        retV += Hex2Utf8(Str2Hex(sa[i].substring(1, 5)));
        if (sa[i].isNotEmpty) {
          retV += sa[i].substring(5);
        }
      } else {
        retV += Uri.decodeComponent('%${sa[i]}');
        if (sa[i].isNotEmpty) {
          retV += sa[i].substring(5);
        }
      }
    }
    return retV;
  }

  static String UTF8ToGB2312(String str1) {
    var substr = '';
    var a = '';
    var b = '';
    var c = '';
    var i = -1;
    i = str1.indexOf('%');
    if (i == -1) {
      return str1;
    }
    while (i != -1) {
      if (i < 3) {
        substr = substr + str1.substr(0, i - 1);
        str1 = str1.substr(i + 1, str1.length - i);
        a = str1.substr(0, 2);
        str1 = str1.substr(2, str1.length - 2);
        if ((int.parse(a, radix: 16) & 0x80) == 0) {
          substr = substr + String.fromCharCode(int.parse(a, radix: 16));
        } else if ((int.parse(a, radix: 16) & 0xe0) == 0xc0) {
          //two byte
          b = str1.substr(1, 2);
          str1 = str1.substr(3, str1.length - 3);
          var widechar = (int.parse(a, radix: 16) & 0x1f) << 6;
          widechar = widechar | (int.parse(b, radix: 16) & 0x3f);
          substr = substr + String.fromCharCode(widechar);
        } else {
          b = str1.substr(1, 2);
          str1 = str1.substr(3, str1.length - 3);
          c = str1.substr(1, 2);
          str1 = str1.substr(3, str1.length - 3);
          var widechar = (int.parse(a, radix: 16) & 0x0f) << 12;
          widechar = widechar | ((int.parse(b, radix: 16) & 0x3f) << 6);
          widechar = widechar | (int.parse(c, radix: 16) & 0x3f);
          substr = substr + String.fromCharCode(widechar);
        }
      } else {
        substr = substr + str1.substring(0, i);
        str1 = str1.substring(i);
      }
      i = str1.indexOf('%');
    }

    return substr + str1;
  }
}

extension StringSubStr on String {
  String substr(start, [slength]) {
    return substring(start, min(length, start + slength));
  }
}
