import 'dart:convert';

import 'package:file/memory.dart';
import 'package:gpt/src/chatgpt/plugin_server.dart';
import 'package:test/test.dart';

void main() {
  test(
      'createMockedRequestConfigs transforms list of maps into list of MockedRequestConfig objects',
      () {
    var mockedRequests = [
      {
        'path': '/time',
        'method': 'get',
        'mockedResponse': 'time.json',
      },
      {
        'path': '/events',
        'method': 'get',
        'mockedResponse': 'events.json',
      },
      {
        'path': '/image',
        'method': 'get',
        'mockedResponse': '195.png',
        'contentType': 'image/png',
      },
    ];

    final server = PluginServer(MemoryFileSystem());

    var result = server.createMockedRequestConfigs(mockedRequests);

    expect(result, isA<List<MockedRequestConfig>>());
    expect(result.length, 3);

    expect(result[0].path, '/time');
    expect(result[0].method, 'get');
    expect(result[0].mockedResponse, 'time.json');
    expect(result[0].contentType, 'application/json');

    expect(result[1].path, '/events');
    expect(result[1].method, 'get');
    expect(result[1].mockedResponse, 'events.json');
    expect(result[1].contentType, 'application/json');

    expect(result[2].path, '/image');
    expect(result[2].method, 'get');
    expect(result[2].mockedResponse, '195.png');
    expect(result[2].contentType, 'image/png');
  });

  group('PluginServer', () {
    late PluginServer pluginServer;
    late MemoryFileSystem memoryFileSystem;

    setUp(() {
      memoryFileSystem = MemoryFileSystem();
      pluginServer = PluginServer(memoryFileSystem);
      // Setup mock files
      final defaultConfigDir = memoryFileSystem.directory('defaultConfig')
        ..createSync();
      defaultConfigDir
          .childFile('plugin-manifest.prompt')
          .writeAsStringSync('Prompt content');
      defaultConfigDir
          .childFile('ai-plugin.json')
          .writeAsStringSync(jsonEncode({
            "api": {"url": "http://localhost/api"},
            "logo_url": "http://localhost/logo.png"
          }));
      defaultConfigDir.childFile('logo.png').writeAsStringSync('Logo content');
      defaultConfigDir
          .childFile('openapi.yaml')
          .writeAsStringSync('servers:\n  - url: http://localhost');
    });

    test('setup should initialize properties correctly', () async {
      final defaultConfig = {};
      final serverConfig = {
        'properties': {'port': 3000, 'showHttpHeaders': true},
        'flavor': 'flavor1',
        'serverId': 'server1',
        'mockedRequests': [
          {'path': '/time', 'method': 'get', 'mockedResponse': 'time.json'},
        ],
      };

      await pluginServer.setup(defaultConfig, serverConfig);

      expect(pluginServer.flavorDir, 'pluginFlavors/flavor1');
      expect(pluginServer.defaultDir, 'defaultConfig');
      expect(pluginServer.properties['port'], 3000);
      expect(pluginServer.properties['manifestPrompt'], 'Prompt content');
      expect(pluginServer.logoName, 'logo.png');
      expect(pluginServer.port, 3000);
      expect(pluginServer.showHttpHeaders, true);
      expect(pluginServer.mockedRequestConfigs[0].path, '/time');
      expect(pluginServer.mockedRequestConfigs[0].method, 'get');
      expect(pluginServer.mockedRequestConfigs[0].mockedResponse, 'time.json');
    });

    test('setup should fallback to default port if no port is specified',
        () async {
      final defaultConfig = {};
      final serverConfig = {
        'flavor': 'flavor1',
        'serverId': 'server1',
        'configuration': {},
        'mockedRequests': [],
      };

      await pluginServer.setup(defaultConfig, serverConfig);

      expect(pluginServer.port, 80);
    });
  });

  test('mergeMockedRequestConfigs merges and overrides correctly', () {
    final memoryFileSystem = MemoryFileSystem();
    final pluginServer = PluginServer(memoryFileSystem);
    var firstList = [
      MockedRequestConfig(path: "/path1", method: "get", mockedResponse: "response1", contentType: "json"),
      MockedRequestConfig(path: "/path2", method: "get", mockedResponse: "response2", contentType: "json"),
    ];
    var secondList = [
      MockedRequestConfig(path: "/path2", method: "get", mockedResponse: "response2_updated", contentType: "json"),
      MockedRequestConfig(path: "/path3", method: "get", mockedResponse: "response3", contentType: "json"),
    ];

    var result = pluginServer.mergeMockedRequestConfigs(firstList, secondList);

    expect(result, [
      MockedRequestConfig(path: "/path1", method: "get", mockedResponse: "response1", contentType: "json"),
      MockedRequestConfig(path: "/path2", method: "get", mockedResponse: "response2_updated", contentType: "json"),
      MockedRequestConfig(path: "/path3", method: "get", mockedResponse: "response3", contentType: "json"),
    ]);
  });
}
