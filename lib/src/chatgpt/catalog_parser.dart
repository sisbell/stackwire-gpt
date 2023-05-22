import 'dart:convert';

import 'package:file/file.dart';

typedef TransformFunction = dynamic Function(dynamic);

Future<void> parseJson(
    File inputFile, File outputFile, TransformFunction transform) async {
  final jsonData = json.decode(await inputFile.readAsString());
  final List items = jsonData['items'];
  final transformedItems = items
      .where((item) {
        return item['status'] == 'approved';
      })
      .map(transform)
      .toList();
  await outputFile.writeAsString(json.encode(transformedItems));
}

TransformFunction catalogTransform = (item) {
  return {
    'id': item['domain'],
    'name': item['manifest']['name_for_human'],
    'description': item['manifest']['description_for_human'],
    'logo': item['manifest']['logo_url'],
  };
};

TransformFunction domainsTransform = (item) {
  return item['domain'];
};

Future<void> parseCatalog(File inputFile, File outputFile) async {
  return parseJson(inputFile, outputFile, catalogTransform);
}

Future<void> parseDomains(File inputFile, File outputFile) async {
  return parseJson(inputFile, outputFile, domainsTransform);
}
