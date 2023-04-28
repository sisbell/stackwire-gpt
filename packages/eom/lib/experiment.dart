import 'dart:convert';

import 'chat_client.dart';
import 'prompts.dart';

Future<void> runExperiment(
    Map<String, dynamic> experimentConfig, aiConfig, reporter) async {
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

  final experimentResults = ExperimentResults(experimentName);
  print("$experimentRuns $chainRuns");
  for (var experimentRun = 1;
      experimentRun <= experimentRuns;
      experimentRun++) {
    print("Experiment Run: $experimentRun");
    var promptValues = Map.from(promptProperties);
    final messageHistory = MessageHistory(systemMessage);
    for (var chainRun = 1; chainRun <= chainRuns; chainRun++) {
      print("Chain Run: $chainRun");
      for (int i = 0; i < promptTemplates.length; i++) {
        var promptFileName = promptChains[i];
        var promptTemplate = promptTemplates[i];
        final prompt = await createPrompt(promptTemplate, promptValues);
        if (excludesMessageHistory.contains(promptFileName)) {
          aiConfig['messages'] = [{"role": "user", "content": prompt}];
        } else {
          messageHistory.addUserMessage(prompt);
          aiConfig['messages'] = messageHistory.history;
        }
        final requestBody = jsonEncode(aiConfig);
        final responseBody = await sendHttpPostRequest(requestBody, apiKey);
        if (responseBody['errorCode'] != null) {
          await reporter.logFailedRequest(requestBody, dataDir, experimentRun);
          experimentResults.addExperimentResult(experimentRun, "FAILURE",
              "Failed Request: ${responseBody['errorCode']}");
          await reporter.writeResultsTo(experimentResults.experimentReport, reportDir);
          throw Exception("Failed Request: ${responseBody['errorCode']}");
        }
        experimentResults.addUserHistory(
            prompt, responseBody, promptFileName, promptValues, chainRun);

        final content = responseBody["choices"][0]["message"]["content"];
        if (!excludesMessageHistory.contains(promptFileName)) {
          messageHistory.addAssistantMessage(content);
        }

        try {
          if (responseFormat == "json") {
            addPromptValues(content, responseFormat, promptValues, fixJson);
          }
        } catch (e) {
          print(e);
          experimentResults.addAssistantHistory(
              content, responseBody, promptFileName, promptValues, chainRun);
          experimentResults.addExperimentResult(
              experimentRun, "FAILURE", "Failure Parsing JSON Response");
          await reporter.logRequestAndResponse(
              requestBody, responseBody, dataDir, experimentRun);
          await reporter.writeMetrics(
              responseBody, promptFileName, metricsFile);
          await reporter.writeResultsTo(experimentResults.experimentReport, reportDir);
          rethrow;
        }
        experimentResults.addAssistantHistory(
            content, responseBody, promptFileName, promptValues, chainRun);
        await reporter.logRequestAndResponse(
            requestBody, responseBody, dataDir, experimentRun);
        await reporter.writeMetrics(responseBody, promptFileName, metricsFile);
      }
    }
    experimentResults.addExperimentResult(experimentRun, "OK", null);
  }
  await reporter.writeResultsTo(experimentResults.experimentReport, reportDir);
  print("Finished Experiment Run");
}

class MessageHistory {
  List<Map<String, dynamic>> history = [];

  MessageHistory(systemMessage) {
    if (systemMessage != null) {
      history.add({"role": "system", "content": systemMessage});
    }
  }

  void addAssistantMessage(content) {
    history.add(_createAssistantMessage(content));
  }

  void addUserMessage(prompt) {
    history.add(_createUserMessage(prompt));
  }

  Map<String, dynamic> _createAssistantMessage(content) {
    return {"role": "assistant", "content": content};
  }

  Map<String, dynamic> _createUserMessage(prompt) {
    return {"role": "user", "content": prompt};
  }
}

class ExperimentResults {
  late Map<String, dynamic> experimentReport;

  List<Map<String, dynamic>> requestHistory = [];

  ExperimentResults(experimentName) {
    experimentReport = {
      "experimentName": experimentName,
      "experimentResults": []
    };
  }

  void addAssistantHistory(
      content, responseBody, promptFileName, promptValues, cr) {
    requestHistory.add(createAssistantHistory(
        content, responseBody, promptFileName, promptValues, cr));
  }

  void addExperimentResult(experimentRun, result, message) {
    experimentReport["experimentResults"].add(
        createExperimentResult(experimentRun, result, message));
  }

  void addUserHistory(prompt, responseBody, promptFileName, promptValues, cr) {
    requestHistory.add(createUserHistory(
        prompt, responseBody, promptFileName, promptValues, cr));
  }

  Map<String, dynamic> createExperimentResult(run, result, String? message) {
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
}
