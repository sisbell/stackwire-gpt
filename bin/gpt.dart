import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:gpt/batch.dart';
import 'package:gpt/experiment.dart';
import 'package:gpt/io/native_io.dart';
import 'package:gpt/reporter.dart';

final io = NativeIO();

void main(List<String> arguments) async {
  CommandRunner("gpt", "A command line tool for running GPT commands")
    ..addCommand(BatchCommand())
    ..addCommand(ExperimentCommand())
    ..run(arguments);
}

Future<Map<String, dynamic>> readProjectFile(String filePath) async {
  String jsonString = await io.readFileAsString(filePath);
  return jsonDecode(jsonString);
}

class ExperimentCommand extends Command {
  ExperimentCommand() {
    argParser.addOption('projectFile', abbr: 'p');
    argParser.addOption('id');
  }

  @override
  String get description => "Run an experiment and output metrics.";

  @override
  String get name => "experiment";

  void run() async {
    final reporter = Reporter(io);
    final id = argResults?['id'];
    String projectFile = argResults?['projectFile'] ?? 'project.eom';
    Map<String, dynamic> project = await readProjectFile(projectFile);
    final apiKeyFile = project['api_key_file'] ?? "api_key";
    final apiKey = await io.readFileAsString(apiKeyFile);
    final aiConfig = project["ai_config"];
    final outputDirName = project['output_dir'] ?? "output";
    final projectName = project["project_name"];
    final projectVersion = project["project_version"];
    final experiments = project["experiments"];
    final experiment =
        (id == null) ? experiments[0] : getObjectById(experiments, id);
    Map<String, dynamic> prompts = experiment['prompts'];
    int chainRuns = prompts['chain_runs'] ?? 1;
    String? systemMessageFile = prompts['system_message_file'];
    final systemMessage = systemMessageFile != null
        ? await io.readFileAsString(systemMessageFile)
        : null;
    List<dynamic> promptChain = prompts['chain'];
    List<Future<String>> futurePrompts =
        promptChain.map((e) async => await io.readFileAsString(e)).toList();
    List<String> promptTemplates = await Future.wait(futurePrompts);

    io.createDirectoryIfNotExist("$outputDirName/$projectName/$projectVersion/data");
    io.writeMap(aiConfig, "$outputDirName/$projectName/$projectVersion/config.ai");

    final projectConfig = {
      "apiKey": apiKey,
      "chainRuns": chainRuns,
      "excludesMessageHistory": prompts["excludesMessageHistory"] ?? [],
      "fixJson": prompts["fixJson"] ?? false,
      "outputDir": outputDirName,
      "projectName": projectName,
      "projectVersion": projectVersion,
      "projectRuns": project["project_runs"] ?? 1,
      "promptChains": prompts['chain'],
      "promptProperties": prompts['properties'] ?? {},
      "promptTemplates": promptTemplates,
      "responseFormat": project['response_format'] ?? "text",
      "systemMessage": systemMessage
    };
    await runExperiment(projectConfig, aiConfig, reporter);
  }
}

class BatchCommand extends Command {
  BatchCommand() {
    argParser.addOption('projectFile', abbr: 'p');
    argParser.addOption('id');
  }

  @override
  String get description => "Run batch program";

  @override
  String get name => "batch";

  void run() async {
    final reporter = Reporter(io);

    String projectFile = argResults?['projectFile'] ?? 'project.eom';
    final batchId = argResults?['id'];
    Map<String, dynamic> project = await readProjectFile(projectFile);

    final aiConfig = project["ai_config"];
    final apiKeyFile = project['api_key_file'] ?? "api_key";
    final apiKey = await io.readFileAsString(apiKeyFile);
    final outputDirName = project['output_dir'] ?? "output";
    final projectName = project["project_name"];
    final projectVersion = project["project_version"];
    final batches = project["batches"];
    final batch =
        (batchId == null) ? batches[0] : getObjectById(batches, batchId);
    final promptFile = batch["prompt"];
    final promptTemplate = await io.readFileAsString(promptFile);
    String? systemMessageFile = batch['system_message_file'];
    final systemMessage = systemMessageFile != null
        ? await io.readFileAsString(systemMessageFile)
        : null;
    final dataFile = batch["data_file"];
    Map<String, dynamic> data = await readProjectFile(dataFile);

    io.createDirectoryIfNotExist("$outputDirName/$projectName/$projectVersion/data");
    io.writeMap(aiConfig, "$outputDirName/$projectName/$projectVersion/config.ai");

    final projectConfig = {
      "apiKey": apiKey,
      "data": data,
      "outputDir": outputDirName,
      "projectName": projectName,
      "projectVersion": projectVersion,
      "projectRuns": project["project_runs"] ?? 1,
      "promptTemplate": promptTemplate,
      "systemMessage": systemMessage
    };
    await runBatch(projectConfig, aiConfig, reporter);
  }
}

Map<String, dynamic>? getObjectById(List<dynamic> array, String id) {
  for (Map<String, dynamic> obj in array) {
    if (obj["id"] == id) {
      return obj;
    }
  }
  return null;
}
