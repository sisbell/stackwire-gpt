library gpt_plugins;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:gpt/src/network_client.dart';
import 'package:gpt/src/reporter.dart';
import 'package:http/http.dart';

import 'io_helper.dart';
import 'prompts.dart';

part "plugins/batch_plugin.dart";
part "plugins/experiment_plugin.dart";
part "plugins/image_plugin.dart";
part "plugins/reporting_plugin.dart";

abstract class GptPlugin {
  Map<String, dynamic> _projectConfig;
  Map<String, dynamic> block;
  late FileSystem fileSystem;
  late NetworkClient networkClient;

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
  late IOHelper ioHelper;

  GptPlugin(this._projectConfig, this.block,
      {FileSystem? fileSystem,
      NetworkClient? networkClient}) {
    this.fileSystem = fileSystem ?? LocalFileSystem();

    outputDir = _projectConfig["outputDir"];
    projectName = _projectConfig["projectName"];
    projectVersion = _projectConfig["projectVersion"];
    reportDir = _projectConfig["reportDir"];
    dataDir = _projectConfig["dataDir"];
    blockId = block["blockId"];
    pluginName = block["pluginName"];
    blockDataDir = "$dataDir/$blockId";
    metricsFile = "$reportDir/metrics-$blockId.csv";

    ioHelper = IOHelper(fileSystem: this.fileSystem);
    reporter = ConcreteReporter(ioHelper);
    final apiKey = _projectConfig["apiKey"];
    this.networkClient =
        networkClient ?? NetworkClient(apiKey, reporter, fileSystem!, Client());
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
    await ioHelper.createDirectoryIfNotExist(blockDataDir);
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
      await reporter.writeProjectReport({
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

  Future<void> writeMetrics(responseBody, executionId, tag) async {
    await reporter.writeMetrics(responseBody, executionId, tag, metricsFile);
  }
}
