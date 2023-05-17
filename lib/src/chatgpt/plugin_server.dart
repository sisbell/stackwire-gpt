import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import '../io_helper.dart';
import '../prompts.dart';

class PluginServer {
  late File apiFile;

  late String defaultDir;

  final FileSystem fileSystem;

  String? flavorDir;

  late IOHelper ioHelper;

  late File logoFile;

  late String logoName;

  late File manifestFile;

  late int port;

  late List<MockedRequestConfig> mockedRequestConfigs;

  late Map<String, dynamic> properties;

  late bool showHttpHeaders;

  PluginServer(this.fileSystem) {
    ioHelper = IOHelper(fileSystem: fileSystem);
  }

  Future<void> setup(defaultConfig, serverConfig) async {
    final defaultProperties =
        defaultConfig['properties'] ?? <String, dynamic>{};
    final serverProperties = serverConfig['properties'] ?? <String, dynamic>{};

    final flavor = serverConfig["flavor"];
    flavorDir = "pluginFlavors/$flavor";
    defaultDir = "defaultConfig";

    properties = {...serverProperties, ...defaultProperties};
    final prompt = await findResource("plugin-manifest.prompt");
    final content = await ioHelper.readFileAsString(prompt.path);
    final newContent = content.replaceAll('\n', '').replaceAll('\r', '');
    properties.addAll({"manifestPrompt": newContent});

    final serverId = serverConfig["serverId"];
    final mockedRequests = serverConfig["mockedRequests"]; //merge

    manifestFile = await findResource("ai-plugin.json");
    print("Found plugin manifest: ${manifestFile.path}");
    String manifestTemplate =
        await ioHelper.readFileAsString(manifestFile.path);
    String manifestString =
        substituteTemplateProperties(manifestTemplate, properties);
    final manifest = jsonDecode(manifestString);
    final apiUrl = manifest["api"]["url"];
    final logo = manifest["logo_url"];
    List<String> parts = logo.split('/');
    logoName = parts.last;
    logoFile = await findResource(logoName);

    apiFile = await findResource("openapi.yaml");
    print("Found OpenAPI Spec: ${apiFile.path}\n");
    String apiTemplate = await ioHelper.readFileAsString(apiFile.path);
    String apiString = substituteTemplateProperties(apiTemplate, properties);
    final api = await ioHelper.readYaml(apiString);
    final serverUri = api["servers"][0]["url"];
    if (properties.containsKey("port")) {
      port = properties["port"];
    } else {
      final uri = Uri.parse(serverUri);
      port = uri.port;
    }
    showHttpHeaders = properties["showHttpHeaders"] ?? false;

    print("Setting up plugin server: $serverId");
    print(serverUri);
    print("$serverUri/.well-known/ai-plugin.json");
    print(apiUrl);
    print(logo);
    print("\nRegistering endpoints");
    final defaultMocks = defaultConfig['mockedRequests'] ?? [];
    final defaultMockedRequests = createMockedRequestConfigs(defaultMocks);
    mockedRequestConfigs = createMockedRequestConfigs(mockedRequests);
    mockedRequestConfigs =
        mergeMockedRequestConfigs(mockedRequestConfigs, defaultMockedRequests);
    for (var config in mockedRequestConfigs) {
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
      writeLogo(request);
    } else if (path.endsWith("openapi.yaml")) {
      await writeTemplate(request, apiFile, ContentType("text", "yaml"));
    } else if (path.endsWith("ai-plugin.json")) {
      await writeTemplate(
          request, manifestFile, ContentType("application", "json"));
    } else {
      final config = getRequestConfig(request);
      if (config != null) {
        var file = fileSystem.file(await findMock(config.mockedResponse));
        if (file.existsSync()) {
          print("\tUsing response file ${file.path}");
          final contentType = ContentType.parse(config.contentType);
          request.response
            ..headers.contentType = contentType
            ..add(file.readAsBytesSync())
            ..close();
        } else {
          print("\tFile for mock resource not found: ${file.path}");
        }
      } else {
        print("\tNo handler for this request found");
        request.response
          ..headers.contentType = ContentType.json
          ..write("{}")
          ..close();
      }
    }
  }

  List<MockedRequestConfig> createMockedRequestConfigs(
      List<dynamic> mockedRequests) {
    return mockedRequests
        .map((dynamic request) => MockedRequestConfig(
            path: (request as Map<String, dynamic>)['path'],
            mockedResponse: (request)['mockedResponse'],
            method: (request)['method'],
            contentType: (request)['contentType'] ?? "application/json"))
        .toList();
  }

  List<MockedRequestConfig> mergeMockedRequestConfigs(
    List<MockedRequestConfig> firstList,
    List<MockedRequestConfig> secondList,
  ) {
    final firstMap =
        Map.fromEntries(firstList.map((e) => MapEntry(e.method + e.path, e)));
    final secondMap =
        Map.fromEntries(secondList.map((e) => MapEntry(e.method + e.path, e)));
    firstMap.addAll(secondMap);
    return firstMap.values.toList();
  }

  Future<File> findResource(fileName) async {
    return await ioHelper.findFile(flavorDir, defaultDir, fileName);
  }

  Future<File> findMock(fileName) async {
    return await findResource("mocks/$fileName");
  }

  MockedRequestConfig? getRequestConfig(HttpRequest request) {
    for (var config in mockedRequestConfigs) {
      if (request.uri.path == config.path &&
          request.method.toLowerCase() == config.method.toLowerCase()) {
        return config;
      }
    }
    return null;
  }

  void writeLogo(request) {
    var extensionWithDot = path.extension(logoFile.path);
    var extensionWithoutDot =
        extensionWithDot.isNotEmpty ? extensionWithDot.substring(1) : '';
    request.response.headers.contentType =
        ContentType('image', extensionWithoutDot);
    logoFile.openRead().pipe(request.response).catchError((e) {
      print('Error occurred while reading image: $e');
    });
  }

  void writeString(request, contentFile, contentType) {
    request.response.headers.contentType = contentType;
    contentFile.openRead().pipe(request.response).catchError((e) {
      print('Error occurred: $e');
    });
  }

  Future<void> writeTemplate(request, templateFile, contentType) async {
    final template = await ioHelper.readFileAsString(templateFile.path);
    final content = substituteTemplateProperties(template, properties);
    request.response
      ..headers.contentType = contentType
      ..write(content)
      ..close();
  }
}

class MockedRequestConfig {
  final String path;
  final String mockedResponse;
  final String method;
  final String contentType;

  MockedRequestConfig(
      {required this.path,
      required this.mockedResponse,
      required this.method,
      required this.contentType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockedRequestConfig &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          mockedResponse == other.mockedResponse &&
          method == other.method &&
          contentType == other.contentType;

  @override
  int get hashCode =>
      path.hashCode ^
      mockedResponse.hashCode ^
      method.hashCode ^
      contentType.hashCode;
}
