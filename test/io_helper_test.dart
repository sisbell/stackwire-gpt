import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:gpt/src/io_helper.dart';
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

    final ioHelper = IOHelper(fileSystem: fileSystem);
    await ioHelper.copyDirectoryContents(sourceDir, destDir);

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
    final ioHelper = IOHelper(fileSystem: fileSystem);
    final srcDir = fileSystem.directory('src');
    final destDir = fileSystem.directory('dest');
    await srcDir.create();
    await destDir.create();
    await ioHelper.copyDirectoryContents(srcDir, destDir);

    final destDirContents = destDir.listSync();
    expect(destDirContents.isEmpty, isTrue);
  });

  test(
      'copyDirectoryContents should copy a directory with files only (no subdirectories)',
      () async {
    final fileSystem = MemoryFileSystem();
    final ioHelper = IOHelper(fileSystem: fileSystem);

    final srcDir = fileSystem.directory('src');
    final destDir = fileSystem.directory('dest');
    await srcDir.create();
    await destDir.create();

    final file1 = fileSystem.file(path.join(srcDir.path, 'file1.txt'));
    final file2 = fileSystem.file(path.join(srcDir.path, 'file2.txt'));
    await file1.writeAsString('Content of file1.txt');
    await file2.writeAsString('Content of file2.txt');

    await ioHelper.copyDirectoryContents(srcDir, destDir);

    final destFile1 = fileSystem.file(path.join(destDir.path, 'file1.txt'));
    final destFile2 = fileSystem.file(path.join(destDir.path, 'file2.txt'));
    expect(await destFile1.exists(), isTrue);
    expect(await destFile2.exists(), isTrue);

    expect(await destFile1.readAsString(), 'Content of file1.txt');
    expect(await destFile2.readAsString(), 'Content of file2.txt');
  });

  test('writeMap should write a JSON file from a map', () async {
    final fileSystem = MemoryFileSystem();
    final ioHelper = IOHelper(fileSystem: fileSystem);

    final testMap = {
      'key1': 'value1',
      'key2': 'value2',
    };

    final filePath = 'test.json';

    await ioHelper.writeMap(testMap, filePath);

    final file = fileSystem.file(filePath);
    expect(await file.exists(), isTrue);
    expect(jsonDecode(await file.readAsString()), equals(testMap));
  });

  test('writeMap should write a JSON file from a map with special characters',
      () async {
    final fileSystem = MemoryFileSystem();
    final ioHelper = IOHelper(fileSystem: fileSystem);

    final specialCharMap = {
      'key@1': 'value#1',
      'key\$2': 'value!2',
    };

    final filePath = 'special_chars.json';

    await ioHelper.writeMap(specialCharMap, filePath);

    final file = fileSystem.file(filePath);
    expect(await file.exists(), isTrue);
    expect(jsonDecode(await file.readAsString()), equals(specialCharMap));
  });

  test('writeMap should write a JSON file from a map with different data types',
      () async {
    final fileSystem = MemoryFileSystem();
    final ioHelper = IOHelper(fileSystem: fileSystem);

    final multiTypeMap = {
      'key1': 'value1',
      'key2': 123,
      'key3': true,
      'key4': [1, 2, 3],
      'key5': {'a': 1, 'b': 2},
    };

    final filePath = 'multi_types.json';
    await ioHelper.writeMap(multiTypeMap, filePath);

    final file = fileSystem.file(filePath);
    expect(await file.exists(), isTrue);
    expect(jsonDecode(await file.readAsString()), equals(multiTypeMap));
  });

  late FileSystem fs;
  late IOHelper ioHelper;

  setUp(() {
    fs = MemoryFileSystem();
    ioHelper = IOHelper(fileSystem: fs);
  });

  group('IOHelper', () {
    test('finds file in the first directory when dir1 is not null', () async {
      var dir1 = '/dir1';
      var dir2 = '/dir2';
      var fileName = 'testFile1.txt';
      var file1 = fs.directory(dir1).childFile(fileName);

      fs.directory(dir1).createSync();
      file1.writeAsStringSync('Test content');
      expect((await ioHelper.findFile(dir1, dir2, fileName)).path, file1.path);
    });

    test('finds file in the second directory when dir1 is null', () async {
      var dir2 = '/dir2';
      var fileName = 'testFile2.txt';
      var file2 = fs.directory(dir2).childFile(fileName);

      fs.directory(dir2).createSync();
      file2.writeAsStringSync('Test content');
      expect((await ioHelper.findFile(null, dir2, fileName)).path, file2.path);
    });

    test('finds file in the second directory when dir1 does not exist', () async {
      var dir1 = '/nonExistentDirectory';
      var dir2 = '/dir2';
      var fileName = 'testFile2.txt';
      var file2 = fs.directory(dir2).childFile(fileName);

      fs.directory(dir2).createSync();
      file2.writeAsStringSync('Test content');

      expect((await ioHelper.findFile(dir1, dir2, fileName)).path, file2.path);
    });

    test('throws when file is not found in both directories', () async {
      var dir1 = '/dir1';
      var dir2 = '/dir2';
      var fileName = 'nonExistentFile.txt';

      fs.directory(dir1).createSync();
      fs.directory(dir2).createSync();

      expect(ioHelper.findFile(dir1, dir2, fileName), throwsA(isA<FileSystemException>()));
    });
  });

}


