part of gpt_plugins;

class BatchGptPlugin extends GptPlugin {
  BatchGptPlugin(super.projectConfig, super.block, super.io);

  late Map<String, dynamic> batchData;

  late String promptTemplate;

  late Map<String, dynamic> requestParams;

  late String? systemMessage;

  @override
  num apiCallCount() {
    return batchData[batchData.keys.first].length;
  }

  @override
  Future<void> init(execution, pluginConfiguration) async {
    requestParams = Map.from(pluginConfiguration["requestParams"]);
    final promptFile = execution["prompt"];
    promptTemplate = await io.readFileAsString(promptFile);
    String? systemMessageFile = execution['systemMessageFile'];
    systemMessage = systemMessageFile != null
        ? await io.readFileAsString(systemMessageFile)
        : null;
    final dataFile = execution["dataFile"];
    batchData = await readJsonFile(dataFile);
  }

  @override
  Future<void> doExecution(results, dryRun) async {
    final dataSize = batchData[batchData.keys.first].length;
    for (int i = 0; i < dataSize; i++) {
      final messageHistory = MessageHistory(systemMessage);
      final prompt = createPromptByIndex(promptTemplate, batchData, i);
      messageHistory.addUserMessage(prompt);
      requestParams['messages'] = messageHistory.history;
      final responseBody =
          await makeChatCompletionRequest(requestParams, dryRun);
      if (dryRun) {
        continue;
      }
      if (responseBody['errorCode'] != null) {
        throw Exception("Failed Request: ${responseBody['errorCode']}");
      }
      final result = {
        "input": buildObject(batchData, i),
        "output": responseBody["choices"][0]["message"]["content"]
      };
      results.add(result);
    }
  }

  Future<Map<String, dynamic>> makeChatCompletionRequest(
      requestBody, dryRun) async {
    return sendHttpPostRequest(requestBody, "v1/chat/completions", dryRun);
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
