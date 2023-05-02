library gpt_plugins;

import 'dart:async';
import 'dart:convert';

import 'gpt_client.dart';
import 'io/io.dart';
import 'prompts.dart';
import 'reporter.dart';

part "plugins/batch_plugin.dart";

part "plugins/experiment_plugin.dart";

part "plugins/image_plugin.dart";

abstract class GptPlugin {
  IO io;
  Map<String, dynamic> _projectConfig;
  Map<String, dynamic> block;
  Reporter reporter;
  late String apiKey;
  late String dataDir;
  late String outputDir;
  late String projectName;
  late String projectVersion;
  late String reportDir;
  late String blockDataDir;
  late String blockId;

  GptPlugin(this._projectConfig, this.block, this.reporter, this.io) {
    apiKey = _projectConfig["apiKey"];
    outputDir = _projectConfig["outputDir"];
    projectName = _projectConfig["projectName"];
    projectVersion = _projectConfig["projectVersion"];
    reportDir = _projectConfig["reportDir"];
    dataDir = _projectConfig["dataDir"];
    blockId = block["blockId"];
    blockDataDir = "$dataDir/$blockId";
  }

  Future<void> init() async {}

  Future<void> execute() async {
    final pluginConfiguration = block["configuration"];
    final blockRuns = pluginConfiguration["blockRuns"] ?? 1;
    print(block);
    createDirectoryIfNotExist(blockDataDir);
    final blockResults = [];
    for (var blockRun = 1; blockRun <= blockRuns; blockRun++) {
      final results = [];
      final executions = block["executions"];
      for (var i = 0; i < executions.length; i++) {
        final execution = executions[i];
        await doExecution(execution, pluginConfiguration, results, blockRun);
      }
      final blockResult = {"blockRun": blockRun, "blockResults": results};
      blockResults.add(blockResult);
    }
    await reporter.writeResultsTo({
      "projectName": projectName,
      "projectVersion": projectVersion,
      "blockId": blockId,
      "blockRuns": blockResults
    }, reportDir);
  }

  Future<void> doExecution(
      execution, pluginConfiguration, results, blockRun) async {}

  void createDirectoryIfNotExist(directory) {
    io.createDirectoryIfNotExist(directory);
  }
}
