import 'dart:convert';
import 'dart:io';

import 'file_system.dart';

abstract class Reporter {
  Future<void> logRequestAndResponse(
    requestBody,
    responseBody,
    toDirectory,
  );

  Future<void> logFailedRequest(requestBody, toDirectory);

  Future<void> writeMetrics(responseBody, executionId, tag, metricsFile);

  Future<void> writeProjectReport(results, reportDir);
}

class ConcreteReporter extends Reporter {
  IOFileSystem ioFileSystem;

  ConcreteReporter(this.ioFileSystem);

  @override
  Future<void> logRequestAndResponse(
      requestBody, responseBody, toDirectory) async {
    await ioFileSystem.createDirectoryIfNotExist(toDirectory);
    final responseId = responseBody["id"] ?? "";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputRequestFile =
        "$toDirectory/$timestamp-$responseId-request.json";
    final outputResponseFile =
        "$toDirectory/$timestamp-$responseId-response.json";
    await ioFileSystem.writeString(requestBody, outputRequestFile);
    await ioFileSystem.writeString(
        jsonEncode(responseBody), outputResponseFile);
  }

  @override
  Future<void> logFailedRequest(requestBody, toDirectory) async {
    await ioFileSystem.createDirectoryIfNotExist(toDirectory);
    final responseId = "failed";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await ioFileSystem.writeString(
        requestBody, "$toDirectory/$timestamp-$responseId-request.json");
  }

  @override
  Future<void> writeProjectReport(results, reportDir) async {
    await ioFileSystem.createDirectoryIfNotExist(reportDir);
    final projectName = results["projectName"];
    final projectVersion = results["projectVersion"];
    final blockId = results["blockId"];
    final fileName = "$projectName-$projectVersion-$blockId-report.json";
    print("Writing project report: $reportDir/$fileName");
    await ioFileSystem.writeMap(results, "$reportDir/$fileName");
  }

  @override
  Future<void> writeMetrics(responseBody, executionId, tag, metricsFile) async {
    final responseId = responseBody["id"] ?? "N/A";
    final usage = responseBody["usage"];
    final promptTokens = usage?['prompt_tokens'] ?? 0;
    final completionTokens = usage?['completion_tokens'] ?? 0;
    final totalTokens = usage?['total_tokens'] ?? 0;

    final file = ioFileSystem.file(metricsFile);
    bool exists = await file.exists();
    if (!exists) {
      await file.writeAsString(
          "request_id, executionId, tag, request_time, prompt_tokens, completion_tokens, total_tokens\n");
    }

    try {
      final requestTime = responseBody['requestTime'];
      final dataToAppend =
          "$responseId, $executionId, $tag, $requestTime, $promptTokens, $completionTokens, $totalTokens\n";
      await file.writeAsString(dataToAppend,
          mode: FileMode.append, flush: true);
    } catch (e) {
      throw FileSystemException('Error occurred while writing file: $e');
    }
  }
}
