import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:gpt/src/reporter.dart';
import 'package:http/http.dart';

class NetworkClient {
  final String apiKey;

  final Reporter reporter;

  late Client httpClient;

  late FileSystem fileSystem;

  NetworkClient(
      this.apiKey, this.reporter, this.fileSystem, Client? httpClient) {
    this.httpClient = httpClient ?? Client();
  }

  Future<Map<String, dynamic>> sendHttpPostRequest(requestBody, urlPath, logDir,
      {bool? dryRun}) async {
    dryRun = dryRun ?? false;
    final requestBodyStr = jsonEncode(requestBody);
    if (dryRun) {
      print("\tPOST to https://api.openai.com/$urlPath");
      print("\t\t$requestBodyStr");
      return {};
    }
    print("\n\tMaking call to OpenAI: $urlPath");
    try {
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final response = await httpClient.post(
        Uri.parse("https://api.openai.com/$urlPath"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: requestBodyStr,
      );
      final endTime = DateTime.now().millisecondsSinceEpoch;
      print("\t\trequestTime: ${(endTime - startTime)}");
      if (response.statusCode == 200) {
        print('\t\tOpenAI Request successful.');
      } else {
        print(
            '\t\tOpenAI Request failed with status code: ${response.statusCode}');
        print(requestBodyStr);
        await reporter.logFailedRequest(requestBodyStr, logDir);
        return {"errorCode": response.statusCode};
      }
      Map<String, dynamic> responseBody = jsonDecode(response.body);
      responseBody.addAll({"requestTime": (endTime - startTime)});
      await reporter.logRequestAndResponse(
          requestBodyStr, responseBody, logDir);
      //writeMetrics(responseBody, executionId, tag);
      return responseBody;
    } catch (e) {
      throw HttpException('Error occurred during the request: $e',
          uri: Uri.parse("https://api.openai.com/$urlPath"));
    }
  }

  Future<void> downloadImage(String imageUrl, String savePath) async {
    final response = await httpClient.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final file = fileSystem.file(savePath);
      await file.writeAsBytes(bytes);
    } else {
      throw HttpException('Failed to download image', uri: Uri.parse(imageUrl));
    }
  }

  Future<void> saveBase64AsPng(String base64String, String filePath) async {
    Uint8List decodedBytes = base64Decode(base64String);
    File file = fileSystem.file(filePath);
    await file.writeAsBytes(decodedBytes);
  }
}
