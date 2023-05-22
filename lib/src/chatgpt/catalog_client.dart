import 'dart:convert';

import 'package:file/file.dart';
import 'package:http/http.dart' as http;

import '../io_helper.dart';

class CatalogClient {
  FileSystem fileSystem;

  late IOHelper ioHelper;

  CatalogClient(this.fileSystem) {
    ioHelper = IOHelper(fileSystem: fileSystem);
  }

  Future<void> downloadManifests(domains, outputDir) async {
    final start = DateTime.now().second;
    await ioHelper.createDirectoryIfNotExist(outputDir);

    var logData = {
      "ok": [],
      "failures": [],
    };

    for (String domain in domains) {
      final url = Uri.parse('https://$domain/.well-known/ai-plugin.json');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final outputFile = fileSystem.file('$outputDir/$domain.json');
          await outputFile.writeAsString(response.body);
          print('Saved data for $domain');

          var data = json.decode(response.body);
          logData["ok"]!.add({
            "domain": domain,
            "manifest": data,
          });
        } else {
          print(
              'Failed to load data for $domain. Response status: ${response.statusCode}');
          logData["failures"]!.add({
            "domain": domain,
            "responseCode": response.statusCode,
            "exception":
                'Failed to load data for $domain. Response status: ${response.statusCode}',
          });
        }
      } on http.ClientException catch (e) {
        print('Exception occurred: $e');
        logData["failures"]!.add({
          "domain": domain,
          "responseCode": null,
          "exception": e.toString(),
        });
      }
    }
    final duration = start - DateTime.now().second;
    print("Total Time: $duration seconds");
    final logFile = fileSystem.file('$outputDir/log.json');
    await logFile.writeAsString(json.encode(logData));
  }
}
