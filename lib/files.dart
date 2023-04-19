import 'dart:convert';
import 'dart:io';

Future<void> writeMap(Map<String, dynamic> data, String filePath) async {
  File file = File(filePath);
  try {
    String jsonString = jsonEncode(data);
    await file.writeAsString(jsonString);
  } catch (e) {
    throw Exception('Error occurred while writing JSON to file: $e');
  }
}

Future<Map<String, dynamic>> readExperimentFile(String filePath) async {
  String jsonString = await readFileAsString(filePath);
  return jsonDecode(jsonString);
}

Future<String> readFileAsString(String filePath) async {
  File file = File(filePath);
  try {
    String content = await file.readAsString();
    return content;
  } catch (e) {
    throw Exception('Error occurred while reading file: $e');
  }
}

Future<void> writeResponseAsText(experimentName, responseBody,  reportDir, experimentRuns, chainRun) async {
  final responseId = responseBody["id"];
  final textResponseBuffer = StringBuffer();
  textResponseBuffer.writeln("$experimentName");
  final content = responseBody["choices"][0]["message"]["content"];
  textResponseBuffer.writeln("Experiment Run: $experimentRuns, Chain Run: $chainRun");
  textResponseBuffer.writeln(content);
  textResponseBuffer.writeln("------");
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  writeString(textResponseBuffer.toString(), "$reportDir/$timestamp-$responseId-text.txt");
}

Future<void> writeRequestAndResponseAsJson( requestBody, responseBody, reportDir) async {
  final responseId = responseBody["id"];
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  writeString(requestBody, "$reportDir/$timestamp-$responseId-request.json");
  writeString(jsonEncode(responseBody), "$reportDir/$timestamp-$responseId-response.json");
}

Future<void> writeMetrics(responseBody, promptFileName, filePath) async {
  final responseId = responseBody["id"];
  final usage = responseBody["usage"];
  final promptTokens = usage['prompt_tokens'];
  final completionTokens = usage['completion_tokens'];
  final totalTokens = usage['total_tokens'];

  final file = File(filePath);
  bool exists = await file.exists();
  if(!exists) {
    await file.writeAsString("request_id, prompt_name, request_time, prompt_tokens, completion_tokens, total_tokens\n");
  }
  final sink = File(filePath).openWrite(mode: FileMode.append);
  try {
    final requestTime = responseBody['requestTime'];
    sink.write("$responseId, $promptFileName, $requestTime, $promptTokens, $completionTokens, $totalTokens\n");
  } catch (e) {
    throw Exception('Error occurred while writing file: $e');
  } finally {
    sink.close();
  }
}

Future<void> writeCalculatedPrompt(String content, String filePath, experimentRuns, chainRun) async {
  final sink = File(filePath).openWrite(mode: FileMode.append);
  try {
    sink.writeln("Experiment Run: $experimentRuns, Chain Run: $chainRun");
    sink.writeln(content);
    sink.writeln("-----");
  } catch (e) {
    throw Exception('Error occurred while writing file: $e');
  } finally {
    sink.close();
  }
}

Future<void> writeString(String content, String filePath) async {
  final file = File(filePath);
  try {
    file.writeAsString(content, flush: true);
  } catch (e) {
    throw Exception('Error occurred while writing file: $e');
  }
}

void createDirectoryIfNotExist(String dirName) {
  Directory directory = Directory(dirName);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
    print('Directory $dirName created.');
  }
}
