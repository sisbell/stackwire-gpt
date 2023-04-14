import 'package:stackwire/experiment_runner.dart';
import 'package:stackwire/files.dart';

void main(List<String> arguments) async {
  String experimentFilePath = arguments.isEmpty ? 'experiment.json' : arguments[0];
  Map<String, dynamic> experiment = await readExperimentFile(experimentFilePath);

  final aiConfig = experiment["ai_config"];
  final experimentName = experiment["experiment_name"];
  final outputDirName = experiment['output_dir'];
  final apiKeyFile = experiment['api_key_file'];
  final apiKey = await readFileAsString(apiKeyFile);

  createDirectoryIfNotExist("$outputDirName/$experimentName/data");
  writeMap(aiConfig, "$outputDirName/$experimentName/config.ai");

  final experimentData = {
    "experimentName": experimentName,
    "promptTemplateFilePath": experiment['prompt_template'],
    "templateValues":  experiment['template_values'],
    "apiKey" : apiKey,
    "outputDir": outputDirName,
    "runs" : experiment["number_of_runs"],
    "runDepth" : experiment['run_depth'] ?? 0,
    "promptAiFile": "$outputDirName/$experimentName/prompt.ai",
    "responseFormat" : experiment['response_format'] ?? "text"
  };
  runExperiment(experimentData, aiConfig);
}
