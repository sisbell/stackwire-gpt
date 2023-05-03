part of gpt_plugins;

class ExperimentGptPlugin extends GptPlugin {
  ExperimentGptPlugin(super.projectConfig, super.block, super.io);

  late int chainRuns;

  late List<dynamic> excludesMessageHistory;

  late bool fixJson;

  late String metricsFile;

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
    requestParams = Map.from(pluginConfiguration["requestParams"]);
    chainRuns = execution['chainRuns'] ?? 1;
    fixJson = execution["fixJson"] ?? false;
    String? systemMessageFile = execution['systemMessageFile'];
    systemMessage = systemMessageFile != null
        ? await io.readFileAsString(systemMessageFile)
        : null;
    promptChain = execution['promptChain'];
    List<Future<String>> futurePrompts =
        promptChain.map((e) async => await io.readFileAsString(e)).toList();
    promptTemplates = await Future.wait(futurePrompts);
    excludesMessageHistory = execution["excludesMessageHistory"] ?? [];
    promptValues = Map.from(execution['properties'] ?? {});
    responseFormat = execution['responseFormat'] ?? "text";
    metricsFile = "$reportDir/metrics-$blockId.csv";
  }

  @override
  Future<void> doExecution(results, dryRun) async {
    final messageHistory = MessageHistory(systemMessage);
    for (var chainRun = 1; chainRun <= chainRuns; chainRun++) {
      print("\nChain Run: $chainRun");
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
        final responseBody =
            await makeChatCompletionRequest(requestParams, dryRun);
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
            addPromptValues(content, responseFormat, promptValues, fixJson);
          }
        } catch (e) {
          print(e);
          results.add(createAssistantHistory(
              content, responseBody, promptFileName, promptValues, chainRun));
          results.add(createExperimentResult(
              "FAILURE", "Failure Parsing JSON Response"));
          rethrow;
        } finally {
          await writeMetrics(responseBody, promptFileName, metricsFile);
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
      requestBody, dryRun) async {
    return sendHttpPostRequest(requestBody, "v1/chat/completions", dryRun);
  }

  Future<void> writeMetrics(responseBody, promptFileName, filePath) async {
    final responseId = responseBody["id"];
    final usage = responseBody["usage"];
    final promptTokens = usage['prompt_tokens'];
    final completionTokens = usage['completion_tokens'];
    final totalTokens = usage['total_tokens'];

    final file = File(filePath);
    bool exists = await file.exists();
    if (!exists) {
      await file.writeAsString(
          "request_id, prompt_name, request_time, prompt_tokens, completion_tokens, total_tokens\n");
    }
    final sink = File(filePath).openWrite(mode: FileMode.append);
    try {
      final requestTime = responseBody['requestTime'];
      sink.write(
          "$responseId, $promptFileName, $requestTime, $promptTokens, $completionTokens, $totalTokens\n");
    } catch (e) {
      throw Exception('Error occurred while writing file: $e');
    } finally {
      sink.close();
    }
  }
}
