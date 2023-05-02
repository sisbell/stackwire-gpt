part of gpt_plugins;

class ImageGptPlugin extends GptPlugin {
  ImageGptPlugin(
      super.projectConfig, super.executionBlock, super.reporter, super.io);

  @override
  Future<void> doExecution(
      execution, pluginConfiguration, results, blockRun) async {
    final imagesDir = "$reportDir/images/$blockId";
    createDirectoryIfNotExist(imagesDir);
    final imageConfigs = await createImageConfigs(execution);
    for (var i = 1; i <= imageConfigs.length; i++) {
      final image = imageConfigs[i - 1];
      final imageStr = jsonEncode(image);
      final response = await makeImageGenerationRequest(imageStr, apiKey);
      await reporter.logRequestAndResponse(imageStr, response, blockDataDir, i);
      final result = {
        "prompt": image["prompt"],
        "size": image["size"],
        "images": response["data"]
      };
      results.add(result);
    }

    for (var result in results) {
      final images = result["images"];
      for (var image in images) {
        final url = image["url"];
        if (url != null) {
          final imageName = getLastPathSegment(url);
          downloadImage(url, "$imagesDir/$imageName");
        }
        final b64 = image["b64_json"];
        if (b64 != null) {
          final imageName = DateTime.now().millisecond;
          saveBase64AsPng(b64, "$imagesDir/$imageName.png");
        }
      }
    }
    print("Finished generating images");
  }

  String getLastPathSegment(String url) {
    Uri uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  }

  Future<List<dynamic>> createImageConfigs(execution) async {
    final imagePromptFile = execution["prompt"];
    final promptTemplate = await io.readFileAsString(imagePromptFile);
    final templateProperties = execution["properties"];
    final prompt = createPrompt(promptTemplate, templateProperties);
    final responseFormat = execution["responseFormat"];
    final imageCount = execution["imageCount"];
    final sizes = execution["sizes"];
    final imageConfigs = [];
    for (int size in sizes) {
      final imageConfig = {
        "prompt": prompt,
        "n": imageCount,
        "size": createImageSize(size),
        "response_format": responseFormat
      };
      imageConfigs.add(imageConfig);
    }
    return imageConfigs;
  }

  String createImageSize(size) {
    if (size == 256) {
      return "256x256";
    } else if (size == 512) {
      return "512x512";
    } else if (size == 1024) {
      return "1024x1024";
    } else {
      throw Exception("Invalid image size: $size");
    }
  }
}
