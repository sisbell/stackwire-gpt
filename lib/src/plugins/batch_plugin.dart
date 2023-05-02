part of gpt_plugins;

class BatchGptPlugin extends GptPlugin {
  BatchGptPlugin(
      super.projectConfig, super.executionBlock, super.reporter, super.io);

  @override
  Future<void> doExecution(
      execution, pluginConfiguration, results, blockRun) async {
    final requestParams = Map.from(pluginConfiguration["requestParams"]);
    final promptFile = execution["prompt"];
    final promptTemplate = await io.readFileAsString(promptFile);
    String? systemMessageFile = execution['systemMessageFile'];
    final systemMessage = systemMessageFile != null
        ? await io.readFileAsString(systemMessageFile)
        : null;
    final dataFile = execution["dataFile"];
    Map<String, dynamic> data = await readJsonFile(dataFile);
    final dataSize = data[data.keys.first].length;
    for (int i = 0; i < dataSize; i++) {
      final messageHistory = MessageHistory(systemMessage);
      final prompt = createPromptByIndex(promptTemplate, data, i);
      messageHistory.addUserMessage(prompt);
      requestParams['messages'] = messageHistory.history;
      final requestBody = jsonEncode(requestParams);
      final responseBody = await makeChatCompletionRequest(requestBody, apiKey);
      if (responseBody['errorCode'] != null) {
        throw Exception("Failed Request: ${responseBody['errorCode']}");
      }
      await reporter.logRequestAndResponse(
          requestBody, responseBody, blockDataDir, blockRun);
      final result = {
        "input": buildObject(data, i),
        "output": responseBody["choices"][0]["message"]["content"]
      };
      results.add(result);
    }
    print("Finished Run");
  }

  Future<Map<String, dynamic>> readJsonFile(String filePath) async {
    String jsonString = await io.readFileAsString(filePath);
    return jsonDecode(jsonString);
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
