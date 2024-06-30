class Tokenizer {
  late String str;
  String operatorCurrent = '';
  String operatorExpecting = '';

  dynamic node;
  bool escaped = false;
  List list = [];
  late Map<String, String> operators;

  Tokenizer(dynamic str) {
    this.str = (str ?? '').toString();

    operators = {
      '"': '"',
      '(': ')',
      '<': '>',
      ',': '',
      ':': ';',
      // Semicolons are not a legal delimiter per the RFC2822 grammar other
      // than for terminating a group, but they are also not valid for any
      // other use in this context.  Given that some mail clients have
      // historically allowed the semicolon as a delimiter equivalent to the
      // comma in their UI, it makes sense to treat them the same as a comma
      // when used outside of a group.
      ';': '',
    };
  }

  List tokenize() {
    String chr;
    List list = [];
    for (var i = 0, len = str.length; i < len; i++) {
      chr = str[i];
      checkChar(chr);
    }

    for (var node in this.list) {
      node['value'] = (node["value"] ?? '').toString().trim();
      if (node['value'] != '') {
        list.add(node);
      }
    }

    return list;
  }

  void checkChar(String chr) {
    if (escaped) {
      // ignore next condition blocks
    } else if (chr == operatorExpecting) {
      node = {
        "type": 'operator',
        "value": chr,
      };
      list.add(node);
      node = null;
      operatorExpecting = '';
      escaped = false;
      return;
    } else if (operatorExpecting == '' && operators.containsKey(chr)) {
      node = {
        "type": 'operator',
        "value": chr,
      };
      list.add(node);
      node = null;
      operatorExpecting = operators[chr]!;
      escaped = false;
      return;
    } else if (['"', "'"].contains(operatorExpecting) && chr == '\\') {
      escaped = true;
      return;
    }

    if (node == null) {
      node = {
        "type": 'text',
        "value": '',
      };
      list.add(node);
    }

    if (chr == '\n') {
      // Convert newlines to spaces. Carriage return is ignored as \r and \n usually
      // go together anyway and there already is a WS for \n. Lone \r means something is fishy.
      chr = ' ';
    }

    if (chr.codeUnitAt(0) >= 0x21 || [' ', '\t'].contains(chr)) {
      // skip command bytes
      node["value"] += chr;
    }

    escaped = false;
  }
}

List _slice(List list, [int start = 0, int? end]) {
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

_handleAddress(List tokens) {
  dynamic token;
  var isGroup = false;
  var state = 'text';
  dynamic address;
  var addresses = [];
  var data = <String, dynamic>{
    "address": [],
    "comment": [],
    "group": [],
    "text": [],
  };

  // Filter out <addresses>, (comments) and regular text
  for (var i = 0, len = tokens.length; i < len; i++) {
    token = tokens[i];
    if (token['type'] == 'operator') {
      switch (token['value']) {
        case '<':
          state = 'address';
          break;
        case '(':
          state = 'comment';
          break;
        case ':':
          state = 'group';
          isGroup = true;
          break;
        default:
          state = 'text';
      }
    } else if (token['value'] != null) {
      if (state == 'address') {
        // handle use case where unquoted name includes a "<"
        // Apple Mail truncates everything between an unexpected < and an address
        // and so will we
        token['value'] =
            token['value'].toString().replaceAll(RegExp("^[^<]*<\\s*"), '');
      }
      data[state]?.add(token["value"]);
    }
  }

  // If there is no text but a comment, replace the two
  if (data['text']?.isEmpty == true && data['comment']?.isNotEmpty == true) {
    data['text'] = data['comment']!;
    data['comment'] = [];
  }

  if (isGroup) {
    // http://tools.ietf.org/html/rfc2822#appendix-A.1.3
    data['text'] = data['text']?.join(' ').codeUnits ?? [];
    addresses.add({
      "name": data["text"] ?? address?['name'],
      "group": data["group"]?.isNotEmpty == true
          ? addressparser(data['group']!.join(','))
          : [],
    });
  } else {
    // If no address was found, try to detect one from regular text
    if (data['address']?.isEmpty == true && data['text']?.isNotEmpty == true) {
      for (var i = data['text']!.length - 1; i >= 0; i--) {
        if (RegExp("^[^@\\s]+@[^@\\s]+\$").hasMatch(data['text']![i])) {
          data['address'] = _slice(data['text']!, i, 1);
          break;
        }
      }

      String regexHandler(address) {
        if (data['address']?.isEmpty == true) {
          data['address'] = [address.group(0).trim()];
          return ' ';
        } else {
          return address.group(0);
        }
      }

      // still no address
      if (data['address']?.isNotEmpty != true) {
        for (var i = data['text']!.length - 1; i >= 0; i--) {
          // fixed the regex to parse email address correctly when email address has more than one @
          data['text']![i] = (data['text']![i] as String)
              .replaceAllMapped(
                  RegExp("\\s*\\b[^@\\s]+@[^\\s]+\\b\\s*"), regexHandler)
              .trim();
          if (data['address']?.isEmpty != true) {
            break;
          }
        }
      }
    }

    // If there's still is no text but a comment exixts, replace the two
    if (data['text']?.isNotEmpty != true && data['comment']?.isEmpty != true) {
      data['text'] = data['comment']!;
      data['comment'] = [];
    }

    // Keep only the first address occurence, push others to regular text
    if (data['address'].length > 1) {
      data['text'] = data['text'].concat(data['address'].splice(1));
    }

    // Join values with spaces
    data['text'] = data['text']!.join(' ');
    data['address'] = data['address']!.join(' ');

    if (data['address'] != null && isGroup) {
      return [];
    } else {
      address = {
        "address": data['address'] ?? data['text'] ?? '',
        "name": data["text"] ?? data["address"] ?? '',
      };

      if (address["address"] == address["name"]) {
        if (RegExp("@").hasMatch(address["address"] ?? '')) {
          address["name"] = '';
        } else {
          address["address"] = '';
        }
      }

      addresses.add(address);
    }

    return addresses;
  }
}

List addressparser(
  String str,
) {
  var tokenizer = Tokenizer(str);
  var tokens = tokenizer.tokenize();

  var addresses = [];
  var address = [];
  var parsedAddresses = [];

  for (var token in tokens) {
    if (token['type'] == 'operator' &&
        (token['value'] == ',' || token['value'] == ';')) {
      if (address.isNotEmpty) {
        addresses.add(address);
      }
      address = [];
    } else {
      address.add(token);
    }
  }

  if (address.isNotEmpty) {
    addresses.add(address);
  }

  for (var address in addresses) {
    address = _handleAddress(address);
    if (address.isNotEmpty) {
      parsedAddresses = [...parsedAddresses, address];
    }
  }

  return parsedAddresses;
}
