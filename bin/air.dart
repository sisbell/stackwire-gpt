import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:gpt/src/commands/batch.dart';
import 'package:gpt/src/commands/experiment.dart';
import 'package:gpt/src/commands/image.dart';
import 'package:gpt/src/io/native_io.dart';
import 'package:gpt/src/prompts.dart';
import 'package:gpt/src/reporter.dart';

final io = NativeIO();

void main(List<String> arguments) async {
  CommandRunner("gpt", "A command line tool for running GPT commands")
    ..addCommand(BatchCommand())
    ..addCommand(ExperimentCommand())
    ..addCommand(ImageCommand())
    ..run(arguments);
}

class ExperimentCommand extends ChatCommand {
  ExperimentCommand() {
    argParser.addOption('projectFile', abbr: 'p');
    argParser.addOption('id');
  }

  @override
  String get description => "Run an experiment and output metrics.";

  @override
  String get name => "experiment";

  @override
  Future<void> run() async {
    await super.run();
    final id = argResults?['id'];
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
    final pluginConfig = {
      "chainRuns": chainRuns,
      "excludesMessageHistory": prompts["excludesMessageHistory"] ?? [],
      "fixJson": prompts["fixJson"] ?? false,
      "promptChains": prompts['chain'],
      "promptProperties": prompts['properties'] ?? {},
      "promptTemplates": promptTemplates,
      "responseFormat": project['response_format'] ?? "text",
      "systemMessage": systemMessage
    };
    projectConfig.addAll(pluginConfig);
    final command = ExperimentGptCommand(projectConfig, reporter, io);
    await command.run();
  }
}

class BatchCommand extends ChatCommand {
  BatchCommand() {
    argParser.addOption('projectFile', abbr: 'p');
    argParser.addOption('id');
  }

  @override
  String get description => "Run batch program";

  @override
  String get name => "batch";

  @override
  Future<void> run() async {
    await super.run();
    final id = argResults?['id'];
    final batches = project["batches"];
    final batch = (id == null) ? batches[0] : getObjectById(batches, id);
    final promptFile = batch["prompt"];
    final promptTemplate = await io.readFileAsString(promptFile);
    String? systemMessageFile = batch['system_message_file'];
    final systemMessage = systemMessageFile != null
        ? await io.readFileAsString(systemMessageFile)
        : null;
    final dataFile = batch["data_file"];
    Map<String, dynamic> data = await readJsonFile(dataFile);
    final pluginConfig = {
      "promptTemplate": promptTemplate,
      "systemMessage": systemMessage
    };
    projectConfig.addAll(pluginConfig);
    final command = BatchGptCommand(projectConfig, reporter, io);
    await command.run();
  }
}

class ImageCommand extends ProjectInitializeCommand {
  ImageCommand() {
    argParser.addOption('projectFile', abbr: 'p');
    argParser.addOption('id');
  }

  @override
  String get description => "Create an Image";

  @override
  String get name => "image";

  @override
  Future<void> run() async {
    await super.run();
    final id = argResults?['id'];
    final images = project["images"];
    final image = (id == null) ? images[0] : getObjectById(images, id);
    final pluginConfig = {"images": await createImageConfig(image)};
    projectConfig.addAll(pluginConfig);
    final command = ImageGptCommand(projectConfig, reporter, io);
    await command.run();
  }
}

Future<List<dynamic>> createImageConfig(image) async {
  final imagePromptFile = image["prompt"];
  final promptTemplate = await io.readFileAsString(imagePromptFile);
  final templateProperties = image["properties"];
  final prompt = createPrompt(promptTemplate, templateProperties);
  final responseFormat = image["response_format"];
  final imageCount = image["image_count"];
  final sizes = image["sizes"];
  final imageConfigs = [];
  for (int size in sizes) {
    final imageConfig = {
      "prompt": prompt,
      "n": imageCount,
      "size": createImageSize(size),
      "response_format": responseFormat
    };
    imageConfigs.add(imageConfig);
  }
  return imageConfigs;
}

String createImageSize(size) {
  if (size == 256) {
    return "256x256";
  } else if (size == 512) {
    return "512x512";
  } else if (size == 1024) {
    return "1024x1024";
  } else {
    throw Exception("Invalid image size: $size");
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

abstract class ChatCommand extends ProjectInitializeCommand {
  @override
  Future<void> run() async {
    await super.run();
    final pluginConfig = {
      "aiConfig": project["ai_config"],
      "projectRuns": project["project_runs"] ?? 1
    };
    projectConfig.addAll(pluginConfig);
    io.writeMap(project["ai_config"], "$reportDir/config.ai");
  }
}

abstract class ProjectInitializeCommand extends Command {
  final reporter = Reporter(io);

  late Map<String, dynamic> project;

  late Map<String, dynamic> projectConfig;

  late String reportDir;

  @override
  Future<void> run() async {
    String projectFile = argResults?['projectFile'] ?? 'project.eom';
    project = await readJsonFile(projectFile);
    final apiKeyFile = project['api_key_file'] ?? "api_key";
    final apiKey = await io.readFileAsString(apiKeyFile);
    final outputDirName = project['output_dir'] ?? "output";
    final projectName = project["project_name"];
    final projectVersion = project["project_version"];
    reportDir = "$outputDirName/$projectName/$projectVersion";
    final dataDir = "$reportDir/data";
    io.createDirectoryIfNotExist(dataDir);

    projectConfig = {
      "apiKey": apiKey,
      "dataDir": dataDir,
      "outputDir": outputDirName,
      "projectName": projectName,
      "projectVersion": projectVersion,
      "reportDir": reportDir
    };
  }

  Future<Map<String, dynamic>> readJsonFile(String filePath) async {
    String jsonString = await io.readFileAsString(filePath);
    return jsonDecode(jsonString);
  }
}
