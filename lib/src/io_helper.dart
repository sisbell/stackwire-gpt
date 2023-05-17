import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

class IOHelper {
  final FileSystem fileSystem;

  IOHelper({required this.fileSystem});

  File file(path) {
    return fileSystem.file(path);
  }

  Future<File> findFile(String? dir1, String dir2, String fileName) async {
    if (dir1 != null) {
      var file1 = fileSystem.directory(dir1).childFile(fileName);
      if (await file1.exists()) {
        return file1;
      }
    }

    var file2 = fileSystem.directory(dir2).childFile(fileName);

    if (await file2.exists()) {
      return file2;
    } else {
      throw FileSystemException('File not found: $fileName');
    }
  }

  Future<void> createDirectoryIfNotExist(String path) async {
    final dir = fileSystem.directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> writeString(String content, String path) async {
    final file = fileSystem.file(path);
    await file.writeAsString(content);
  }

  Future<String> readFileAsString(String filePath) async {
    File file = fileSystem.file(filePath);
    try {
      String content = await file.readAsString();
      return content;
    } catch (e) {
      throw FileSystemException(
          'Error occurred while reading file: $e', filePath);
    }
  }

  Future<Map<String, dynamic>> readJsonFile(String filePath) async {
    String jsonString = await readFileAsString(filePath);
    return jsonDecode(jsonString);
  }

  Future<Map<String, dynamic>> readYamlFile(String filePath) async {
    String text = await readFileAsString(filePath);
    final yamlObject = loadYaml(text);
    return jsonDecode(json.encode(yamlObject));
  }

  Future<Map<String, dynamic>> readYaml(String content) async {
    final yamlObject = loadYaml(content);
    return jsonDecode(json.encode(yamlObject));
  }

  Future<void> writeMap(Map<String, dynamic> data, String filePath) async {
    File file = fileSystem.file(filePath);
    try {
      String jsonString = jsonEncode(data);
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      throw FileSystemException(
          'Error occurred while writing JSON to file: $e', filePath);
    }
  }

  Future<void> copyDirectoryContents(
      Directory source, Directory destination) async {
    await createDirectoryIfNotExist(destination.path);
    await for (var entity
        in source.list(recursive: false, followLinks: false)) {
      final newPath = path.join(destination.path, path.basename(entity.path));
      if (entity is Directory) {
        await fileSystem.directory(newPath).create();
        await copyDirectoryContents(entity, fileSystem.directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }
}
