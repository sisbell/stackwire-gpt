import 'dart:io';

abstract class IO {
  Future<String> readFileAsString(String filePath);

  Future<void> writeMap(Map<String, dynamic> data, String filePath);

  Future<void> writeString(String content, String filePath);

  void createDirectoryIfNotExist(String dirName);

  Future<void> copyDirectoryContents(Directory source, Directory destination);
}
