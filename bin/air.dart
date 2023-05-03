import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:args/command_runner.dart';
import 'package:gpt/src/gpt_plugin.dart';
import 'package:gpt/src/io/native_io.dart';

final io = NativeIO();

void main(List<String> arguments) async {
  CommandRunner("air", "A command line tool for running GPT commands")
    ..addCommand(RunCommand())
    ..addCommand(CleanCommand())
    ..addCommand(ApiCountCommand())
    ..run(arguments);
}

class ApiCountCommand extends ProjectInitializeCommand {
  @override
  String get description =>
      "Returns the number of OpenApiCalls that would be made";

  @override
  String get name => "count";

  ApiCountCommand() {
    argParser.addOption('projectFile', abbr: 'p');
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

  CleanCommand() {
    argParser.addOption('projectFile', abbr: 'p');
  }

  @override
  Future<void> run() async {
    await super.run();
    Directory directory = Directory(outputDirName);
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
  String get description => "Runs a plugin";

  @override
  String get name => "run";

  RunCommand() {
    argParser.addOption('projectFile', abbr: 'p');
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
  final gptPlugin =
      pluginMirror.newInstance(Symbol(''), [projectConfig, block, io]).reflectee
          as GptPlugin;
  return gptPlugin;
}

abstract class ProjectInitializeCommand extends Command {
  late String outputDirName;

  late Map<String, dynamic> project;

  late Map<String, dynamic> projectConfig;

  late String reportDir;

  late List<dynamic> blocks;

  @override
  Future<void> run() async {
    String projectFile = argResults?['projectFile'] ?? 'project.eom';
    project = await readJsonFile(projectFile);
    final apiKeyFile = project['apiKeyFile'] ?? "api_key";
    final apiKey = await io.readFileAsString(apiKeyFile);
    outputDirName = project['outputDir'] ?? "output";
    final projectName = project["projectName"];
    final projectVersion = project["projectVersion"];
    reportDir = "$outputDirName/$projectName/$projectVersion";
    final dataDir = "$reportDir/data";
    io.createDirectoryIfNotExist(dataDir);

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

  Future<Map<String, dynamic>> readJsonFile(String filePath) async {
    String jsonString = await io.readFileAsString(filePath);
    return jsonDecode(jsonString);
  }
}
