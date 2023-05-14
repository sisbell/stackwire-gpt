import 'package:file/memory.dart';
import 'package:gpt/src/gpt_plugin.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('createImageRequest', () {
    test('should return list of image request for each size', () async {
      final promptTemplate = "Create image of a \${creature} with \${feature}";

      final execution = {
        "id": "img-unicorn",
        "sizes": [256, 512],
        "prompt": "image.prompt",
        "properties": {
          "creature": "Unicorn",
          "feature": "a gold horn and wings"
        }
      };
      final plugin = ImageGptPlugin(testProjectConfig, testBlock,
          fileSystem: MemoryFileSystem());
      final imageRequests =
          await plugin.createImageRequest(execution, promptTemplate);

      expect(imageRequests, isNotNull);
      expect(imageRequests, isNotEmpty);
      expect(imageRequests.length, 2);
      expect(imageRequests[0]["prompt"],
          "Create image of a Unicorn with a gold horn and wings");
      expect(imageRequests[0]["n"], 1);
      expect(imageRequests[0]["size"], "256x256");
      expect(imageRequests[0]["response_format"], "url");
    });

    test('createImageRequest should return an empty list when sizes is empty',
        () async {
      final promptTemplate = "Create image of a \${creature} with \${feature}";
      final plugin = ImageGptPlugin(testProjectConfig, testBlock,
          fileSystem: MemoryFileSystem());
      final execution = {
        "properties": {
          "creature": "Unicorn",
          "feature": "a gold horn and wings"
        },
        "responseFormat": "url",
        "imageCount": 1,
        "sizes": []
      };
      final result = await plugin.createImageRequest(execution, promptTemplate);
      expect(result, []);
    });

    test('createImageRequest should use the provided responseFormat', () async {
      final promptTemplate = "Create image of a \${creature} with \${feature}";
      final plugin = ImageGptPlugin(testProjectConfig, testBlock,
          fileSystem: MemoryFileSystem());
      final execution = {
        "properties": {
          "creature": "Unicorn",
          "feature": "a gold horn and wings"
        },
        "responseFormat": "b64_json",
        "imageCount": 1,
        "sizes": [256]
      };
      final result = await plugin.createImageRequest(execution, promptTemplate);
      expect(result[0]['response_format'], 'b64_json');
    });

    test('createImageRequest should use url as the default responseFormat',
        () async {
      final promptTemplate = "Create image of a \${creature} with \${feature}";
      final plugin = ImageGptPlugin(testProjectConfig, testBlock,
          fileSystem: MemoryFileSystem());
      final execution = {
        "properties": {
          "creature": "Unicorn",
          "feature": "a gold horn and wings"
        },
        "imageCount": 1,
        "sizes": [256]
      };
      final result = await plugin.createImageRequest(execution, promptTemplate);
      expect(result[0]['response_format'], 'url');
    });
  });

  group('createImageSize', () {
    late ImageGptPlugin plugin;

    setUp(() {
      plugin = ImageGptPlugin(testProjectConfig, testBlock,
          fileSystem: MemoryFileSystem());
    });

    test('returns "256x256" when size is 256', () {
      expect(plugin.createImageSize(256), equals('256x256'));
    });

    test('returns "512x512" when size is 512', () {
      expect(plugin.createImageSize(512), equals('512x512'));
    });

    test('returns "1024x1024" when size is 1024', () {
      expect(plugin.createImageSize(1024), equals('1024x1024'));
    });

    test('throws ArgumentError when size is not 256, 512, or 1024', () {
      expect(() => plugin.createImageSize(123), throwsA(isA<ArgumentError>()));
    });
  });
}
