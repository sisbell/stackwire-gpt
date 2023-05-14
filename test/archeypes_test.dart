import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:gpt/src/archetypes.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('getDirectoryPaths', () {
    test('should return correct stackwire and archetype directory paths',
        () async {
      FileSystem fileSystem = MemoryFileSystem.test();
      final builder = ArchetypeBuilder(fileSystem);
      final directoryPaths = await builder.getDirectoryPaths("2");
      final String homeDir =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
      final String expectedStackwireDirPath = path.join(homeDir, '.stackwire');
      final String expectedArchetypesDirPath =
          path.join(expectedStackwireDirPath, 'cache/archetypes-2');

      expect(
          directoryPaths['stackwireDirectoryPath'], expectedStackwireDirPath);
      expect(
          directoryPaths['archetypesDirectoryPath'], expectedArchetypesDirPath);
    });
  });

  group('downloadArchetypeArchive', () {
    late ArchetypeBuilder builder;
    late MemoryFileSystem memoryFileSystem;

    setUp(() {
      memoryFileSystem = MemoryFileSystem();
      builder = ArchetypeBuilder(memoryFileSystem);
    });

    test(
        'should download and extract the archive when the directory does not exist',
        () async {
      final archive = Archive();
      final encoder = ZipEncoder();
      final encodedArchive = encoder.encode(archive)!;

      final client = MockClient(
        (request) async {
          return http.Response.bytes(encodedArchive, 200);
        },
      );

      final archetypesDirPath =
          await builder.downloadArchetypeArchive(client: client);

      final homeDir =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
      final stackwireDirPath = path.join(homeDir, '.stackwire');
      final stackwireDir = memoryFileSystem.directory(stackwireDirPath);
      expect(await stackwireDir.exists(), true);

      final extractedPath =
          (await builder.getDirectoryPaths("2"))["archetypesDirectoryPath"];
      expect(archetypesDirPath, extractedPath);
    });

    test('downloadArchetypeArchive throws ArchiveDownloadException on error',
        () async {
      final client = MockClient(
        (request) async {
          return http.Response.bytes([], 400);
        },
      );
      expect(
        () async => await builder.downloadArchetypeArchive(client: client),
        throwsA(isA<ArchiveDownloadException>()),
      );
    });
  });

  group('readProjectYaml', () {
    late ArchetypeBuilder builder;
    late MemoryFileSystem memoryFileSystem;

    setUp(() {
      memoryFileSystem = MemoryFileSystem();
      builder = ArchetypeBuilder(memoryFileSystem);
    });

    test('should read and return the contents of the project.yaml file',
        () async {
      final directory = memoryFileSystem.directory('/test/');
      directory.createSync();
      final file = memoryFileSystem.file('/test/project.yaml');
      file.writeAsStringSync('test: Test Project');
      final result = await builder.readProjectYaml(directory.path);
      expect(result, equals('test: Test Project'));
    });

    test('should throw an exception if the project.yaml file does not exist',
        () async {
      final directory = memoryFileSystem.directory('/test/');
      directory.createSync();
      expect(() async => await builder.readProjectYaml(directory.path),
          throwsA(isA<FileSystemException>()));
    });
  });

  group('verifyYamlFormat', () {
    late ArchetypeBuilder builder;
    late MemoryFileSystem memoryFileSystem;

    setUp(() {
      memoryFileSystem = MemoryFileSystem();
      builder = ArchetypeBuilder(memoryFileSystem);
    });
    test('returns true for correctly formatted YAML', () {
      final yamlString = '''
name: John Doe
age: 30
email: johndoe@example.com
''';
      expect(builder.verifyYamlFormat(yamlString), isTrue);
    });

    test('returns false for incorrectly formatted YAML', () {
      final yamlString = '''
* name John Doe
''';
      expect(builder.verifyYamlFormat(yamlString), isFalse);
    });

    test('returns true for an empty YAML string', () {
      expect(builder.verifyYamlFormat(''), isTrue);
    });
  });
}
