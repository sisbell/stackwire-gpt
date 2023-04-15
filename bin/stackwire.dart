import 'package:stackwire/experiment_runner.dart';
import 'package:stackwire/files.dart';

void main(List<String> arguments) async {
  String experimentFilePath = arguments.isEmpty ? 'experiment.json' : arguments[0];
  Map<String, dynamic> experiment = await readExperimentFile(experimentFilePath);

  final aiConfig = experiment["ai_config"];
  final experimentName = experiment["experiment_name"];
  final outputDirName = experiment['output_dir'] ?? "output";
  final apiKeyFile = experiment['api_key_file'] ?? "api_key.txt";
  final apiKey = await readFileAsString(apiKeyFile);

  createDirectoryIfNotExist("$outputDirName/$experimentName/data");
  writeMap(aiConfig, "$outputDirName/$experimentName/config.ai");

  Map<String, dynamic>? chat = experiment['chat'];
  String? systemMessageFile = chat?['system_message_file'];
  final systemMessage = systemMessageFile != null ? await readFileAsString(systemMessageFile) : null;
  int runDepth = chat?['run_depth'] ?? 0;

  Map<String, dynamic> prompts = experiment['prompts'];
  final templateFile = prompts["template_file"];
  final template = await readFileAsString(templateFile);

  final experimentData = {
    "experimentName": experimentName,
    "promptTemplate": template,
    "promptProperties":  prompts['properties'] ?? {},
    "apiKey" : apiKey,
    "outputDir": outputDirName,
    "runs" : experiment["number_of_runs"] ?? 1,
    "runDepth" : runDepth,
    "promptAiFile": "$outputDirName/$experimentName/prompt-calculated.ai",
    "responseFormat" : experiment['response_format'] ?? "text",
    "systemMessage" : systemMessage
  };
  print(experimentData);
  runExperiment(experimentData, aiConfig);
}
