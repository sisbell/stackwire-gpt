import 'dart:convert';

import 'package:eom/io/io.dart';

class Reporter {
  final IO io;

  Reporter(this.io);

  Future<void> writeMetrics(responseBody, promptFileName, filePath) async {
    io.writeMetrics(responseBody, promptFileName, filePath);
  }

  Future<Map<String, dynamic>> readExperimentFile(String filePath) async {
    String jsonString = await io.readFileAsString(filePath);
    return jsonDecode(jsonString);
  }

  Future<void> writeResultsTo(experimentResults, reportDir) async {
    await io.writeMap(experimentResults,
        "$reportDir/${experimentResults["experimentName"]}-report.json");
  }

  Future<void> logFailedRequest(requestBody, dataDir, experimentRun) async {
    final directory = "$dataDir/$experimentRun";
    io.createDirectoryIfNotExist(directory);
    final responseId = "failed";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await io.writeString(requestBody, "$directory/$timestamp-$responseId-request.json");
  }

  Future<void> logRequestAndResponse(requestBody, responseBody, dataDir, experimentRun) async {
    final directory = "$dataDir/$experimentRun";
    io.createDirectoryIfNotExist(directory);
    final responseId = responseBody["id"];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await io.writeString(requestBody, "$directory/$timestamp-$responseId-request.json");
    await io.writeString(jsonEncode(responseBody), "$directory/$timestamp-$responseId-response.json");
  }
}
