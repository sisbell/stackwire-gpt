import 'package:gpt/src/prompts.dart';
import 'package:test/test.dart';

void main() {
  group('_extractJson', () {
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
}
