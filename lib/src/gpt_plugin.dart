library gpt_plugins;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'io/io.dart';
import 'prompts.dart';

part "plugins/batch_plugin.dart";
part "plugins/experiment_plugin.dart";
part "plugins/image_plugin.dart";

abstract class GptPlugin {
  IO io;
  Map<String, dynamic> _projectConfig;
  Map<String, dynamic> block;
  late String apiKey;
  late String dataDir;
  late String outputDir;
  late String projectName;
  late String projectVersion;
  late String reportDir;
  late String blockDataDir;
  late String blockId;
  late String pluginName;
  late int blockRuns;
  late String metricsFile;
  var currentBlockRun = 0;

  GptPlugin(this._projectConfig, this.block, this.io) {
    apiKey = _projectConfig["apiKey"];
    outputDir = _projectConfig["outputDir"];
    projectName = _projectConfig["projectName"];
    projectVersion = _projectConfig["projectVersion"];
    reportDir = _projectConfig["reportDir"];
    dataDir = _projectConfig["dataDir"];
    blockId = block["blockId"];
    pluginName = block["pluginName"];
    blockDataDir = "$dataDir/$blockId";
    metricsFile = "$reportDir/metrics-$blockId.csv";
  }

  num apiCallCount() {
    return 0;
  }

  Future<void> init(execution, pluginConfiguration) async {}

  Future<void> report(results) async {}

  Future<num> apiCallCountForBlock() async {
    num result = 0;
    final pluginConfiguration = block["configuration"];
    final blockRuns = block["blockRuns"] ?? 1;
    for (var blockRun = 1; blockRun <= blockRuns; blockRun++) {
      final executions = block["executions"];
      for (var i = 0; i < executions.length; i++) {
        final execution = executions[i];
        await init(execution, pluginConfiguration);
        result += apiCallCount();
      }
    }
    return result;
  }

  Future<void> execute(dryRun) async {
    print("Running Project: $projectName-$projectVersion");
    print("BlockId: $blockId, PluginName: $pluginName");
    final startTime = DateTime.now();
    final pluginConfiguration = block["configuration"];
    blockRuns = block["blockRuns"] ?? 1;
    createDirectoryIfNotExist(blockDataDir);
    final blockResults = [];
    for (var blockRun = 1; blockRun <= blockRuns; blockRun++) {
      print("----------\nStarting Block Run: $blockRun");
      currentBlockRun = blockRun;
      final results = [];
      final executions = block["executions"];

      for (var i = 0; i < executions.length; i++) {
        final execution = executions[i];
        await init(execution, pluginConfiguration);
        print(
            "Starting execution: ${i + 1} - Requires ${apiCallCount()} calls to OpenAI");
        await doExecution(results, dryRun);
        if (!dryRun) {
          await report(results);
        }
        print("Finished execution: ${i + 1}\n");
      }
      final blockResult = {"blockRun": blockRun, "blockResults": results};
      blockResults.add(blockResult);
    }
    if (!dryRun) {
      await writeProjectReport({
        "projectName": projectName,
        "projectVersion": projectVersion,
        "blockId": blockId,
        "blockRuns": blockResults
      }, reportDir);
    }
    final endTime = DateTime.now();
    Duration duration = endTime.difference(startTime);
    print(
        "\n--------\nFinished running project: ${duration.inSeconds} seconds");
  }

  Future<void> doExecution(results, dryRun) async {}

  void createDirectoryIfNotExist(directory) {
    io.createDirectoryIfNotExist(directory);
  }

  Future<void> logFailedRequest(requestBody) async {
    final directory = "$blockDataDir/$currentBlockRun";
    io.createDirectoryIfNotExist(directory);
    final responseId = "failed";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await io.writeString(
        requestBody, "$directory/$timestamp-$responseId-request.json");
  }

  Future<void> logRequestAndResponse(requestBody, responseBody) async {
    final directory = "$blockDataDir/$currentBlockRun";
    io.createDirectoryIfNotExist(directory);
    final responseId = responseBody["id"] ?? "";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputRequestFile = "$directory/$timestamp-$responseId-request.json";
    final outputResponseFile =
        "$directory/$timestamp-$responseId-response.json";
    print("\t\tResponse ID:  $responseId");
    await io.writeString(requestBody, outputRequestFile);
    await io.writeString(jsonEncode(responseBody), outputResponseFile);
  }

  Future<void> writeProjectReport(results, reportDir) async {
    final projectName = results["projectName"];
    final projectVersion = results["projectVersion"];
    final blockId = results["blockId"];
    final fileName = "$projectName-$projectVersion-$blockId-report.json";
    print("Writing project report: $reportDir/$fileName");
    await io.writeMap(results, "$reportDir/$fileName");
  }

  Future<Map<String, dynamic>> sendHttpPostRequest(
      requestBody, urlPath, executionId, tag, dryRun) async {
    final requestBodyStr = jsonEncode(requestBody);
    if (dryRun) {
      print("\tPOST to https://api.openai.com/$urlPath");
      print("\t\t$requestBodyStr");
      return {};
    }
    print("\n\tMaking call to OpenAI: $urlPath");
    try {
      final client = HttpClient();
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final request =
          await client.postUrl(Uri.parse("https://api.openai.com/$urlPath"));
      request.headers.add(HttpHeaders.contentTypeHeader, "application/json");
      request.headers.add(HttpHeaders.authorizationHeader, "Bearer $apiKey");
      request.write(requestBodyStr);
      HttpClientResponse response = await request.close();
      final endTime = DateTime.now().millisecondsSinceEpoch;
      print("\t\trequestTime: ${(endTime - startTime)}");
      if (response.statusCode == 200) {
        print('\t\tOpenAI Request successful.');
      } else {
        print(
            '\t\tOpenAI Request failed with status code: ${response.statusCode}');
        print(requestBodyStr);
        logFailedRequest(requestBodyStr);
        return {"errorCode": response.statusCode};
      }
      Map<String, dynamic> responseBody =
          jsonDecode(await readResponse(response));
      responseBody.addAll({"requestTime": (endTime - startTime)});
      logRequestAndResponse(requestBodyStr, responseBody);
      writeMetrics(responseBody, executionId, tag);
      return responseBody;
    } catch (e) {
      print('Error occurred during the request: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> readJsonFile(String filePath) async {
    String jsonString = await io.readFileAsString(filePath);
    return jsonDecode(jsonString);
  }

  Future<String> readResponse(HttpClientResponse response) async {
    return response.transform(utf8.decoder).join();
  }

  Future<void> writeMetrics(responseBody, executionId, tag) async {
    final responseId = responseBody["id"] ?? "N/A";
    final usage = responseBody["usage"];
    final promptTokens = usage?['prompt_tokens'] ?? 0;
    final completionTokens = usage?['completion_tokens'] ?? 0;
    final totalTokens = usage?['total_tokens'] ?? 0;

    final file = File(metricsFile);
    bool exists = await file.exists();
    if (!exists) {
      await file.writeAsString(
          "request_id, executionId, tag, request_time, prompt_tokens, completion_tokens, total_tokens\n");
    }
    final sink = File(metricsFile).openWrite(mode: FileMode.append);
    try {
      final requestTime = responseBody['requestTime'];
      sink.write(
          "$responseId, $executionId, $tag, $requestTime, $promptTokens, $completionTokens, $totalTokens\n");
    } catch (e) {
      throw Exception('Error occurred while writing file: $e');
    } finally {
      sink.close();
    }
  }
}
