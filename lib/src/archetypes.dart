import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'io_helper.dart';

class ArchetypeBuilder {
  final String archetypeVersion = "4";

  final FileSystem fileSystem;

  ArchetypeBuilder(this.fileSystem);

  Future<String> downloadArchetypeArchive({http.Client? client}) async {
    final ioHelper = IOHelper(fileSystem: fileSystem);
    client ??= http.Client();
    final archetypeFileName = "archetypes-$archetypeVersion.zip";
    Directory? archetypesDirectory;
    try {
      final Map<String, String> paths =
          await getDirectoryPaths(archetypeVersion);
      final String stackwireDirectoryPath = paths['stackwireDirectoryPath']!;
      final String archetypesDirectoryPath = paths['archetypesDirectoryPath']!;
      final stackwireDirectory = fileSystem.directory(stackwireDirectoryPath);
      archetypesDirectory = fileSystem.directory(archetypesDirectoryPath);

      if (await archetypesDirectory.exists()) {
        print("Archetypes file found at: $archetypesDirectoryPath");
        return archetypesDirectoryPath;
      }
      ioHelper.createDirectoryIfNotExist(archetypesDirectoryPath);
      print(stackwireDirectory);
      archetypesDirectory.createSync(recursive: true);
      final String zipUrl =
          'https://storage.googleapis.com/zapvine-prod.appspot.com/archetypes/$archetypeFileName';
      print("Downloading $zipUrl");
      final http.Response response = await client.get(Uri.parse(zipUrl));
      List<int> bytes = response.bodyBytes;
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final String filename = path.join(archetypesDirectoryPath, file.name);
        if (file.isFile) {
          final data = file.content as List<int>;
          fileSystem.file(filename)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          fileSystem.directory(filename).createSync();
        }
      }
      print('Zip file extracted to $archetypesDirectoryPath');
      return archetypesDirectoryPath;
    } catch (e) {
      if (archetypesDirectory != null) {
        archetypesDirectory.deleteSync();
      }
      throw ArchiveDownloadException(
          'Failed to download and extract archive: $e');
    }
  }

  Future<Map<String, String>> getDirectoryPaths(archetypeVersion) async {
    final String homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
    final String stackwireDirPath = path.join(homeDir, '.stackwire');
    final String archetypesDirPath =
        path.join(stackwireDirPath, 'cache', 'archetypes-$archetypeVersion');
    return {
      'stackwireDirectoryPath': stackwireDirPath,
      'archetypesDirectoryPath': archetypesDirPath,
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
