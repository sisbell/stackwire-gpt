import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'files.dart';

Future<void> runExperiment(experimentName, outputDir, data, apiKey, numberOfRuns) async {
  while(numberOfRuns-- > 0) {
    print("Run: $numberOfRuns");
    await sendHttpPostRequest(experimentName, outputDir, data, apiKey);
  }
}

Future<void> sendHttpPostRequest(experimentName, outputDir, data, apiKey) async {
  final stringBuffer = StringBuffer();
  stringBuffer.writeln("$experimentName");

  final headers = {
    "Authorization": "Bearer ${apiKey}",
    "Content-Type": "application/json",
  };

  final body = jsonEncode(data);
  String content = data['messages'][0]['content'];
  stringBuffer.writeln(content);
  try {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      print('Request successful.');
    } else {
      print('Request failed with status code: ${response.statusCode}');
    }
    Map<String, dynamic> jsonBody = jsonDecode(response.body);
    final responseId = jsonBody["id"];

    final x = jsonBody["choices"][0]["message"]["content"];
    stringBuffer.writeln(x);

    writeString(stringBuffer.toString(), "$outputDir/$experimentName/data/$responseId-text.txt");
    writeString(body, "$outputDir/$experimentName/data/$responseId-request.json");
    writeString(response.body, "$outputDir/$experimentName/data/$responseId-response.json");
  } catch (e) {
    print('Error occurred during the request: $e');
  }
}


