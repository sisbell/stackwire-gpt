import 'dart:convert';
import 'dart:mirrors';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:gpt/src/archetypes.dart';
import 'package:gpt/src/file_system.dart';
import 'package:gpt/src/gpt_plugin.dart';
import 'package:gpt/src/prompts.dart';
import 'package:interact/interact.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

final localFileSystem = LocalFileSystem();

final fileSystem = IOFileSystem(fileSystem: localFileSystem);

void main(List<String> arguments) async {
  CommandRunner("air", "A command line tool for running GPT commands")
    ..addCommand(RunCommand())
    ..addCommand(CleanCommand())
    ..addCommand(ApiCountCommand())
    ..addCommand(ArchetypeCommand())
    ..run(arguments);
}

class ArchetypeCommand extends Command {
  @override
  String get description => "Generates a new project";

  @override
  String get name => "genp";

  @override
  void run() async {
    final builder = ArchetypeBuilder(localFileSystem);
    final archetypeDirectory = await builder.downloadArchetypeArchive();
    final archetypeDirectories = {
      "Chain": "chain",
      "Prompt": "prompt",
      "Batch": "batch",
      "Image": "image"
    };
    final projectTypes = ['Prompt', 'Chain', 'Batch', 'Image'];
    final selectedProjectIndex = Select(
      prompt: 'Project Archetype',
      options: projectTypes,
      initialIndex: 0,
    ).interact();
    final projectName = Input(prompt: 'Project Name: ').interact();
    final projectVersion =
        Input(prompt: 'Project Version: ', defaultValue: "1.0").interact();
    final projectSelection = projectTypes[selectedProjectIndex];
    final archetypeName = archetypeDirectories[projectSelection];
    final projectDir = localFileSystem.directory(projectName);
    final sourceDir =
        localFileSystem.directory(path.join(archetypeDirectory, archetypeName));
    await fileSystem.copyDirectoryContents(sourceDir, projectDir);
    Map<String, dynamic> templateProperties = {
      "projectName": projectName,
      "projectVersion": projectVersion
    };

    askImportKey(templateProperties, projectName);

    if (selectedProjectIndex == 0) {
      askBlockRuns(templateProperties);
      askResponseFormat(templateProperties);
    } else if (selectedProjectIndex == 1) {
      //chain
      askBlockRuns(templateProperties);
      askFixJson(templateProperties);
      templateProperties.addAll({"responseFormat": "json"});
      askChainRuns(templateProperties);
    } else if (selectedProjectIndex == 2) {
      askBlockRuns(templateProperties);
    } else if (selectedProjectIndex == 3) {
      askImageDescription(templateProperties);
    }

    print(templateProperties);
    final projectYaml = await builder.readProjectYaml(projectName);
    final calculatedProjectYaml =
        substituteTemplateProperties(projectYaml, templateProperties);
    final isValid = builder.verifyYamlFormat(calculatedProjectYaml);
    if (isValid) {
      await fileSystem.writeString(
          calculatedProjectYaml, "$projectName/project.yaml");
      print("Created Project");
    } else {
      print("Invalid yaml file. Project not created");
    }
  }

  void askBlockRuns(templateProperties) {
    final blockRuns =
        Input(prompt: 'Number of Times to Run The Block: ').interact();
    templateProperties.addAll({"blockRuns": blockRuns});
  }

  void askChainRuns(templateProperties) {
    final blockRuns =
        Input(prompt: 'Number of Times to Run The Prompt Chain: ').interact();
    templateProperties.addAll({"chainRuns": blockRuns});
  }

  void askFixJson(templateProperties) {
    final fixJSONConfirmation = Confirm(
      prompt: 'Attempt to FIX JSON Responses?',
      defaultValue: false,
    ).interact();
    templateProperties.addAll({"fixJson": fixJSONConfirmation.toString()});
  }

  void askImageDescription(templateProperties) {
    final imageDescription = Input(prompt: 'Image Description: ').interact();
    templateProperties.addAll({"imageDescription": imageDescription});
  }

  void askImportKey(templateProperties, projectName) {
    final keyTypes = [
      'Skip',
      'Use Existing OpenAI API Key File',
      'Create New OpenAI API Key File'
    ];
    final selectedKeyIndex = Select(
      prompt: 'Import Key',
      options: keyTypes,
      initialIndex: 0,
    ).interact();

    if (selectedKeyIndex == 1) {
      final keyFile = Input(prompt: 'API Key File: ').interact();
      templateProperties.addAll({"apiKeyFile": keyFile});
    } else if (selectedKeyIndex == 2) {
      final key = Input(prompt: 'API Key: ').interact();
      fileSystem.writeString(key, "$projectName/api_key");
      templateProperties.addAll({"apiKeyFile": "api_key"});
    }
  }

