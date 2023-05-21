import 'dart:convert';

Future<void> parseCatalog(inputFile, outputFile) async {
  final jsonData = json.decode(await inputFile.readAsString());
  final List items = jsonData['items'];
  final transformedItems = items.where((item) {
    return item['status'] == 'approved';
  }).map((item) {
    return {
      'id': item['domain'],
      'name': item['manifest']['name_for_human'],
      'description': item['manifest']['description_for_human'],
      'logo': item['manifest']['logo_url'],
    };
  }).toList();
  await outputFile.writeAsString(json.encode(transformedItems));
}
