import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'io.dart';

class NativeIO implements IO {
  @override
  Future<String> readFileAsString(String filePath) async {
    File file = File(filePath);
    try {
      String content = await file.readAsString();
      return content;
    } catch (e) {
      throw Exception('Error occurred while reading file: $e');
    }
  }

  @override
  Future<void> writeMap(Map<String, dynamic> data, String filePath) async {
    File file = File(filePath);
    try {
      String jsonString = jsonEncode(data);
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      throw Exception('Error occurred while writing JSON to file: $e');
    }
  }

  @override
  Future<void> writeString(String content, String filePath) async {
    final file = File(filePath);
    try {
      file.writeAsStringSync(content, flush: true);
    } catch (e) {
      throw Exception('Error occurred while writing file: $e');
    }
  }

  @override
  void createDirectoryIfNotExist(String dirName) {
    Directory directory = Directory(dirName);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  @override
  Future<void> copyDirectoryContents(
      Directory source, Directory destination) async {
    createDirectoryIfNotExist(destination.path);
    await for (var entity
        in source.list(recursive: false, followLinks: false)) {
      final newPath = path.join(destination.path, path.basename(entity.path));
      if (entity is Directory) {
        await Directory(newPath).create();
        await copyDirectoryContents(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }
}
