import 'dart:convert';
import 'dart:io';

Future<void> writeMap(Map<String, dynamic> data, String filePath) async {
  File file = File(filePath);
  try {
    String jsonString = jsonEncode(data);
    await file.writeAsString(jsonString);
  } catch (e) {
    throw Exception('Error occurred while writing JSON to file: $e');
  }
}

Future<Map<String, dynamic>> readExperimentFile(String filePath) async {
  String jsonString = await readFileAsString(filePath);
  return jsonDecode(jsonString);
}

Future<String> readFileAsString(String filePath) async {
  File file = File(filePath);
  try {
    String content = await file.readAsString();
    return content;
  } catch (e) {
    throw Exception('Error occurred while reading file: $e');
  }
}

Future<void> writeMetrics(String content, String filePath) async {
  final file = File(filePath);
  bool exists = await file.exists();
  if(!exists) {
    await file.writeAsString("request_id, request_time, prompt_tokens, completion_tokens, total_tokens\n");
  }
  final sink = File(filePath).openWrite(mode: FileMode.append);
  try {
    sink.write(content);
  } catch (e) {
    throw Exception('Error occurred while writing file: $e');
  }
}

Future<void> writeString(String content, String filePath) async {
  final file = File(filePath);
  try {
    file.writeAsString(content);
  } catch (e) {
    throw Exception('Error occurred while writing file: $e');
  }
}

void createDirectoryIfNotExist(String dirName) {
  Directory directory = Directory(dirName);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
    print('Directory $dirName created.');
  }
}
