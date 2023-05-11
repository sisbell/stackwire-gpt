import 'dart:convert';

import 'package:file/memory.dart';
import 'package:gpt/src/file_system.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('copyDirectoryContents should copy directory contents', () async {
    final fileSystem = MemoryFileSystem();
    final sourceDir = fileSystem.directory('source');
    final destDir = fileSystem.directory('destination');

    await sourceDir.create();
    await fileSystem.file('source/file1.txt').writeAsString('Hello');
    await fileSystem.file('source/file2.txt').writeAsString('World');
    await sourceDir.childDirectory('subdir').create();
    await fileSystem.file('source/subdir/file3.txt').writeAsString('Subdir');

    final io = IOFileSystem(fileSystem: fileSystem);
    await io.copyDirectoryContents(sourceDir, destDir);

    expect(await destDir.exists(), true);
    expect(
        await fileSystem.file('destination/file1.txt').readAsString(), 'Hello');
    expect(
        await fileSystem.file('destination/file2.txt').readAsString(), 'World');
    expect(await fileSystem.directory('destination/subdir').exists(), true);
    expect(await fileSystem.file('destination/subdir/file3.txt').readAsString(),
        'Subdir');
  });

  test('copyDirectoryContents should copy an empty directory', () async {
    final fileSystem = MemoryFileSystem();
    final customFileSystem = IOFileSystem(fileSystem: fileSystem);
    final srcDir = fileSystem.directory('src');
    final destDir = fileSystem.directory('dest');
    await srcDir.create();
    await destDir.create();
    await customFileSystem.copyDirectoryContents(srcDir, destDir);

    final destDirContents = destDir.listSync();
    expect(destDirContents.isEmpty, isTrue);
  });

  test(
      'copyDirectoryContents should copy a directory with files only (no subdirectories)',
      () async {
    final fileSystem = MemoryFileSystem();
    final customFileSystem = IOFileSystem(fileSystem: fileSystem);

    final srcDir = fileSystem.directory('src');
    final destDir = fileSystem.directory('dest');
    await srcDir.create();
    await destDir.create();

    final file1 = fileSystem.file(path.join(srcDir.path, 'file1.txt'));
    final file2 = fileSystem.file(path.join(srcDir.path, 'file2.txt'));
    await file1.writeAsString('Content of file1.txt');
    await file2.writeAsString('Content of file2.txt');

    await customFileSystem.copyDirectoryContents(srcDir, destDir);

    final destFile1 = fileSystem.file(path.join(destDir.path, 'file1.txt'));
    final destFile2 = fileSystem.file(path.join(destDir.path, 'file2.txt'));
    expect(await destFile1.exists(), isTrue);
    expect(await destFile2.exists(), isTrue);

    expect(await destFile1.readAsString(), 'Content of file1.txt');
    expect(await destFile2.readAsString(), 'Content of file2.txt');
  });

  test('writeMap should write a JSON file from a map', () async {
    final fileSystem = MemoryFileSystem();
    final customFileSystem = IOFileSystem(fileSystem: fileSystem);

    final testMap = {
      'key1': 'value1',
      'key2': 'value2',
    };

    final filePath = 'test.json';

    await customFileSystem.writeMap(testMap, filePath);

    final file = fileSystem.file(filePath);
    expect(await file.exists(), isTrue);
    expect(jsonDecode(await file.readAsString()), equals(testMap));
  });

  test('writeMap should write a JSON file from a map with special characters',
      () async {
    final fileSystem = MemoryFileSystem();
    final customFileSystem = IOFileSystem(fileSystem: fileSystem);

    final specialCharMap = {
      'key@1': 'value#1',
      'key\$2': 'value!2',
    };

    final filePath = 'special_chars.json';

    await customFileSystem.writeMap(specialCharMap, filePath);

    final file = fileSystem.file(filePath);
    expect(await file.exists(), isTrue);
    expect(jsonDecode(await file.readAsString()), equals(specialCharMap));
  });

  test('writeMap should write a JSON file from a map with different data types',
      () async {
    final fileSystem = MemoryFileSystem();
    final customFileSystem = IOFileSystem(fileSystem: fileSystem);

    final multiTypeMap = {
      'key1': 'value1',
      'key2': 123,
      'key3': true,
      'key4': [1, 2, 3],
      'key5': {'a': 1, 'b': 2},
    };

    final filePath = 'multi_types.json';
    await customFileSystem.writeMap(multiTypeMap, filePath);

    final file = fileSystem.file(filePath);
    expect(await file.exists(), isTrue);
    expect(jsonDecode(await file.readAsString()), equals(multiTypeMap));
  });
}
