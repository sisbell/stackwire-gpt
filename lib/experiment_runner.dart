import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'files.dart';

Future<String> createPrompt(experimentName, String template, templateValues, outputFile) async {
  RegExp placeholderPattern = RegExp(r'\$\{([^\}]+)\}');
  String modifiedTemplate = template.replaceAllMapped(
      placeholderPattern, (Match match) => templateValues[match[1]] ?? match[0]);

  await writeString(modifiedTemplate, outputFile);

  print('Output file created: $outputFile');
  return modifiedTemplate;
}

Future<void> runExperiment(Map<String, dynamic> experimentConfig, aiConfig) async {
  final experimentName = experimentConfig["experimentName"];
  final promptTemplateFilePath = experimentConfig["promptTemplateFilePath"];
  final templateValues = experimentConfig["templateValues"];
  final apiKey = experimentConfig["apiKey"];
  final outputDir = experimentConfig["outputDir"];
  var numberOfRuns = experimentConfig["runs"];
  final runDepth = experimentConfig["runDepth"];
  final promptAiFile = experimentConfig["promptAiFile"];
  final responseFormat = experimentConfig["responseFormat"];
  String promptTemplate = await readFileAsString(promptTemplateFilePath);
  print("$numberOfRuns $runDepth");
  while(numberOfRuns-- > 0) {
    print("Run: $numberOfRuns");
    var depth = runDepth;
    var values  = Map.from(templateValues);
    while(depth >= 0) {
      print("Depth: $depth");
      final prompt = await createPrompt(experimentName, promptTemplate, values, promptAiFile);
      List<Map<String, dynamic>> messages = [
        {"role": "user", "content": prompt},
      ];
      aiConfig['messages'] = messages;
      final isJsonFormat = responseFormat == "json";
      final params = await sendHttpPostRequest(experimentName, outputDir, aiConfig, apiKey, isJsonFormat);
      if(isJsonFormat) {
        values.addAll(params);
      }
      depth--;
    }
    print("Finished Run");
  }
}

Future<Map<String, dynamic>> sendHttpPostRequest(experimentName, outputDir, data, apiKey, isJsonFormat) async {
  print("Making call to OpenAi");
  final stringBuffer = StringBuffer();
  stringBuffer.writeln("$experimentName");

  final headers = {
    "Authorization": "Bearer ${apiKey}",
    "Content-Type": "application/json",
  };

  final body = jsonEncode(data);
  String content = data['messages'][0]['content'];
  stringBuffer.writeln(content);
  try {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      print('Request successful.');
    } else {
      print('Request failed with status code: ${response.statusCode}');
    }
    Map<String, dynamic> jsonBody = jsonDecode(response.body);
    final responseId = jsonBody["id"];

    final content = jsonBody["choices"][0]["message"]["content"];
    stringBuffer.writeln(content);

    writeString(stringBuffer.toString(), "$outputDir/$experimentName/data/$responseId-text.txt");
    writeString(body, "$outputDir/$experimentName/data/$responseId-request.json");
    writeString(response.body, "$outputDir/$experimentName/data/$responseId-response.json");
    return isJsonFormat ? jsonDecode(content) : {};
  } catch (e) {
    print('Error occurred during the request: $e');
  }
  return {};
}