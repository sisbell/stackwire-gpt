part of gpt_plugins;

class ExperimentGptPlugin extends GptPlugin {
  ExperimentGptPlugin(
      super.projectConfig, super.executionBlock, super.reporter, super.io);

  @override
  Future<void> doExecution(
      execution, pluginConfiguration, results, blockRun) async {
    final requestParams = Map.from(pluginConfiguration["requestParams"]);
    final chainRuns = execution['chainRuns'] ?? 1;
    final fixJson = execution["fixJson"] ?? false;
    String? systemMessageFile = execution['systemMessageFile'];
    final systemMessage = systemMessageFile != null
        ? await io.readFileAsString(systemMessageFile)
        : null;
    List<dynamic> promptChain = execution['promptChain'];
    List<Future<String>> futurePrompts =
        promptChain.map((e) async => await io.readFileAsString(e)).toList();
    List<String> promptTemplates = await Future.wait(futurePrompts);
    final excludesMessageHistory = execution["excludesMessageHistory"] ?? [];
    var promptValues = Map.from(execution['properties'] ?? {});
    final responseFormat = execution['responseFormat'] ?? "text";
    final metricsFile = "$reportDir/metrics-$blockId.csv";
    final messageHistory = MessageHistory(systemMessage);
    for (var chainRun = 1; chainRun <= chainRuns; chainRun++) {
      print("Chain Run: $chainRun");
      for (int i = 0; i < promptTemplates.length; i++) {
        var promptFileName = promptChain[i];
        var promptTemplate = promptTemplates[i];
        final prompt = createPrompt(promptTemplate, promptValues);
        if (excludesMessageHistory.contains(promptFileName)) {
          requestParams['messages'] = [
            {"role": "user", "content": prompt}
          ];
        } else {
          messageHistory.addUserMessage(prompt);
          requestParams['messages'] = messageHistory.history;
        }
        final requestBody = jsonEncode(requestParams);
        final responseBody =
            await makeChatCompletionRequest(requestBody, apiKey);
        if (responseBody['errorCode'] != null) {
          await reporter.logFailedRequest(requestBody, blockDataDir, blockRun);
          results.add(createExperimentResult(
              "FAILURE", "Failed Request: ${responseBody['errorCode']}"));
          throw Exception("Failed Request: ${responseBody['errorCode']}");
        }
        results.add(createUserHistory(
            prompt, responseBody, promptFileName, promptValues, chainRun));
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
          results.add(createAssistantHistory(
              content, responseBody, promptFileName, promptValues, chainRun));
          results.add(createExperimentResult(
              "FAILURE", "Failure Parsing JSON Response"));
          await reporter.logRequestAndResponse(
              requestBody, responseBody, blockDataDir, blockRun);
          await reporter.writeMetrics(
              responseBody, promptFileName, metricsFile);
          rethrow;
        }
        results.add(createAssistantHistory(
            content, responseBody, promptFileName, promptValues, chainRun));
        await reporter.logRequestAndResponse(
            requestBody, responseBody, blockDataDir, blockRun);
        await reporter.writeMetrics(responseBody, promptFileName, metricsFile);
      }
    }
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

  Map<String, dynamic> createExperimentResult(result, String? message) {
    return {"result": result, "message": message};
  }
}
