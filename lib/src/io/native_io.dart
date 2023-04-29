import 'dart:convert';
import 'dart:io';

import 'io.dart';

class NativeIO implements IO {
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

  Future<String> readFileAsString(String filePath) async {
    File file = File(filePath);
    try {
      String content = await file.readAsString();
      return content;
    } catch (e) {
      throw Exception('Error occurred while reading file: $e');
    }
  }

  Future<void> writeMap(Map<String, dynamic> data, String filePath) async {
    File file = File(filePath);
    try {
      String jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      throw Exception('Error occurred while writing JSON to file: $e');
    }
  }

  Future<void> writeString(String content, String filePath) async {
    final file = File(filePath);
    try {
      await file.writeAsString(content, flush: true);
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
}
