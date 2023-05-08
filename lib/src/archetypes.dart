import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

Future<String> getProjectRoot() async {
  final scriptPath = Platform.script.toFilePath();
  Directory currentDirectory = File(scriptPath).parent;
  while (
      await File(path.join(currentDirectory.path, 'pubspec.yaml')).exists() ==
          false) {
    currentDirectory = currentDirectory.parent;
  }
  return currentDirectory.path;
}

Future<String> getArchetypeDirectory() async {
  final String homeDir =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
  final String stackwireDirPath = path.join(homeDir, '.stackwire');
  final String archetypesDirPath = path.join(stackwireDirPath, 'archetypes');
  return archetypesDirPath;
}

Future<Directory> getArchetypeTestDirectory(dirName) async {
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
    throw Exception(
        'project.yaml file not found in the specified directory: $directoryPath');
  }
}

Future<String> downloadArchetypeArchive() async {
  try {
    final String homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
    final String stackwireDirPath = path.join(homeDir, '.stackwire');
    final stackwireDir = Directory(stackwireDirPath);
    final String archetypesDirPath = await getArchetypeDirectory();

    if (await stackwireDir.exists()) {
      print("Archive directory found");
      return archetypesDirPath;
    }
    print("Downloading archetype archive...");
    stackwireDir.createSync();

    final String zipUrl =
        'https://firebasestorage.googleapis.com/v0/b/stantrek-prod.appspot.com/o/stackwire%2Farchetypes.zip?alt=media&token=10bdbb6f-e11d-446e-ab34-e42d4642b5f7';
    final http.Response response = await http.get(Uri.parse(zipUrl));
    print(response.contentLength);
    List<int> bytes = response.bodyBytes;

    final Archive archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final String filename = path.join(stackwireDirPath, file.name);
      if (file.isFile) {
        final data = file.content as List<int>;
        File(filename)
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(filename).createSync();
      }
    }

    print('Zip file extracted to $archetypesDirPath');
    return archetypesDirPath;
  } catch (e) {
    print(e);
  }
  return "";
}
