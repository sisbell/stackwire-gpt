
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

Future<String> getProjectRoot() async {
  final scriptPath = Platform.script.toFilePath();
  Directory currentDirectory = File(scriptPath).parent;
  while (await File(path.join(currentDirectory.path, 'pubspec.yaml')).exists() ==
      false) {
    currentDirectory = currentDirectory.parent;
  }
  return currentDirectory.path;
}

Future<Directory> getArchetypeDirectory(dirName) async {
  final projectRoot = await getProjectRoot();
  return Directory("$projectRoot/archetypes/$dirName");
}

Future<String> readProjectYaml(String directoryPath) async {
  final projectYamlPath = '$directoryPath/project.yaml';
  final projectYamlFile = File(projectYamlPath);

  if (await projectYamlFile.exists()) {
    final contents = await projectYamlFile.readAsString(encoding: utf8);
    return contents;
  } else {
    throw Exception('project.yaml file not found in the specified directory: $directoryPath');
  }
}