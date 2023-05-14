part of gpt_plugins;

class ImageGptPlugin extends GptPlugin {
  ImageGptPlugin(super.projectConfig, super.block,
      {super.fileSystem, super.networkClient});

  late String executionId;

  late String imagePromptFile;

  late String imagesDir;

  late List<dynamic> imageRequests;

  @override
  num apiCallCount() {
    return imageRequests.length;
  }

  @override
  Future<void> init(execution, pluginConfiguration) async {
    executionId = execution["id"];
    imagePromptFile = execution["prompt"];
    final promptTemplate = await ioHelper.readFileAsString(imagePromptFile);
    imagesDir = "$reportDir/images/$blockId";
    await ioHelper.createDirectoryIfNotExist(imagesDir);
    imageRequests = await createImageRequest(execution, promptTemplate);
  }

  @override
  Future<void> doExecution(results, dryRun) async {
    for (var i = 1; i <= imageRequests.length; i++) {
      final image = imageRequests[i - 1];
      final response = await makeImageGenerationRequest(
          image, executionId, imagePromptFile, dryRun);
      final result = {
        "prompt": image["prompt"],
        "size": image["size"],
        "images": response["data"]
      };
      results.add(result);
    }
  }

  @override
  Future<void> report(results) async {
    for (var result in results) {
      final images = result["images"];
      for (var image in images) {
        final url = image["url"];
        if (url != null) {
          final imageName = getLastPathSegment(url);
          networkClient.downloadImage(url, "$imagesDir/$imageName");
        }
        final b64 = image["b64_json"];
        if (b64 != null) {
          final imageName = DateTime.now().millisecond;
          networkClient.saveBase64AsPng(b64, "$imagesDir/$imageName.png");
        }
      }
    }
    print("Finished generating images");
  }

  Future<List<dynamic>> createImageRequest(execution, promptTemplate) async {
    final templateProperties = execution["properties"];
    final prompt =
        substituteTemplateProperties(promptTemplate, templateProperties);
    final responseFormat = execution["responseFormat"] ?? "url";
    final imageCount = execution["imageCount"] ?? 1;
    final sizes = execution["sizes"];
    final imageRequests = [];
    for (int size in sizes) {
      final imageRequest = {
        "prompt": prompt,
        "n": imageCount,
        "size": createImageSize(size),
        "response_format": responseFormat
      };
      imageRequests.add(imageRequest);
    }
    return imageRequests;
  }

  String createImageSize(size) {
    if (size == 256) {
      return "256x256";
    } else if (size == 512) {
      return "512x512";
    } else if (size == 1024) {
      return "1024x1024";
    } else {
      throw ArgumentError("Invalid image size: $size", "execution.sizes");
    }
  }

  String getLastPathSegment(String url) {
    Uri uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  }

  Future<Map<String, dynamic>> makeImageGenerationRequest(
      requestBody, executionId, tag, dryRun) async {
    final toDirectory = "$blockDataDir/$currentBlockRun";
    return networkClient.sendHttpPostRequest(
        requestBody, "v1/images/generations", toDirectory,
        dryRun: dryRun);
  }

}
