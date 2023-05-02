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

  Future<void> init(execution, pluginConfiguration) async {}

  Future<void> report(results) async {}

  Future<void> execute() async {
    print("Running Project: $projectName-$projectVersion");
    print("BlockId: $blockId, PluginName: $pluginName");
    final startTime = DateTime.now();
    final pluginConfiguration = block["configuration"];
    final blockRuns = pluginConfiguration["blockRuns"] ?? 1;
    createDirectoryIfNotExist(blockDataDir);
    final blockResults = [];
    for (var blockRun = 1; blockRun <= blockRuns; blockRun++) {
      print("----------\nStarting Block Run: $blockRun");
      currentBlockRun = blockRun;
      final results = [];
      final executions = block["executions"];

      for (var i = 0; i < executions.length; i++) {
        print("Starting execution: ${i + 1}");
        final execution = executions[i];
        await init(execution, pluginConfiguration);
        await doExecution(results);
        await report(results);
        print("Finished execution: ${i + 1}");
      }
      final blockResult = {"blockRun": blockRun, "blockResults": results};
      blockResults.add(blockResult);
    }
    print("Writing project report");
    await writeProjectReport({
      "projectName": projectName,
      "projectVersion": projectVersion,
      "blockId": blockId,
      "blockRuns": blockResults
    }, reportDir);
    final endTime = DateTime.now();
    Duration duration = endTime.difference(startTime);
    print("Finished running project: ${duration.inSeconds} seconds");
  }

  Future<void> doExecution(results) async {}

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
    await io.writeString(
        requestBody, "$directory/$timestamp-$responseId-request.json");
    await io.writeString(jsonEncode(responseBody),
        "$directory/$timestamp-$responseId-response.json");
  }

  Future<void> writeProjectReport(results, reportDir) async {
    final projectName = results["projectName"];
    final projectVersion = results["projectVersion"];
    final blockId = results["blockId"];
    final fileName = "$projectName-$projectVersion-$blockId-report.json";
    await io.writeMap(results, "$reportDir/$fileName");
  }

  Future<Map<String, dynamic>> sendHttpPostRequest(requestBody, urlPath) async {
    final requestBodyStr = jsonEncode(requestBody);
    print("Making call to OpenAI: $urlPath");
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
      print("requestTime: ${(endTime - startTime)}");
      if (response.statusCode == 200) {
        print('OpenAI Request successful.');
      } else {
        print('OpenAI Request failed with status code: ${response.statusCode}');
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
