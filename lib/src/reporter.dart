import 'dart:convert';
import 'dart:io';

import 'io_helper.dart';

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
  IOHelper ioHelper;

  ConcreteReporter(this.ioHelper);

  @override
  Future<void> logRequestAndResponse(
      requestBody, responseBody, toDirectory) async {
    await ioHelper.createDirectoryIfNotExist(toDirectory);
    final responseId = responseBody["id"] ?? "";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputRequestFile =
        "$toDirectory/$timestamp-$responseId-request.json";
    final outputResponseFile =
        "$toDirectory/$timestamp-$responseId-response.json";
    await ioHelper.writeString(requestBody, outputRequestFile);
    await ioHelper.writeString(jsonEncode(responseBody), outputResponseFile);
  }

  @override
  Future<void> logFailedRequest(requestBody, toDirectory) async {
    await ioHelper.createDirectoryIfNotExist(toDirectory);
    final responseId = "failed";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await ioHelper.writeString(
        requestBody, "$toDirectory/$timestamp-$responseId-request.json");
  }

  @override
  Future<void> writeProjectReport(results, reportDir) async {
    await ioHelper.createDirectoryIfNotExist(reportDir);
    final projectName = results["projectName"];
    final projectVersion = results["projectVersion"];
    final blockId = results["blockId"];
    final fileName = "$projectName-$projectVersion-$blockId-report.json";
    print("Writing project report: $reportDir/$fileName");
    await ioHelper.writeMap(results, "$reportDir/$fileName");
  }

  @override
  Future<void> writeMetrics(responseBody, executionId, tag, metricsFile) async {
    final responseId = responseBody["id"] ?? "N/A";
    final usage = responseBody["usage"];
    final promptTokens = usage?['prompt_tokens'] ?? 0;
    final completionTokens = usage?['completion_tokens'] ?? 0;
    final totalTokens = usage?['total_tokens'] ?? 0;

    final file = ioHelper.file(metricsFile);
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
      throw FileSystemException(
          'Error occurred while writing file: $e', file.path);
    }
  }
}
