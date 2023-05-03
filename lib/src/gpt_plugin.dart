library gpt_plugins;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  }

  num apiCallCount() {
    return 0;
  }

  Future<void> init(execution, pluginConfiguration) async {}

  Future<void> report(results) async {}

  Future<num> apiCallCountForBlock() async {
    num result = 0;
    final pluginConfiguration = block["configuration"];
    final blockRuns = pluginConfiguration["blockRuns"] ?? 1;
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
    blockRuns = pluginConfiguration["blockRuns"] ?? 1;
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
      requestBody, urlPath, dryRun) async {
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
        logFailedRequest(requestBodyStr);
        return {"errorCode": response.statusCode};
      }
      Map<String, dynamic> responseBody =
          jsonDecode(await readResponse(response));
      responseBody.addAll({"requestTime": (endTime - startTime)});
      logRequestAndResponse(requestBodyStr, responseBody);
      return responseBody;
    } catch (e) {
      print('Error occurred during the request: $e');
    }
    return {};
  }

  Future<String> readResponse(HttpClientResponse response) async {
    return response.transform(utf8.decoder).join();
  }
}
