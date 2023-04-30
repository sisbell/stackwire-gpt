import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> makeChatCompletionRequest(
    requestBody, apiKey) async {
  return sendHttpPostRequest(requestBody, apiKey, "v1/chat/completions");
}

Future<Map<String, dynamic>> makeImageGenerationRequest(
    requestBody, apiKey) async {
  return sendHttpPostRequest(requestBody, apiKey, "v1/images/generations");
}

Future<Map<String, dynamic>> sendHttpPostRequest(
    requestBody, apiKey, urlPath) async {
  print("Making call to OpenAi");
  try {
    final client = HttpClient();
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final request =
        await client.postUrl(Uri.parse("https://api.openai.com/$urlPath"));
    request.headers.add(HttpHeaders.contentTypeHeader, "application/json");
    request.headers.add(HttpHeaders.authorizationHeader, "Bearer $apiKey");
    request.write(requestBody);
    HttpClientResponse response = await request.close();
    final endTime = DateTime.now().millisecondsSinceEpoch;
    print("requestTime: ${(endTime - startTime)}");
    if (response.statusCode == 200) {
      print('Request successful.');
    } else {
      print('Request failed with status code: ${response.statusCode}');
      return {"errorCode": response.statusCode};
    }
    Map<String, dynamic> responseBody =
        jsonDecode(await readResponse(response));
    responseBody.addAll({"requestTime": (endTime - startTime)});
    return responseBody;
  } catch (e) {
    print('Error occurred during the request: $e');
  }
  return {};
}

Future<String> readResponse(HttpClientResponse response) async {
  return response.transform(utf8.decoder).join();
}
