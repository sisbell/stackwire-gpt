import 'dart:convert';
import 'dart:mirrors';

import 'package:args/command_runner.dart';
import 'package:gpt/src/gpt_plugin.dart';
import 'package:gpt/src/io/native_io.dart';
import 'package:gpt/src/reporter.dart';

final io = NativeIO();

void main(List<String> arguments) async {
  CommandRunner("air", "A command line tool for running GPT commands")
    ..addCommand(RunCommand())
    ..run(arguments);
}

class RunCommand extends ProjectInitializeCommand {
  @override
  String get description => "Runs a plugin";

  @override
  String get name => "run";

  RunCommand() {
    argParser.addOption('projectFile', abbr: 'p');
    argParser.addOption('blockId', abbr: 'b');
  }

  @override
  Future<void> run() async {
    await super.run();
    final blockId = argResults?['blockId'];
    if (blockId != null) {
      final block = getBlockById(blocks, blockId)!;
      await executeBlock(block);
    } else {
      for (var block in blocks) {
        print("Executing Block");
        await executeBlock(block);
      }
    }
  }

  Future<void> executeBlock(block) async {
    final pluginName = block["pluginName"];
    LibraryMirror libraryMirror =
        currentMirrorSystem().findLibrary(Symbol('gpt_plugins'));
    ClassMirror pluginMirror =
        libraryMirror.declarations[Symbol(pluginName)] as ClassMirror;
    final gptPlugin = pluginMirror.newInstance(
            Symbol(''), [projectConfig, block, reporter, io]).reflectee
        as GptPlugin;
    await gptPlugin.init();
    await gptPlugin.execute();
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

abstract class ProjectInitializeCommand extends Command {
  final reporter = Reporter(io);

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
    final outputDirName = project['outputDir'] ?? "output";
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
