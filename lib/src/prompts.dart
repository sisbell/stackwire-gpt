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
    final fixedJson = extractJson(content);
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

String? extractJson(content) {
  int bracketCount = 0;
  int startIndex = -1;
  int endIndex = -1;

  for (int i = 0; i < content.length; i++) {
    if (content[i] == '{') {
      if (startIndex == -1) {
        startIndex = i;
      }
      bracketCount++;
    } else if (content[i] == '}') {
      bracketCount--;
      if (bracketCount == 0) {
        endIndex = i;
        break;
      }
    }
  }

  if (startIndex != -1 && endIndex != -1) {
    return content.substring(startIndex, endIndex + 1);
  } else {
    print('No JSON string found in the input.');
    return null;
  }
}