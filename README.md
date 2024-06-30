<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

This package is a port of [eml-pars-js](https://www.npmjs.com/package/eml-parse-js) wich reads and parses email messages saved in MSG and EML format. It also reads attachments from the saved message.

## Features

Parse and reads EML messages, with attachements.

## Getting started

Include this library in your Android or IOS flutter App. For encoding and decoding it uses the package charset_converter which only works in an app environment. 

## Usage

See the example. 

```dart
    String eml = await File('./sample.eml').readAsString();

    EmlParseResult result =  await parseEml(eml);

    
    print(result.from?.email);
    print(result.to?.email);
    print(result.subject);
    print(result.text);
    print(result.html);

    if (result.attachments != null && result.attachments!.isNotEmpty) {
      for (EmlEmailAttachment attachment in result.attachments!) {
        print(
            'Attachment: ${attachment.name} ${attachment.contentType} ${attachment.data.length}');
      }
    }

```

## Additional information

