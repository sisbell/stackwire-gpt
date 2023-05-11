part of gpt_plugins;

class ExperimentGptPlugin extends GptPlugin {
  ExperimentGptPlugin(super.projectConfig, super.block);

  late int chainRuns;

  late List<dynamic> excludesMessageHistory;

  late bool fixJson;

  late Map<String, dynamic> importProperties;

  late String executionId;

  late List<String> promptTemplates;

  late List<dynamic> promptChain;

  late Map<String, dynamic> promptValues;

  late Map<String, dynamic> requestParams;

  late String responseFormat;

  late String? systemMessage;

  @override
  num apiCallCount() {
    return chainRuns * promptChain.length;
  }

  @override
  Future<void> init(execution, pluginConfiguration) async {
    executionId = execution["id"];
    requestParams = Map.from(pluginConfiguration["requestParams"]);
    chainRuns = execution['chainRuns'] ?? 1;
    fixJson = execution["fixJson"] ?? false;
    String? systemMessageFile = execution['systemMessageFile'];
    systemMessage = systemMessageFile != null
        ? await fileSystem.readFileAsString(systemMessageFile)
        : null;
    promptChain = execution['promptChain'];
    List<Future<String>> futurePrompts = promptChain
        .map((e) async => await fileSystem.readFileAsString(e))
        .toList();
    promptTemplates = await Future.wait(futurePrompts);
    excludesMessageHistory = execution["excludesMessageHistory"] ?? [];
    final properties = execution['properties'] ?? {};
    responseFormat = execution['responseFormat'] ?? "text";
    final import = execution["import"];
    if (import != null) {
      final propertiesFile = import["propertiesFile"] ?? "properties.json";
      final data = await readJsonFile(propertiesFile);
      final props = import["properties"];
      final calculatedData = getFieldsForAllProperties(data, props);
      promptValues = {...calculatedData, ...properties};
    } else {
      promptValues = Map.from(properties);
    }
  }

  Map<String, String> getFieldAtIndex(Map<String, dynamic> data,
      Map<String, dynamic> properties, String field) {
    if (data.containsKey(field) && properties.containsKey(field)) {
      int index = properties[field]! - 1;
      if (index >= 0 && index < data[field]!.length) {
        return {field: data[field]![index]};
      }
    }
    return {};
  }

  Map<String, String> getFieldsForAllProperties(
      Map<String, dynamic> data, Map<String, dynamic> properties) {
    Map<String, String> result = {};
    for (String key in properties.keys) {
      result.addAll(getFieldAtIndex(data, properties, key));
    }
    return result;
  }

  @override
  Future<void> doExecution(results, dryRun) async {
    final messageHistory = MessageHistory(systemMessage);
    for (var chainRun = 1; chainRun <= chainRuns; chainRun++) {
      print("\nChain Run: $chainRun");
      for (int i = 0; i < promptTemplates.length; i++) {
        var promptFileName = promptChain[i];
        var promptTemplate = promptTemplates[i];
        final prompt =
            substituteTemplateProperties(promptTemplate, promptValues);
        if (excludesMessageHistory.contains(promptFileName)) {
          requestParams['messages'] = [
            {"role": "user", "content": prompt}
          ];
        } else {
          messageHistory.addUserMessage(prompt);
          requestParams['messages'] = messageHistory.history;
        }

        final responseBody = await makeChatCompletionRequest(
            requestParams, executionId, promptFileName, dryRun);
        if (dryRun) {
          continue;
        }
        if (responseBody['errorCode'] != null) {
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
            addPromptValues(content, promptValues, fixJson);
          }
        } catch (e) {
          print(e);
          results.add(createAssistantHistory(
              content, responseBody, promptFileName, promptValues, chainRun));
          results.add(createExperimentResult(
              "FAILURE", "Failure Parsing JSON Response"));
          rethrow;
        }
        results.add(createAssistantHistory(
            content, responseBody, promptFileName, promptValues, chainRun));
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

  Future<Map<String, dynamic>> makeChatCompletionRequest(
      requestBody, executionId, tag, dryRun) async {
    return sendHttpPostRequest(
        requestBody, "v1/chat/completions", executionId, tag, dryRun);
  }
}
