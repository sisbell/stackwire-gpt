library gpt_plugins;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file/local.dart' show LocalFileSystem;
import 'package:gpt/src/reporter.dart';
import 'package:http/http.dart' as http;

import 'file_system.dart';
import 'prompts.dart';

part "plugins/batch_plugin.dart";

part "plugins/experiment_plugin.dart";

part "plugins/image_plugin.dart";

part "plugins/reporting_plugin.dart";

abstract class GptPlugin {
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
  late Reporter reporter;
  late IOFileSystem fileSystem;

  GptPlugin(this._projectConfig, this.block) {
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
    fileSystem = IOFileSystem(fileSystem: LocalFileSystem());
    reporter = ConcreteReporter(fileSystem);
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
    if (!dryRun &&
        blockResults.isNotEmpty &&
        blockResults.first["blockResults"].isNotEmpty) {
      await writeProjectReport({
        "projectName": projectName,
        "projectVersion": projectVersion,
        "blockId": blockId,
        "configuration": pluginConfiguration,
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
    fileSystem.createDirectoryIfNotExist(directory);
  }

  Future<void> logFailedRequest(requestBody) async {
    final toDirectory = "$blockDataDir/$currentBlockRun";
    await reporter.logFailedRequest(requestBody, toDirectory);
  }

  Future<void> logRequestAndResponse(requestBody, responseBody) async {
    final toDirectory = "$blockDataDir/$currentBlockRun";
    await reporter.logRequestAndResponse(
        requestBody, responseBody, toDirectory);
  }

  Future<void> writeProjectReport(results, reportDir) async {
    await reporter.writeProjectReport(results, reportDir);
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
    String jsonString = await fileSystem.readFileAsString(filePath);
    return jsonDecode(jsonString);
  }

  Future<String> readResponse(HttpClientResponse response) async {
    return response.transform(utf8.decoder).join();
  }

  Future<void> writeMetrics(responseBody, executionId, tag) async {
    await reporter.writeMetrics(responseBody, executionId, tag, metricsFile);
  }
}
