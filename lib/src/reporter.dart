import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'io/io.dart';

class Reporter {
  final IO io;

  Reporter(this.io);

  Future<void> writeMetrics(responseBody, promptFileName, filePath) async {
    io.writeMetrics(responseBody, promptFileName, filePath);
  }

  Future<void> writeResultsTo(results, reportDir) async {
    final projectName = results["projectName"];
    final projectVersion = results["projectVersion"];
    final blockId = results["blockId"];
    final fileName = "$projectName-$projectVersion-$blockId-report.json";
    await io.writeMap(results, "$reportDir/$fileName");
  }

  Future<void> logFailedRequest(requestBody, dataDir, experimentRun) async {
    final directory = "$dataDir/$experimentRun";
    io.createDirectoryIfNotExist(directory);
    final responseId = "failed";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await io.writeString(
        requestBody, "$directory/$timestamp-$responseId-request.json");
  }

  Future<void> logRequestAndResponse(
      requestBody, responseBody, dataDir, experimentRun) async {
    final directory = "$dataDir/$experimentRun";
    io.createDirectoryIfNotExist(directory);
    final responseId = responseBody["id"] ?? "";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await io.writeString(
        requestBody, "$directory/$timestamp-$responseId-request.json");
    await io.writeString(jsonEncode(responseBody),
        "$directory/$timestamp-$responseId-response.json");
  }
}

Future<void> downloadImage(String imageUrl, String savePath) async {
  final response = await http.get(Uri.parse(imageUrl));
  if (response.statusCode == 200) {
    final bytes = response.bodyBytes;
    final file = File(savePath);
    await file.writeAsBytes(bytes);
  } else {
    throw Exception('Failed to download image: HTTP ${response.statusCode}');
  }
}

Future<void> saveBase64AsPng(String base64String, String filePath) async {
  Uint8List decodedBytes = base64Decode(base64String);
  File file = File(filePath);
  await file.writeAsBytes(decodedBytes);
}
