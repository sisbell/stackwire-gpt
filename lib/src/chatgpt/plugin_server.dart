import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:path/path.dart' as path;

import '../io_helper.dart';
import '../prompts.dart';

class PluginServer {
  late File aiPluginFile;

  late File logoFile;

  late String logoName;

  late File openapiFile;

  late int port;

  String? promptFileName;

  final ioHelper = IOHelper(fileSystem: LocalFileSystem());

  late List<dynamic> requestConfigs;

  late bool showHttpHeaders;

  Future<void> setup(serverConfig) async {
    print(serverConfig);
    final serverId = serverConfig["serverId"];
    final configuration = serverConfig["configuration"];
    final requests = serverConfig["requests"];
    final resources = serverConfig["resources"];

    aiPluginFile = File(resources["aiPlugin"]);
    final aiPlugin = await ioHelper.readJsonFile(aiPluginFile.path);
    final openapiUrl = aiPlugin["api"]["url"];
    final logo = aiPlugin["logo_url"];
    final logoUri = Uri.parse(logo);
    logoName = logoUri.pathSegments.last;
    logoFile = File(resources["logo"]);

    openapiFile = File(resources["openapi"]);
    final openapi = await ioHelper.readYamlFile(openapiFile.path);
    final serverUri = openapi["servers"][0]["url"];
    final uri = Uri.parse(serverUri);
    port = uri.port;

    promptFileName = configuration["prompt"];
    showHttpHeaders = configuration["showHttpHeaders"] ?? false;

    print("Setting up plugin server: $serverId");
    print(serverUri);
    print("$serverUri/.well-known/ai-plugin.json");
    print(openapiUrl);
    print(logo);
    print("\nRegistering endpoints");
    requestConfigs = requests
        .map((request) => RequestConfig(
            path: request['path'],
            response: request['response'],
            method: request['method'],
            contentType: request['contentType'] ?? "application/json"))
        .toList();

    for (var config in requestConfigs) {
      print("${config.method.toUpperCase()} - $serverUri${config.path}");
    }
  }

  void start() async {
    var server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    print('\nListening on localhost:${server.port}\n');

    await for (HttpRequest request in server) {
      handleRequest(request);
    }
  }

  void writeImage(request, imageFile) {
    var extensionWithDot = path.extension(imageFile.path);
    var extensionWithoutDot =
        extensionWithDot.isNotEmpty ? extensionWithDot.substring(1) : '';
    request.response.headers.contentType =
        ContentType('image', extensionWithoutDot);
    imageFile.openRead().pipe(request.response).catchError((e) {
      print('Error occurred while reading image: $e');
    });
  }

  void writeString(request, contentFile, contentType) {
    request.response.headers.contentType = contentType;
    contentFile.openRead().pipe(request.response).catchError((e) {
      print('Error occurred: $e');
    });
  }

  Future<Map<String, dynamic>> getProperties() async {
    if (promptFileName != null) {
      final prompt = await ioHelper.readFileAsString(promptFileName!);
      final newPrompt = prompt.replaceAll('\n', '').replaceAll('\r', '');
      return {"prompt": newPrompt};
    }
    return {};
  }

  void handleRequest(HttpRequest request) async {
    request.response.headers
        .add('Access-Control-Allow-Origin', 'https://chat.openai.com');
    request.response.headers
        .add('Access-Control-Allow-Methods', 'GET,POST,DELETE,PUT,OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');
    final path = request.uri.path;
    final requestMethod = request.method;

    print("${DateTime.now()} Request: $requestMethod - $path");
    if (showHttpHeaders) {
      request.headers.forEach((String name, List<String> values) {
        print('\t$name: $values');
      });
    }
    var body = await utf8.decoder.bind(request).join();
    if (body.isNotEmpty) {
      print(body);
    }
    if (path.endsWith(logoName)) {
      writeImage(request, logoFile);
    } else if (path.endsWith("openapi.yaml")) {
      final yamlTemplate = await ioHelper.readFileAsString(openapiFile.path);
      final properties = await getProperties();
      final content = substituteTemplateProperties(yamlTemplate, properties);
      request.response
        ..headers.contentType = ContentType("text", "yaml")
        ..write(content)
        ..close();
    } else if (path.endsWith("ai-plugin.json")) {
      writeString(request, aiPluginFile, ContentType("application", "json"));
    } else {
      final config = getRequestConfig(request);
      if (config != null) {
        var file = File(config.response);
        if (file.existsSync()) {
          print("\tUsing response file ${file.path}");
          final contentType = config.contentType == "application/json"
              ? ContentType.json
              : ContentType.text;
          request.response
            ..headers.contentType = contentType
            ..add(file.readAsBytesSync())
            ..close();
        }
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..write("{}")
          ..close();
      }
    }
  }

  RequestConfig? getRequestConfig(HttpRequest request) {
    return requestConfigs.firstWhere(
      (config) =>
          request.uri.path == config.path &&
          request.method.toLowerCase() == config.method,
      orElse: () => null,
    );
  }
}

class RequestConfig {
  final String path;
  final String response;
  final String method;
  final String contentType;

  RequestConfig(
      {required this.path,
      required this.response,
      required this.method,
      required this.contentType});
}
