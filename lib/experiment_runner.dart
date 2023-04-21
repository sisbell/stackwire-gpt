import 'dart:convert';

import 'package:http/http.dart' as http;

import 'files.dart';

Future<String> createPrompt(String template, templateProperties) async {
  RegExp placeholderPattern = RegExp(r'\$\{([^\}]+)\}');
  String modifiedTemplate = template.replaceAllMapped(placeholderPattern,
      (Match match) => templateProperties[match[1]] ?? match[0]);
  return modifiedTemplate;
}

Future<void> runExperiment(
    Map<String, dynamic> experimentConfig, aiConfig) async {
  final experimentName = experimentConfig["experimentName"];
  final outputDir = experimentConfig["outputDir"];
  List<String> promptTemplates = experimentConfig["promptTemplates"];
  List<dynamic> promptChains = experimentConfig["promptChains"];
  final promptProperties = experimentConfig["promptProperties"];
  List<dynamic> excludesMessageHistory =
      experimentConfig["excludesMessageHistory"];
  final apiKey = experimentConfig["apiKey"];
  var experimentRuns = experimentConfig["experimentRuns"];
  final chainRuns = experimentConfig["chainRuns"];
  final responseFormat = experimentConfig["responseFormat"];
  final systemMessage = experimentConfig['systemMessage'];
  final reportDir = "$outputDir/$experimentName";
  final dataDir = "$reportDir/data";
  final metricsFile = "$reportDir/metrics.csv";
  final fixJson = experimentConfig["fixJson"];

  List<Map<String, dynamic>> experimentResults = [];
  Map<String, dynamic> experimentReport = {
    "experimentName": experimentName,
    "experimentResults": experimentResults
  };

  print("$experimentRuns $chainRuns");
  for (var er = 1; er <= experimentRuns; er++) {
    print("Experiment Run: $er");
    List<Map<String, dynamic>> requestHistory = [];
    var promptValues = Map.from(promptProperties);
    List<Map<String, dynamic>> messageHistory =
        createSystemMessage(systemMessage);
    for (var cr = 1; cr <= chainRuns; cr++) {
      print("Chain Run: $cr");
      for (int i = 0; i < promptTemplates.length; i++) {
        var promptFileName = promptChains[i];
        var promptTemplate = promptTemplates[i];
        final prompt = await createPrompt(promptTemplate, promptValues);
        if (excludesMessageHistory.contains(promptFileName)) {
          aiConfig['messages'] = [createUserMessage(prompt)];
        } else {
          messageHistory.add(createUserMessage(prompt));
          aiConfig['messages'] = messageHistory;
        }
        final requestBody = jsonEncode(aiConfig);
        final responseBody = await sendHttpPostRequest(requestBody, apiKey);
        if (responseBody['errorCode'] != null) {
          await logFailedRequest(requestBody, dataDir, er);
          experimentResults.add(createExperiment(er, requestHistory, "FAILURE",
              "Failed Request: ${responseBody['errorCode']}"));
          await writeExperimentsReport(experimentReport, reportDir);
          throw Exception("Failed Request: ${responseBody['errorCode']}");
        }
        requestHistory.add(createUserHistory(
            prompt, responseBody, promptFileName, promptValues, cr));

        final content = responseBody["choices"][0]["message"]["content"];
        if (!excludesMessageHistory.contains(promptFileName)) {
          messageHistory.add(createAssistantMessage(content));
        }

        try {
          if (responseFormat == "json") {
            addPromptValues(content, responseFormat, promptValues, fixJson);
          }
        } catch (e) {
          print(e);
          requestHistory.add(createAssistantHistory(
              content, responseBody, promptFileName, promptValues, cr));
          experimentResults.add(createExperiment(
              er, requestHistory, "FAILURE", "Failure Parsing JSON Response"));
          await logRequestAndResponse(requestBody, responseBody, dataDir, er);
          await writeMetrics(responseBody, promptFileName, metricsFile);
          await writeExperimentsReport(experimentReport, reportDir);
          rethrow;
        }
        requestHistory.add(createAssistantHistory(
            content, responseBody, promptFileName, promptValues, cr));
        await logRequestAndResponse(requestBody, responseBody, dataDir, er);
        await writeMetrics(responseBody, promptFileName, metricsFile);
      }
    }
    experimentResults.add(createExperiment(er, requestHistory, "OK", null));
  }
  await writeExperimentsReport(experimentReport, reportDir);
  print("Finished Experiment Run");
}

void addPromptValues(content, responseFormat, promptValues, fixJson) {
  try {
    addJsonContentToPromptValues(content, responseFormat, promptValues);
  } catch (e) {
    if (!fixJson) {
      rethrow;
    }
    final fixedJson = extractJson(content);
    if (fixedJson != null) {
      addJsonContentToPromptValues(fixedJson, responseFormat, promptValues);
    } else {
      rethrow;
    }
  }
}

void addJsonContentToPromptValues(jsonContent, responseFormat, promptValues) {
  try {
    final newValues = jsonDecode(jsonContent);
    promptValues.addAll(newValues);
  } catch (e) {
    throw Exception("Malformed JSON. Failing Experiment.");
  }
}

Map<String, dynamic> createAssistantMessage(content) {
  return {"role": "assistant", "content": content};
}

Map<String, dynamic> createUserMessage(prompt) {
  return {"role": "user", "content": prompt};
}

Map<String, dynamic> createAssistantHistory(
    content, responseBody, promptFile, promptValues, chainRun) {
  final usage = responseBody["usage"];
  return {
    "role": "assistant",
    "content": content,
    "promptFile": promptFile,
    "chainRun": chainRun,
    "completionTokens": usage['completion_tokens'],
    "totalTokens": usage['total_tokens'],
    "promptValues": Map.from(promptValues)
  };
}

Map<String, dynamic> createUserHistory(
    prompt, responseBody, promptFile, promptValues, chainRun) {
  final usage = responseBody["usage"];
  return {
    "role": "user",
    "content": prompt,
    "promptFile": promptFile,
    "chainRun": chainRun,
    "promptTokens": usage['prompt_tokens'],
    "promptValues": Map.from(promptValues)
  };
}

Map<String, dynamic> createUserErrorHistory(
    prompt, responseBody, promptFile, promptValues, errorCode) {
  return {
    "role": "user",
    "content": prompt,
    "promptFile": promptFile,
    "promptValues": Map.from(promptValues),
    "errorCode": errorCode
  };
}

List<Map<String, dynamic>> createSystemMessage(systemMessage) {
  return systemMessage != null
      ? [
          {"role": "system", "content": systemMessage}
        ]
      : [];
}

Future<Map<String, dynamic>> sendHttpPostRequest(requestBody, apiKey) async {
  print("Making call to OpenAi");
  final headers = {
    "Authorization": "Bearer $apiKey",
    "Content-Type": "application/json",
  };

  try {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: requestBody,
    );
    final endTime = DateTime.now().millisecondsSinceEpoch;
    if (response.statusCode == 200) {
      print('Request successful.');
    } else {
      print('Request failed with status code: ${response.statusCode}');
      return {"errorCode": response.statusCode};
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

Map<String, dynamic> createExperiment(
    run, requestHistory, result, String? message) {
  final response = {
    "experimentRun": run,
    "requestHistory": requestHistory,
    "result": result
  };
  if (message != null) {
    response["message"] = message;
  }
  return response;
}
