import 'package:args/command_runner.dart';
import 'package:file/local.dart';
import 'package:gpt/src/archetypes.dart';
import 'package:gpt/src/io_helper.dart';
import 'package:gpt/src/prompts.dart';
import 'package:interact/interact.dart';
import 'package:path/path.dart' as path;

final localFileSystem = LocalFileSystem();

final ioHelper = IOHelper(fileSystem: localFileSystem);

class ArchetypeCommand extends Command {
  @override
  String get description => "Generates a new project";

  @override
  String get name => "genp";

  @override
  void run() async {
    final builder = ArchetypeBuilder(localFileSystem);
    final archetypeDirectory = await builder.downloadArchetypeArchive();
    final archetypeDirectories = {
      "ChatGPT Plugin": "plugins-quickstart",
      "ZapVine Plugin Catalog": "plugin-catalog",
      "Chain": "chain",
      "Prompt": "prompt",
      "Batch": "batch",
      "Image": "image"
    };
    final projectTypes = [
      'ChatGPT Plugin',
      'ZapVine Plugin Catalog',
      'Prompt',
      'Chain',
      'Batch',
      'Image'
    ];
    final selectedProjectIndex = Select(
      prompt: 'Project Archetype',
      options: projectTypes,
      initialIndex: 0,
    ).interact();

    final projectName = (selectedProjectIndex == 1)
        ? "PluginCatalog"
        : Input(prompt: 'Project Name: ', defaultValue: "MyProject").interact();
    final projectVersion = (selectedProjectIndex == 1)
        ? "1.0"
        : Input(prompt: 'Project Version: ', defaultValue: "1.0").interact();
    final projectSelection = projectTypes[selectedProjectIndex];
    final archetypeName = archetypeDirectories[projectSelection];
    final projectDir = localFileSystem.directory(projectName);
    final sourceDir =
        localFileSystem.directory(path.join(archetypeDirectory, archetypeName));
    await ioHelper.copyDirectoryContents(sourceDir, projectDir);
    Map<String, dynamic> templateProperties = {
      "projectName": projectName,
      "projectVersion": projectVersion
    };
    if (selectedProjectIndex == 0) {
      //plugins
    } else if (selectedProjectIndex == 1) {
      //catalog
    } else if (selectedProjectIndex == 2) {
      //prompt
      askImportKey(templateProperties, projectName);
      askBlockRuns(templateProperties);
      askResponseFormat(templateProperties);
    } else if (selectedProjectIndex == 3) {
      //chain
      askImportKey(templateProperties, projectName);
      askBlockRuns(templateProperties);
      askFixJson(templateProperties);
      templateProperties.addAll({"responseFormat": "json"});
      askChainRuns(templateProperties);
    } else if (selectedProjectIndex == 4) {
      //batch
      askImportKey(templateProperties, projectName);
      askBlockRuns(templateProperties);
    } else if (selectedProjectIndex == 5) {
      //image
      askImportKey(templateProperties, projectName);
      askImageDescription(templateProperties);
    }
    print(templateProperties);
    final projectYaml = await builder.readProjectYaml(projectName);
    final calculatedProjectYaml =
        substituteTemplateProperties(projectYaml, templateProperties);
    final isValid = builder.verifyYamlFormat(calculatedProjectYaml);
    if (isValid) {
      await ioHelper.writeString(
          calculatedProjectYaml, "$projectName/project.yaml");
      print("Created Project");
    } else {
      print("Invalid yaml file. Project not created");
    }
  }

  void askBlockRuns(templateProperties) {
    final blockRuns =
        Input(prompt: 'Number of Times to Run The Block: ').interact();
    templateProperties.addAll({"blockRuns": blockRuns});
  }

  void askChainRuns(templateProperties) {
    final blockRuns =
        Input(prompt: 'Number of Times to Run The Prompt Chain: ').interact();
    templateProperties.addAll({"chainRuns": blockRuns});
  }

  void askFixJson(templateProperties) {
    final fixJSONConfirmation = Confirm(
      prompt: 'Attempt to FIX JSON Responses?',
      defaultValue: false,
    ).interact();
    templateProperties.addAll({"fixJson": fixJSONConfirmation.toString()});
  }

  void askImageDescription(templateProperties) {
    final imageDescription = Input(prompt: 'Image Description: ').interact();
    templateProperties.addAll({"imageDescription": imageDescription});
  }

  void askImportKey(templateProperties, projectName) {
    final keyTypes = [
      'Skip',
      'Use Existing OpenAI API Key File',
      'Create New OpenAI API Key File'
    ];
    final selectedKeyIndex = Select(
      prompt: 'Import Key',
      options: keyTypes,
      initialIndex: 0,
    ).interact();

    if (selectedKeyIndex == 1) {
      final keyFile = Input(prompt: 'API Key File: ').interact();
      templateProperties.addAll({"apiKeyFile": keyFile});
    } else if (selectedKeyIndex == 2) {
      final key = Input(prompt: 'API Key: ').interact();
      ioHelper.writeString(key, "$projectName/api_key");
      templateProperties.addAll({"apiKeyFile": "api_key"});
    }
  }

  void askResponseFormat(templateProperties) {
    final outputTypes = ['JSON', 'TEXT'];
    final selectedOutputIndex = Select(
      prompt: 'Response Format',
      options: outputTypes,
      initialIndex: 1,
    ).interact();
    if (selectedOutputIndex == 0) {
      templateProperties.addAll({"responseFormat": "json"});
      templateProperties.addAll({"promptName": "prompt-json.prompt"});
      askFixJson(templateProperties);
    } else {
      templateProperties.addAll({"responseFormat": "text"});
      templateProperties.addAll({"promptName": "prompt-text.prompt"});
      templateProperties.addAll({"fixJson": false.toString()});
    }
  }
}
