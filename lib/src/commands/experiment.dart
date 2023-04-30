import 'dart:convert';

import 'package:gpt/src/gpt_command.dart';

import '../gpt_client.dart';
import '../prompts.dart';

class ExperimentGptCommand extends GptCommand {
  ExperimentGptCommand(super.projectConfig, super.reporter, super.io);

  Future<void> run() async {
    final aiConfig = projectConfig["aiConfig"];
    final projectRuns = projectConfig["projectRuns"];
    final chainRuns = projectConfig["chainRuns"];
    final excludesMessageHistory = projectConfig["excludesMessageHistory"];
    final fixJson = projectConfig["fixJson"];
    final promptChains = projectConfig["promptChains"];
    final promptProperties = projectConfig["promptProperties"];
    final promptTemplates = projectConfig["promptTemplates"];
    final responseFormat = projectConfig["responseFormat"];
    final systemMessage = projectConfig['systemMessage'];
    final metricsFile = "$reportDir/metrics.csv";

    final experimentResults = ExperimentResults(projectName, projectVersion);
    print("$projectRuns $chainRuns");
    for (var projectRun = 1; projectRun <= projectRuns; projectRun++) {
      print("Project Run: $projectRun");
      var promptValues = Map.from(promptProperties);
      final messageHistory = MessageHistory(systemMessage);
      for (var chainRun = 1; chainRun <= chainRuns; chainRun++) {
        print("Chain Run: $chainRun");
        for (int i = 0; i < promptTemplates.length; i++) {
          var promptFileName = promptChains[i];
          var promptTemplate = promptTemplates[i];
          final prompt = createPrompt(promptTemplate, promptValues);
          if (excludesMessageHistory.contains(promptFileName)) {
            aiConfig['messages'] = [
              {"role": "user", "content": prompt}
            ];
          } else {
            messageHistory.addUserMessage(prompt);
            aiConfig['messages'] = messageHistory.history;
          }
          final requestBody = jsonEncode(aiConfig);
          final responseBody =
              await makeChatCompletionRequest(requestBody, apiKey);
          if (responseBody['errorCode'] != null) {
            await reporter.logFailedRequest(requestBody, dataDir, projectRun);
            experimentResults.addExperimentResult(projectRun, "FAILURE",
                "Failed Request: ${responseBody['errorCode']}");
            await reporter.writeResultsTo(
                experimentResults.experimentReport, reportDir);
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
                projectRun, "FAILURE", "Failure Parsing JSON Response");
            await reporter.logRequestAndResponse(
                requestBody, responseBody, dataDir, projectRun);
            await reporter.writeMetrics(
                responseBody, promptFileName, metricsFile);
            await reporter.writeResultsTo(
                experimentResults.experimentReport, reportDir);
            rethrow;
          }
          experimentResults.addAssistantHistory(
              content, responseBody, promptFileName, promptValues, chainRun);
          await reporter.logRequestAndResponse(
              requestBody, responseBody, dataDir, projectRun);
          await reporter.writeMetrics(
              responseBody, promptFileName, metricsFile);
        }
      }
      experimentResults.addExperimentResult(projectRun, "OK", null);
    }
    await reporter.writeResultsTo(
        experimentResults.experimentReport, reportDir);
    print("Finished Experiment");
  }
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

  ExperimentResults(projectName, projectVersion) {
    experimentReport = {
      "projectName": projectName,
      "projectVersion": projectVersion,
      "experimentResults": []
    };
  }

  void addAssistantHistory(
      content, responseBody, promptFileName, promptValues, cr) {
    requestHistory.add(createAssistantHistory(
        content, responseBody, promptFileName, promptValues, cr));
  }

  void addExperimentResult(experimentRun, result, message) {
    experimentReport["experimentResults"]
        .add(createExperimentResult(experimentRun, result, message));
  }

  void addUserHistory(prompt, responseBody, promptFileName, promptValues, cr) {
    requestHistory.add(createUserHistory(
        prompt, responseBody, promptFileName, promptValues, cr));
  }

  Map<String, dynamic> createExperimentResult(run, result, String? message) {
    final response = {
      "projectRun": run,
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
