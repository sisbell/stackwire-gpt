import 'package:gpt/src/prompts.dart';
import 'package:test/test.dart';

void main() {
  group('extractJson', () {
    test('should return JSON string when input contains a JSON object', () {
      final content = 'Some text before {"key": "value"} some text after';
      final result = extractJson(content);
      expect(result, '{"key": "value"}');
    });

    test('should return null when input does not contain a JSON object', () {
      final content = 'Some text without any JSON object';
      final result = extractJson(content);
      expect(result, isNull);
    });

    test('should return the first JSON object when input contains multiple JSON objects', () {
      final content = 'Some text before {"key1": "value1"} some text in between {"key2": "value2"} some text after';
      final result = extractJson(content);
      expect(result, '{"key1": "value1"}');
    });

    test('should return JSON object with nested JSON object', () {
      final content = 'Some text before {"key": {"nestedKey": "nestedValue"}} some text after';
      final result = extractJson(content);
      expect(result, '{"key": {"nestedKey": "nestedValue"}}');
    });
  });

  group('createPromptByIndex', () {
    test('should replace placeholders with values at specified index', () {
      final template = '\${key1} is friends with \${key2}.';
      final templateProperties = {
        'key1': ['Alice', 'Bob'],
        'key2': ['Charlie', 'David']
      };

      final result = createPromptByIndex(template, templateProperties, 0);
      expect(result, 'Alice is friends with Charlie.');
    });

    test('should throw an error if the index is out of range', () {
      final template = 'Hello \${name}';
      final templateProperties = {'name': ['Alice', 'Bob']};
      final index = 2;

      expect(() => createPromptByIndex(template, templateProperties, index),
          throwsA(isA<RangeError>()));
    });

    test('should return template unchanged if no placeholders found', () {
      final template = 'No placeholders in this template.';
      final templateProperties = {
        'key1': ['Alice', 'Bob'],
        'key2': ['Charlie', 'David']
      };

      final result = createPromptByIndex(template, templateProperties, 0);
      expect(result, 'No placeholders in this template.');
    });
  });
}
