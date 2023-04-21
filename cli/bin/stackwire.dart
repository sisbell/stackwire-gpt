
import 'package:eom/experiment_runner.dart';
import 'package:eom/files.dart';

void main(List<String> arguments) async {
  String experimentFilePath = arguments.isEmpty ? 'experiment.eom' : arguments[0];
  Map<String, dynamic> experiment = await readExperimentFile(experimentFilePath);

  final aiConfig = experiment["ai_config"];
  final experimentName = experiment["experiment_name"];
  final outputDirName = experiment['output_dir'] ?? "output";
  final apiKeyFile = experiment['api_key_file'] ?? "api_key";
  final apiKey = await readFileAsString(apiKeyFile);

  createDirectoryIfNotExist("$outputDirName/$experimentName/data");
  writeMap(aiConfig, "$outputDirName/$experimentName/config.ai");

  Map<String, dynamic> prompts = experiment['prompts'];
  String? systemMessageFile = prompts['system_message_file'];
  final systemMessage = systemMessageFile != null ? await readFileAsString(systemMessageFile) : null;
  int chainRuns = prompts['chain_runs'] ?? 1;

  List<dynamic> promptChain = prompts['chain'];
  List<Future<String>> futurePrompts = promptChain.map((e) async => await readFileAsString(e)).toList();
  List<String> promptTemplates = await Future.wait(futurePrompts);

  final experimentConfig = {
    "experimentName": experimentName,
    "promptTemplates": promptTemplates,
    "promptChains" :prompts['chain'],
    "promptProperties":  prompts['properties'] ?? {},
    "excludesMessageHistory" : prompts["excludesMessageHistory"] ?? [],
    "apiKey" : apiKey,
    "outputDir": outputDirName,
    "experimentRuns" : experiment["experiment_runs"] ?? 1,
    "chainRuns" : chainRuns,
    "responseFormat" : experiment['response_format'] ?? "text",
    "systemMessage" : systemMessage,
    "fixJson" : prompts["fixJson"] ?? false
  };
  runExperiment(experimentConfig, aiConfig);
}
