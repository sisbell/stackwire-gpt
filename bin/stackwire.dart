import 'package:stackwire/experiment_runner.dart';
import 'package:stackwire/files.dart';

Future<String> createPrompt(experimentName, String template, templateValues, outputFile) async {
  RegExp placeholderPattern = RegExp(r'{{([^}]+)}}');
  String modifiedTemplate = template.replaceAllMapped(
      placeholderPattern, (Match match) => templateValues[match[1]] ?? match[0]);

  await writeString(modifiedTemplate, outputFile);

  print('Output file created: $outputFile');
  return modifiedTemplate;
}

void main(List<String> arguments) async {
  String experimentFilePath = arguments.isEmpty ? 'experiment.json' : arguments[0];
  Map<String, dynamic> experiment = await readExperimentFile(experimentFilePath);

  Map<String, dynamic> aiConfig = experiment["ai_config"];
  final runs = experiment["number_of_runs"];
  final experimentName = experiment["experiment_name"];
  final templateValues = experiment['template_values'];
  final outputDirName = experiment['output_dir'];
  final apiKeyFile = experiment['api_key_file'];
  final apiKey = await readFileAsString(apiKeyFile);

  createDirectoryIfNotExist("$outputDirName/$experimentName/data");
  writeMap(aiConfig, "$outputDirName/$experimentName/config.ai");
  String promptAiFile = "$outputDirName/$experimentName/prompt.ai";
  String templateFilePath = experiment['prompt_template'];
  String template = await readFileAsString(templateFilePath);
  final prompt = await createPrompt(experimentName, template, templateValues, promptAiFile);

  List<Map<String, dynamic>> messages = [
    {"role": "user", "content": prompt},
  ];
  aiConfig['messages'] = messages;

  runExperiment(experimentName, outputDirName, aiConfig, apiKey, runs);
}