  void askResponseFormat(templateProperties) {
    final outputTypes = ['JSON', 'TEXT'];
    final selectedOutputIndex = Select(
      prompt: 'Response Format',
      options: outputTypes,
      initialIndex: 1,
    ).interact();
    if (selectedOutputIndex == 0) {
      templateProperties.addAll({"responseFormat": "json"});
      templateProperties.addAll({"promptName": "prompt-json.prompt"});
      askFixJson(templateProperties);
    } else {
      templateProperties.addAll({"responseFormat": "text"});
      templateProperties.addAll({"promptName": "prompt-text.prompt"});
      templateProperties.addAll({"fixJson": false.toString()});
    }
  }
}

class ApiCountCommand extends ProjectInitializeCommand {
  @override
  String get description =>
      "Returns the number of OpenApiCalls that would be made";

  @override
  String get name => "count";

  ApiCountCommand() {
    argParser.addOption('blockId', abbr: 'b');
  }

  @override
  Future<void> run() async {
    await super.run();
    num result = 0;
    final blockId = argResults?['blockId'];
    if (blockId != null) {
      final block = getBlockById(blocks, blockId)!;
      result += await apiCallCountForBlock(block);
    } else {
      for (var block in blocks) {
        result += await apiCallCountForBlock(block);
      }
    }
    final projectName = projectConfig["projectName"];
    final projectVersion = projectConfig["projectVersion"];
    print("Project: $projectName-$projectVersion");
    print("Total OpenAPI Calls would be $result");
  }

  Future<num> apiCallCountForBlock(block) async {
    final gptPlugin = getPlugin(block, projectConfig);
    return await gptPlugin.apiCallCountForBlock();
  }

  Map<String, dynamic>? getBlockById(List<dynamic> array, String id) {
    for (Map<String, dynamic> obj in array) {
      if (obj["blockId"] == id) {
        return obj;
      }
    }
    return null;
  }
}

class CleanCommand extends ProjectInitializeCommand {
  @override
  String get description => "Cleans project's output directory";

  @override
  String get name => "clean";

  CleanCommand() {}

  @override
  Future<void> run() async {
    await super.run();
    Directory directory = localFileSystem.directory(outputDirName);
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
      print(
          "Output directory '$outputDirName' and its contents have been deleted.");
    } else {
      print("Output directory '$outputDirName' does not exist.");
    }
  }
}

class RunCommand extends ProjectInitializeCommand {
  @override
  String get description => "Runs a project's blocks";

  @override
  String get name => "run";

  RunCommand() {
    argParser.addOption('blockId', abbr: 'b');
    argParser.addFlag("dryRun", defaultsTo: false);
  }

  @override
  Future<void> run() async {
    await super.run();
    final blockId = argResults?['blockId'];
    final dryRun = argResults?['dryRun'];
    if (blockId != null) {
      final block = getBlockById(blocks, blockId)!;
      await executeBlock(block, dryRun);
    } else {
      for (var block in blocks) {
        print("Executing Block");
        await executeBlock(block, dryRun);
      }
    }
  }

  Future<void> executeBlock(block, dryRun) async {
    final gptPlugin = getPlugin(block, projectConfig);
    await gptPlugin.execute(dryRun);
  }

  Map<String, dynamic>? getBlockById(List<dynamic> array, String id) {
    for (Map<String, dynamic> obj in array) {
      if (obj["blockId"] == id) {
        return obj;
      }
    }
    return null;
  }
}

GptPlugin getPlugin(block, projectConfig) {
  final pluginName = block["pluginName"];
  LibraryMirror libraryMirror =
      currentMirrorSystem().findLibrary(Symbol('gpt_plugins'));
  ClassMirror pluginMirror =
      libraryMirror.declarations[Symbol(pluginName)] as ClassMirror;
  final gptPlugin = pluginMirror
      .newInstance(Symbol(''), [projectConfig, block]).reflectee as GptPlugin;
  return gptPlugin;
}

abstract class ProjectInitializeCommand extends Command {
  late String outputDirName;

  late Map project;

  late Map<String, dynamic> projectConfig;

  late String reportDir;

  late List<dynamic> blocks;

  @override
  Future<void> run() async {
    String projectFile = 'project.yaml';
    project = await readYamlFile(projectFile);
    final apiKeyFile = project['apiKeyFile'] ?? "api_key";
    final apiKey = await fileSystem.readFileAsString(apiKeyFile);
    outputDirName = project['outputDir'] ?? "output";
    final projectName = project["projectName"];
    final projectVersion = project["projectVersion"];
    reportDir = "$outputDirName/$projectName/$projectVersion";
    final dataDir = "$reportDir/data";
    fileSystem.createDirectoryIfNotExist(dataDir);

    blocks = project["blocks"];
    projectConfig = {
      "apiKey": apiKey,
      "dataDir": dataDir,
      "outputDir": outputDirName,
      "projectName": projectName,
      "projectVersion": projectVersion,
      "reportDir": reportDir
    };
  }

  Future<Map<String, dynamic>> readYamlFile(String filePath) async {
    String text = await fileSystem.readFileAsString(filePath);
    final yamlObject = loadYaml(text);
    return jsonDecode(json.encode(yamlObject));
  }
}
