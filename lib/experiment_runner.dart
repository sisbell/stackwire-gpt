import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'files.dart';

Future<String> createPrompt(String template, templateProperties) async {
  RegExp placeholderPattern = RegExp(r'\$\{([^\}]+)\}');
  String modifiedTemplate = template.replaceAllMapped(placeholderPattern,
          (Match match) => templateProperties[match[1]] ?? match[0]);
  return modifiedTemplate;
}

Future<void> runExperiment(Map<String, dynamic> experimentConfig,
    aiConfig) async {
  final experimentName = experimentConfig["experimentName"];
  final outputDir = experimentConfig["outputDir"];
  List<String> promptTemplates = experimentConfig["promptTemplates"];
  List<dynamic> promptChains = experimentConfig["promptChains"];
  final promptProperties = experimentConfig["promptProperties"];
  final apiKey = experimentConfig["apiKey"];
  var experimentRuns = experimentConfig["experimentRuns"];
  final chainRuns = experimentConfig["chainRuns"];
  final promptAiFile = experimentConfig["promptAiFile"];
  final responseFormat = experimentConfig["responseFormat"];
  final systemMessage = experimentConfig['systemMessage'];
  final reportDir = "$outputDir/$experimentName";
  final dataDir = "$reportDir/data";
  final metricsFile = "$reportDir/metrics.csv";
  final fixJson = experimentConfig["fixJson"];
  print("$experimentRuns $chainRuns");
  while (experimentRuns-- > 0) {
    print("Experiment Run: $experimentRuns");
    var cr = chainRuns;
    var promptValues = Map.from(promptProperties);
    while (cr >= 1) {
      print("Chain Run: $cr");
      for (int i = 0; i < promptTemplates.length; i++) {
        print("Make Prompt Request");
        var promptFileName = promptChains[i];
        var promptTemplate = promptTemplates[i];
        final prompt = await createPrompt(promptTemplate, promptValues);
        aiConfig['messages'] = createMessages(systemMessage, prompt);
        final requestBody = jsonEncode(aiConfig);
        final responseBody = await sendHttpPostRequest(requestBody, apiKey);
        final content = responseBody["choices"][0]["message"]["content"];

        try {
          addJsonContentToPromptValues(content, responseFormat, promptValues);
        } catch (e) {
          if(fixJson) {
            final fixedJson = extractJson(content);
            if(fixedJson != null) {
              addJsonContentToPromptValues(fixedJson, responseFormat, promptValues);
              print("Fixed JSON");
            } else {
              print("RETHROWS");
              rethrow;
            }
          } else {
            rethrow;
          }
        } finally {
          await writeCalculatedPrompt(prompt, promptAiFile, experimentRuns, i );
          await writeResponseAsText(experimentName, responseBody, reportDir, experimentRuns, i);
          await writeRequestAndResponseAsJson(requestBody, responseBody, dataDir);
          await writeMetrics(responseBody, promptFileName, metricsFile);
        }
      }
      cr--;
    }
    print("Finished Experiment Run");
  }
}

void addJsonContentToPromptValues(jsonContent, responseFormat, promptValues) {
  if (responseFormat == "json") {
    try {
      final newValues = jsonDecode(jsonContent);
      promptValues.addAll(newValues);
    } catch (e) {
      print("Broken JSON");
      print(jsonContent);
      print(e);
      throw Exception("Malformed JSON. Failing Experiment.");
    }
  }
}

List<Map<String, dynamic>> createMessages(systemMessage, prompt) {
  List<Map<String, dynamic>> messages = [
    {"role": "user", "content": prompt},
  ];
  if (systemMessage != null) {
    messages.insert(0,
      {"role": "system", "content": systemMessage},
    );
  }
  return messages;
}

Future<Map<String, dynamic>> sendHttpPostRequest(requestBody, apiKey) async {
  print("Making call to OpenAi");
  final headers = {
    "Authorization": "Bearer $apiKey",
    "Content-Type": "application/json",
  };

  try {
    final startTime = DateTime
        .now()
        .millisecondsSinceEpoch;
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: requestBody,
    );
    final endTime = DateTime
        .now()
        .millisecondsSinceEpoch;
    if (response.statusCode == 200) {
      print('Request successful.');
    } else {
      print('Request failed with status code: ${response.statusCode}');
      print(requestBody);
    }
    Map<String, dynamic> responseBody = jsonDecode(response.body);
    responseBody.addAll({"requestTime": (endTime - startTime)});
    return responseBody;
  } catch (e) {
    print('Error occurred during the request: $e');
  }
  return {};
}


String? extractJson(content) {
  RegExp jsonPattern = RegExp(r'(\{.*?\})');
  Match? jsonMatch = jsonPattern.firstMatch(content);
  if (jsonMatch != null) {
    return jsonMatch.group(1)!;
  } else {
    print('No JSON string found in the input.');
  }
}
