part of gpt_plugins;

class ReportingGptPlugin extends GptPlugin {
  late List<String> reports;

  ReportingGptPlugin(super.projectConfig, super.block);

  @override
  Future<void> init(execution, pluginConfiguration) async {
    List<dynamic> blockIds = execution["blockIds"];
    List<Future<String>> futurePrompts = blockIds
        .map((e) async => await fileSystem.readFileAsString(
            "$reportDir/$projectName-$projectVersion-$e-report.json"))
        .toList();
    reports = await Future.wait(futurePrompts);
  }

  @override
  Future<void> doExecution(results, dryRun) async {
    final tables = StringBuffer();
    for (String r in reports) {
      final report = jsonDecode(r);
      final blockId = report["blockId"];
      final configuration = report["configuration"];
      final header = generateBlockHeader(blockId, configuration);
      tables.write(header);
      final blockRuns = report["blockRuns"];
      for (var blockRun in blockRuns) {
        final htmlContent = generateHtmlContent(blockRun);
        tables.write(htmlContent);
      }
    }
    final fileName = "$projectName-$projectVersion-report.html";
    print("Writing project report: $reportDir/$fileName");
    final report = generateHtmlWrapper(tables.toString());
    final outputFile = File("$reportDir/$fileName");
    await outputFile.writeAsString(report);
  }

  String generateBlockHeader(blockId, configuration) {
    final header = "<h1>BLOCK: $blockId</h1>";
    final formattedJson = JsonEncoder.withIndent('  ')
        .convert(configuration)
        .replaceAll('\n', '<br>');

    return "$header<br\><pre>$formattedJson</pre>";
  }

  String generateHtmlWrapper(String body) {
    final htmlBuffer = StringBuffer();
    htmlBuffer.write('<!DOCTYPE html><html><head></head><body>');
    htmlBuffer.write(
        '<div style="width: 80%; margin-left: 10%; margin-right: 10%;">');
    htmlBuffer
        .write("<h1>$projectName:$projectVersion</h1>${DateTime.now()}<hr/>");
    htmlBuffer.write(body);
    htmlBuffer.write('</div></body></html>');
    return htmlBuffer.toString();
  }

  String generateHtmlContent(Map<String, dynamic> data) {
    final htmlBuffer = StringBuffer();
    for (final node in data['blockResults']) {
      final tableColor = node['role'] == 'user' ? '#d0e1ff' : '#fff4d0';

      htmlBuffer.write(
          '<table style="background-color: $tableColor; width: 100%; padding: 20px;">');
      htmlBuffer.write(
          '<tr><td style="padding: 5px;"><h2>${node['role'].toUpperCase()}</h2> <h3> ${node['promptFile']}</h3></td></tr>');
      htmlBuffer.write(
          '<tr><td style="border-top: 1px solid #000; style="padding: 10px;"">');
      final contentWithNewlines = node['content'].replaceAll('\n', '<br>');

      if (node['role'] == 'assistant') {
        try {
          final contentJson = jsonDecode(node['content']);
          final formattedJson = JsonEncoder.withIndent('  ')
              .convert(contentJson)
              .replaceAll('\n', '<br>');
          final updatedJson = formattedJson.splitMapJoin(
            RegExp(r'(".+": ")([^"]+)(",?)'),
            onMatch: (match) {
              final key = match.group(1);
              final value = match.group(2);
              final comma = match.group(3);
              final formattedValue = value!.length > 80
                  ? value.replaceAllMapped(
                      RegExp(r'.{1,80}'), (match) => '${match.group(0)}<br>')
                  : value;
              return '$key$formattedValue$comma';
            },
            onNonMatch: (nonMatch) => nonMatch,
          );

          htmlBuffer.write('<pre>$updatedJson</pre>');
        } catch (e) {
          htmlBuffer.write('$contentWithNewlines');
        }
      } else {
        htmlBuffer.write('$contentWithNewlines');
      }

      htmlBuffer.write('</td></tr></table><hr>');
    }
    return htmlBuffer.toString();
  }
}
