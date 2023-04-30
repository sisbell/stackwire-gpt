import 'dart:convert';
import 'package:gpt/src/gpt_client.dart';
import 'package:gpt/src/gpt_command.dart';
import 'package:gpt/src/reporter.dart';

class ImageGptCommand extends GptCommand {
  ImageGptCommand(super.projectConfig, super.reporter, super.io);

  Future<void> run() async {
    final projectRuns = projectConfig["projectRuns"];
    final images = projectConfig["images"];
    final imagesDir = "$reportDir/images";
    createDirectoryIfNotExist(imagesDir);
    final results = [];
    for (var projectRun = 1; projectRun <= projectRuns; projectRun++) {
      print("Project Run: $projectRun");
      for (var i = 1; i <= images.length; i++) {
        final image = images[i - 1];
        final imageStr = jsonEncode(image);
        final response = await makeImageGenerationRequest(imageStr, apiKey);
        await reporter.logRequestAndResponse(imageStr, response, dataDir, i);
        final result = {
          "prompt": image["prompt"],
          "size": image["size"],
          "images": response["data"]
        };
        results.add(result);
      }
    }
    await reporter.writeResultsTo({
      "projectName": projectName,
      "projectVersion": projectVersion,
      "results": results
    }, reportDir);

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
}
