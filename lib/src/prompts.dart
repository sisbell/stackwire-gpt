import 'dart:convert';

void addJsonContentToPromptValues(jsonContent, promptValues) {
  try {
    final newValues = jsonDecode(jsonContent);
    promptValues.addAll(newValues);
  } catch (e) {
    throw FormatException("Malformed JSON. Failing Experiment.");
  }
}

void addPromptValues(content, promptValues, fixJson) {
  try {
    addJsonContentToPromptValues(content, promptValues);
  } catch (e) {
    if (!fixJson) {
      rethrow;
    }
    final fixedJson = extractJson(content);
    if (fixedJson != null) {
      addJsonContentToPromptValues(fixedJson, promptValues);
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
  String modifiedTemplate =
      template.replaceAllMapped(placeholderPattern, (Match match) {
    if (templateProperties[match[1]] != null) {
      if (index < templateProperties[match[1]].length) {
        return templateProperties[match[1]][index] ?? "";
      } else {
        throw RangeError(
            'Invalid prompt index: $index is out of range for the property ${match[1]}');
      }
    }
    return "";
  });
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
    return null;
  }
}
