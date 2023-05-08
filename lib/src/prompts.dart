import 'dart:convert';

void _addJsonContentToPromptValues(jsonContent, promptValues) {
  try {
    final newValues = jsonDecode(jsonContent);
    promptValues.addAll(newValues);
  } catch (e) {
    throw Exception("Malformed JSON. Failing Experiment.");
  }
}

void addPromptValues(content, promptValues, fixJson) {
  try {
    _addJsonContentToPromptValues(content, promptValues);
  } catch (e) {
    if (!fixJson) {
      rethrow;
    }
    final fixedJson = _extractJson(content);
    if (fixedJson != null) {
      _addJsonContentToPromptValues(fixedJson, promptValues);
    } else {
      rethrow;
    }
  }
}

RegExp placeholderPattern = RegExp(r'\$\{([^\}]+)\}');

String substituteTemplateProperties(String template, templateProperties) {
  String modifiedTemplate = template.replaceAllMapped(
      placeholderPattern, (Match match) => templateProperties[match[1]] ?? "");
  return modifiedTemplate;
}

String createPromptByIndex(String template, templateProperties, index) {
  String modifiedTemplate = template.replaceAllMapped(placeholderPattern,
      (Match match) => templateProperties[match[1]][index] ?? "");
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
