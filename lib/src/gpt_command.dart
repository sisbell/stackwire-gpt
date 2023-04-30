import 'io/io.dart';
import 'reporter.dart';

class GptCommand {
  IO io;
  Map<String, dynamic> projectConfig;
  Reporter reporter;
  late String apiKey;
  late String dataDir;
  late String outputDir;
  late String projectName;
  late String projectVersion;
  late String reportDir;

  GptCommand(this.projectConfig, this.reporter, this.io) {
    apiKey = projectConfig["apiKey"];
    outputDir = projectConfig["outputDir"];
    projectName = projectConfig["projectName"];
    projectVersion = projectConfig["projectVersion"];
    reportDir = projectConfig["reportDir"];
    dataDir = projectConfig["dataDir"];
  }

  void createDirectoryIfNotExist(directory) {
    io.createDirectoryIfNotExist(directory);
  }
}
