import 'dart:convert';

void _addJsonContentToPromptValues(jsonContent, responseFormat, promptValues) {
  try {
    final newValues = jsonDecode(jsonContent);
    promptValues.addAll(newValues);
  } catch (e) {
    throw Exception("Malformed JSON. Failing Experiment.");
  }
}

void addPromptValues(content, responseFormat, promptValues, fixJson) {
  try {
    _addJsonContentToPromptValues(content, responseFormat, promptValues);
  } catch (e) {
    if (!fixJson) {
      rethrow;
    }
    final fixedJson = _extractJson(content);
    if (fixedJson != null) {
      _addJsonContentToPromptValues(fixedJson, responseFormat, promptValues);
    } else {
      rethrow;
    }
  }
}

RegExp placeholderPattern = RegExp(r'\$\{([^\}]+)\}');

String createPrompt(String template, templateProperties) {
  String modifiedTemplate = template.replaceAllMapped(placeholderPattern,
      (Match match) => templateProperties[match[1]] ?? match[0]);
  return modifiedTemplate;
}

String createPromptByIndex(String template, templateProperties, index) {
  String modifiedTemplate = template.replaceAllMapped(placeholderPattern,
      (Match match) => templateProperties[match[1]][index] ?? match[0]);
  return modifiedTemplate;
}

String? _extractJson(content) {
  RegExp jsonPattern = RegExp(r'(\{.*?\})');
  Match? jsonMatch = jsonPattern.firstMatch(content);
  if (jsonMatch != null) {
    return jsonMatch.group(1)!;
  } else {
    print('No JSON string found in the input.');
    return null;
  }
}
