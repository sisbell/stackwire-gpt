import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

class ArchetypeBuilder {
  final FileSystem fileSystem;

  ArchetypeBuilder(this.fileSystem);

  Future<String> downloadArchetypeArchive({http.Client? client}) async {
    client ??= http.Client();
    try {
      final Map<String, String> directoryPaths = await getDirectoryPaths();
      final String stackwireDirPath = directoryPaths['stackwireDirPath']!;
      final String archetypesDirPath = directoryPaths['archetypesDirPath']!;
      final stackwireDir = fileSystem.directory(stackwireDirPath);

      if (await stackwireDir.exists()) {
        print("Archive directory found: $archetypesDirPath");
        return archetypesDirPath;
      }
      print(stackwireDir);
      print("Downloading archetype archive...");
      stackwireDir.createSync(recursive: true);
      final String zipUrl =
          'https://firebasestorage.googleapis.com/v0/b/stantrek-prod.appspot.com/o/stackwire%2Farchetypes.zip?alt=media&token=10bdbb6f-e11d-446e-ab34-e42d4642b5f7';
      final http.Response response = await client.get(Uri.parse(zipUrl));
      List<int> bytes = response.bodyBytes;
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final String filename = path.join(stackwireDirPath, file.name);
        if (file.isFile) {
          final data = file.content as List<int>;
          fileSystem.file(filename)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          fileSystem.directory(filename).createSync();
        }
      }

      print('Zip file extracted to $archetypesDirPath');
      return archetypesDirPath;
    } catch (e) {
      throw ArchiveDownloadException('Failed to download and extract archive: $e');
    }
  }

  Future<Map<String, String>> getDirectoryPaths() async {
    final String homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
    final String stackwireDirPath = path.join(homeDir, '.stackwire');
    final String archetypesDirPath = path.join(stackwireDirPath, 'archetypes');
    return {
      'stackwireDirPath': stackwireDirPath,
      'archetypesDirPath': archetypesDirPath,
    };
  }

  Future<String> readProjectYaml(String directoryPath) async {
    final projectYamlPath = '$directoryPath/project.yaml';
    final projectYamlFile = fileSystem.file(projectYamlPath);

    if (await projectYamlFile.exists()) {
      final contents = await projectYamlFile.readAsString(encoding: utf8);
      return contents;
    } else {
      throw FileSystemException(
        'project.yaml file not found',
        directoryPath,
      );
    }
  }

  bool verifyYamlFormat(String yamlContent) {
    try {
      loadYaml(yamlContent);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ArchiveDownloadException implements Exception {
  final String message;

  ArchiveDownloadException(this.message);

  @override
  String toString() => 'ArchiveDownloadException: $message';
}


