import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;

class IOFileSystem {
  final FileSystem fileSystem;

  IOFileSystem({required this.fileSystem});

  File file(path) {
    return fileSystem.file(path);
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
