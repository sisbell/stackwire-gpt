import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:gpt/src/file_system.dart';
import 'package:gpt/src/reporter.dart';
import 'package:test/test.dart';

void main() {
  test(
      'logRequestAndResponse should log request and response files in the specified directory',
      () async {
    final memoryFileSystem = MemoryFileSystem();
    final customFileSystem = IOFileSystem(fileSystem: memoryFileSystem);
    final reporter = ConcreteReporter(customFileSystem);

    final requestBody = 'This is a sample request body.';
    final responseBody = {
      'id': '123',
      'content': 'This is a sample response body.'
    };
    final toDirectory = 'logs';
    await reporter.logRequestAndResponse(
        requestBody, responseBody, toDirectory);

    final directory = memoryFileSystem.directory(toDirectory);
    expect(await directory.exists(), isTrue);

    final files = await directory.list().toList();
    expect(files.length, equals(2));

    final outputRequestFile =
        files.firstWhere((file) => file.path.contains('-request.json')) as File;
    final outputResponseFile = files
        .firstWhere((file) => file.path.contains('-response.json')) as File;

    final requestContent = await outputRequestFile.readAsString();
    final responseContent = jsonDecode(await outputResponseFile.readAsString());

    expect(requestContent, equals(requestBody));
    expect(responseContent, equals(responseBody));
  });

  test('logFailedRequest should log requestBody with content', () async {
    final fileSystem = MemoryFileSystem();
    final reporter = ConcreteReporter(IOFileSystem(fileSystem: fileSystem));

    final requestBody = 'This is a sample failed request body.';
    final toDirectory = '/failed_requests';

    await reporter.logFailedRequest(requestBody, toDirectory);

    final dir = fileSystem.directory(toDirectory);
    expect(dir.existsSync(), isTrue);

    final files = dir.listSync();
    expect(files.length, equals(1));
    expect(files.first.path.contains('-failed-request.json'), isTrue);

    final content = await (files.first as File).readAsString();
    expect(content, equals(requestBody));
  });

  test('logFailedRequest should log empty requestBody', () async {
    final fileSystem = MemoryFileSystem();
    final reporter = ConcreteReporter(IOFileSystem(fileSystem: fileSystem));

    final requestBody = '';
    final toDirectory = '/empty_failed_requests';

    await reporter.logFailedRequest(requestBody, toDirectory);

    final dir = fileSystem.directory(toDirectory);
    expect(dir.existsSync(), isTrue);

    final files = dir.listSync();
    expect(files.length, equals(1));
    expect(files.first.path.contains('-failed-request.json'), isTrue);

    final content = await (files.first as File).readAsString();
    expect(content, equals(requestBody));
  });

  group('writeProjectReport', () {
    late MemoryFileSystem memoryFileSystem;
    late IOFileSystem fileSystem;
    late ConcreteReporter reporter;
    late Map<String, dynamic> results;

    setUp(() {
      memoryFileSystem = MemoryFileSystem();
      fileSystem = IOFileSystem(fileSystem: memoryFileSystem);
      reporter = ConcreteReporter(fileSystem);

      results = {
        "projectName": "TestProject",
        "projectVersion": "1.0.0",
        "blockId": "001",
        "data": "Sample data",
      };
    });

    test('should create and write report to file', () async {
      await reporter.writeProjectReport(results, '/reports');

      final reportFile =
          memoryFileSystem.file('/reports/TestProject-1.0.0-001-report.json');
      expect(reportFile.existsSync(), true);

      final fileContent = await reportFile.readAsString();
      expect(fileContent,
          '{"projectName":"TestProject","projectVersion":"1.0.0","blockId":"001","data":"Sample data"}');
    });

    test('should create nested report directories if not exist', () async {
      await reporter.writeProjectReport(results, '/nested/reports');

      final reportFile = memoryFileSystem
          .file('/nested/reports/TestProject-1.0.0-001-report.json');
      expect(reportFile.existsSync(), true);
    });

    test('should throw an exception if there is an error while writing',
        () async {
      memoryFileSystem
          .file('/reports')
          .createSync(); // Creating a file instead of a directory
      expect(
        () async => await reporter.writeProjectReport(results, '/reports'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('writeMetrics', () {
    late MemoryFileSystem memoryFileSystem;
    late IOFileSystem fileSystem;
    late ConcreteReporter reporter;
    late Map<String, dynamic> responseBody;

    setUp(() {
      memoryFileSystem = MemoryFileSystem();
      fileSystem = IOFileSystem(fileSystem: memoryFileSystem);
      reporter = ConcreteReporter(fileSystem);

      responseBody = {
        "id": "123",
        "requestTime": "2023-05-05T00:00:00",
        "usage": {
          "prompt_tokens": 10,
          "completion_tokens": 20,
          "total_tokens": 30,
        },
      };
    });

    test('should create and write metrics to file', () async {
      await reporter.writeMetrics(responseBody, '001', 'test', '/metrics.csv');

      final metricsFile = memoryFileSystem.file('/metrics.csv');
      expect(metricsFile.existsSync(), true);

      final fileContent = await metricsFile.readAsString();
      expect(fileContent,
          'request_id, executionId, tag, request_time, prompt_tokens, completion_tokens, total_tokens\n123, 001, test, 2023-05-05T00:00:00, 10, 20, 30\n');
    });

    test('writeMetrics should append metrics to an existing file', () async {
      await reporter.writeMetrics(responseBody, '001', 'test', '/metrics.csv');

      responseBody['id'] = '456';
      responseBody['usage']['prompt_tokens'] = 15;
      responseBody['usage']['completion_tokens'] = 25;
      responseBody['usage']['total_tokens'] = 40;
      await reporter.writeMetrics(responseBody, '002', 'test2', '/metrics.csv');

      final content =
          await memoryFileSystem.file('/metrics.csv').readAsString();
      final lines = content.split('\n');
      expect(lines.length, 4); // 2 data lines + header + empty line
      expect(
        lines[2],
        '456, 002, test2, 2023-05-05T00:00:00, 15, 25, 40',
      );
    });
  });
}
