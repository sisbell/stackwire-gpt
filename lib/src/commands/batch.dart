import 'dart:convert';

import 'package:gpt/src/commands/experiment.dart';
import 'package:gpt/src/gpt_command.dart';

import '../gpt_client.dart';
import '../prompts.dart';

class BatchGptCommand extends GptCommand {
  BatchGptCommand(super.projectConfig, super.reporter, super.io);

  Future<void> run() async {
    final aiConfig = projectConfig["aiConfig"];
    final projectRuns = projectConfig["projectRuns"];
    final data = projectConfig["data"];
    final promptTemplate = projectConfig["promptTemplate"];
    final systemMessage = projectConfig['systemMessage'];
    final results = [];
    final dataSize = data[data.keys.first].length;
    for (var projectRun = 1; projectRun <= projectRuns; projectRun++) {
      print("Project Run: $projectRun");
      for (int i = 0; i < dataSize; i++) {
        final messageHistory = MessageHistory(systemMessage);
        final prompt = createPromptByIndex(promptTemplate, data, i);
        messageHistory.addUserMessage(prompt);
        aiConfig['messages'] = messageHistory.history;
        final requestBody = jsonEncode(aiConfig);
        final responseBody =
            await makeChatCompletionRequest(requestBody, apiKey);
        if (responseBody['errorCode'] != null) {
          throw Exception("Failed Request: ${responseBody['errorCode']}");
        }
        await reporter.logRequestAndResponse(
            requestBody, responseBody, dataDir, projectRun);
        final result = {
          "input": buildObject(data, i),
          "output": responseBody["choices"][0]["message"]["content"]
        };
        results.add(result);
      }
      await reporter.writeResultsTo({
        "projectName": projectName,
        "projectVersion": projectVersion,
        "results": results
      }, reportDir);
      print("Finished Batch Run");
    }
  }
}

Map<String, String> buildObject(inputMap, int index) {
  Map<String, String> result = {};

  inputMap.forEach((key, valueList) {
    if (index >= 0 && index < valueList.length) {
      result[key] = valueList[index];
    } else {
      throw ArgumentError('Index out of range');
    }
  });

  return result;
}
