import 'package:gpt/src/prompts.dart';
import 'package:test/test.dart';

void main() {
  group('addJsonContentToPromptValues', () {
    test('should add JSON content to promptValues', () {
      final jsonContent = '{"key1": "value1", "key2": "value2"}';
      final Map<String, dynamic> promptValues = {"key3": "value3"};

      addJsonContentToPromptValues(jsonContent, promptValues);

      expect(promptValues, {
        "key1": "value1",
        "key2": "value2",
        "key3": "value3",
      });
    });

    test(
        'addJsonContentToPromptValues should throw an exception for malformed JSON',
        () {
      final malformedJson = '{"key1": "value1", "key2": "value2';
      final promptValues = <String, dynamic>{};
      expect(
        () => addJsonContentToPromptValues(malformedJson, promptValues),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('addPromptValues', () {
    test('should add JSON content to promptValues', () {
      final content = '{"key1": "value1", "key2": "value2"}';
      final Map<String, dynamic> promptValues = {"key3": "value3"};

      addPromptValues(content, promptValues, false);

      expect(promptValues, {
        "key1": "value1",
        "key2": "value2",
        "key3": "value3",
      });
    });

    test('should throw an exception for malformed JSON when fixJson is false',
        () {
      final content = '{"key1": "value1", "key2": "value2';
      final Map<String, dynamic> promptValues = {"key3": "value3"};

      expect(() => addPromptValues(content, promptValues, false),
          throwsA(isA<FormatException>()));
    });

    test(
        'should add JSON content to promptValues when fixJson is true and JSON is extractable',
        () {
      final content =
          'Some text before JSON {"key1": "value1", "key2": "value2"} some text after JSON';
      final Map<String, dynamic> promptValues = {"key3": "value3"};

      addPromptValues(content, promptValues, true);

      expect(promptValues, {
        "key1": "value1",
        "key2": "value2",
        "key3": "value3",
      });
    });

    test(
        'should throw an exception for malformed JSON when fixJson is true and JSON is not extractable',
        () {
      final content = '{"key1": "value1", "key2": "value2';
      final Map<String, dynamic> promptValues = {"key3": "value3"};

      expect(() => addPromptValues(content, promptValues, true),
          throwsA(isA<FormatException>()));
    });

    test('should handle empty JSON content', () {
      final content = '{}';
      final Map<String, dynamic> promptValues = {"key1": "value1"};

      addPromptValues(content, promptValues, false);

      expect(promptValues, {"key1": "value1"});
    });

    test('should handle JSON content with only whitespace', () {
      final content = '{  }';
      final Map<String, dynamic> promptValues = {"key1": "value1"};

      addPromptValues(content, promptValues, false);

      expect(promptValues, {"key1": "value1"});
    });

    test('should handle JSON content with non-string values', () {
      final content =
          '{"key1": 42, "key2": true, "key3": [1, 2, 3], "key4": {"nestedKey": "nestedValue"}}';
      final Map<String, dynamic> promptValues = {"key5": "value5"};

      addPromptValues(content, promptValues, false);

      expect(promptValues, {
        "key1": 42,
        "key2": true,
        "key3": [1, 2, 3],
        "key4": {"nestedKey": "nestedValue"},
        "key5": "value5",
      });
    });

    test('should handle JSON content with duplicate keys', () {
      final content = '{"key1": "newValue1", "key2": "value2"}';
      final Map<String, dynamic> promptValues = {"key1": "value1"};

      addPromptValues(content, promptValues, false);

      expect(promptValues, {
        "key1": "newValue1",
        "key2": "value2",
      });
    });
  });

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

    test(
        'should return the first JSON object when input contains multiple JSON objects',
        () {
      final content =
          'Some text before {"key1": "value1"} some text in between {"key2": "value2"} some text after';
      final result = extractJson(content);
      expect(result, '{"key1": "value1"}');
    });

    test('should return JSON object with nested JSON object', () {
      final content =
          'Some text before {"key": {"nestedKey": "nestedValue"}} some text after';
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
      final templateProperties = {
        'name': ['Alice', 'Bob']
      };
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

  group('substituteTemplateProperties', () {
    test('should replace placeholders with their corresponding values', () {
      final template = 'Hello \${name}, welcome to \${location}';
      final templateProperties = {'name': 'Alice', 'location': 'Wonderland'};

      final result = substituteTemplateProperties(template, templateProperties);

      expect(result, 'Hello Alice, welcome to Wonderland');
    });

    test('should replace unknown placeholders with an empty value', () {
      final template = 'Hello \${name}, welcome to \${location}';
      final templateProperties = {'name': 'Alice'};

      final result = substituteTemplateProperties(template, templateProperties);

      expect(result, 'Hello Alice, welcome to ');
    });

    test('should return the original template if there are no placeholders',
        () {
      final template = 'Hello Alice, welcome to Wonderland';
      final templateProperties = <String, dynamic>{};

      final result = substituteTemplateProperties(template, templateProperties);

      expect(result, template);
    });

    test(
        'should replace placeholders with empty strings if properties are not in templateProperties',
        () {
      final template = 'Hello \${name}, welcome to \${location}';
      final templateProperties = {'age': 30};

      final result = substituteTemplateProperties(template, templateProperties);

      expect(result, 'Hello , welcome to ');
    });
  });
}
