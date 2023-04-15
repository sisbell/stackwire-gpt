import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'files.dart';

Future<String> createPrompt(
    experimentName, String template, templateValues, outputFile) async {
  RegExp placeholderPattern = RegExp(r'\$\{([^\}]+)\}');
  String modifiedTemplate = template.replaceAllMapped(placeholderPattern,
      (Match match) => templateValues[match[1]] ?? match[0]);

  await writeString(modifiedTemplate, outputFile);

  print('Output file created: $outputFile');
  return modifiedTemplate;
}

Future<void> runExperiment(
    Map<String, dynamic> experimentConfig, aiConfig) async {
  final experimentName = experimentConfig["experimentName"];
  final promptTemplate = experimentConfig["promptTemplate"];
  final promptProperties = experimentConfig["promptProperties"];
  final apiKey = experimentConfig["apiKey"];
  final outputDir = experimentConfig["outputDir"];
  var numberOfRuns = experimentConfig["runs"];
  final runDepth = experimentConfig["runDepth"];
  final promptAiFile = experimentConfig["promptAiFile"];
  final responseFormat = experimentConfig["responseFormat"];
  final systemMessage = experimentConfig['systemMessage'];

  print("$numberOfRuns $runDepth");
  while (numberOfRuns-- > 0) {
    print("Run: $numberOfRuns");
    var depth = runDepth;
    var values = Map.from(promptProperties);
    while (depth >= 0) {
      print("Depth: $depth");
      final prompt = await createPrompt(
          experimentName, promptTemplate, values, promptAiFile);
      List<Map<String, dynamic>> messages = [
        {"role": "user", "content": prompt},
      ];
      if (systemMessage != null) {
        messages.add(
          {"role": "system", "content": systemMessage},
        );
      }
      aiConfig['messages'] = messages;
      final isJsonFormat = responseFormat == "json";
      final params = await sendHttpPostRequest(
          experimentName, outputDir, aiConfig, apiKey, isJsonFormat);
      if (isJsonFormat) {
        values.addAll(params);
      }
      depth--;
    }
    print("Finished Run");
  }
}

Future<Map<String, dynamic>> sendHttpPostRequest(
    experimentName, outputDir, data, apiKey, isJsonFormat) async {
  print("Making call to OpenAi");
  final textResponseBuffer = StringBuffer();
  textResponseBuffer.writeln("$experimentName");

  final headers = {
    "Authorization": "Bearer ${apiKey}",
    "Content-Type": "application/json",
  };

  final body = jsonEncode(data);
  String content = data['messages'][0]['content'];
  textResponseBuffer.writeln(content);
  textResponseBuffer.writeln("------");
  try {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: body,
    );
    final endTime = DateTime.now().millisecondsSinceEpoch;

    if (response.statusCode == 200) {
      print('Request successful.');
    } else {
      print('Request failed with status code: ${response.statusCode}');
    }
    Map<String, dynamic> jsonBody = jsonDecode(response.body);
    final responseId = jsonBody["id"];
    final usage = jsonBody["usage"];
    final promptTokens = usage['prompt_tokens'];
    final completionTokens = usage['completion_tokens'];
    final totalTokens = usage['total_tokens'];

    final metricsBuffer = StringBuffer();
    final requestTime = endTime - startTime;
    metricsBuffer.writeln("$responseId, $requestTime, $promptTokens, $completionTokens, $totalTokens");
    writeMetrics(metricsBuffer.toString(), "$outputDir/$experimentName/metrics.csv");

    final content = jsonBody["choices"][0]["message"]["content"];
    textResponseBuffer.writeln(content);

    writeString(textResponseBuffer.toString(),
        "$outputDir/$experimentName/data/$responseId-text.txt");
    writeString(
        body, "$outputDir/$experimentName/data/$responseId-request.json");
    writeString(response.body,
        "$outputDir/$experimentName/data/$responseId-response.json");
    return isJsonFormat ? jsonDecode(content) : {};
  } catch (e) {
    print('Error occurred during the request: $e');
  }
  return {};
}
