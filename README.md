A command line tool for running GPT commands. This tool supports prompt-batching and prompt-chaining.

> Currently only chat completion and image generation APIs are supported.

This is the tool I use for refining the StanTrek and StanQuest games. It demonstrates some of the techniques I use for the game.

## Features
Use this tool to
* Create **batch** processing of GPT requests. Run a set of data against a prompt and record the responses.
* Create **experiments** to see how different config parameters and prompts affect performance and output.
* Create **images** with DALL-E

## Getting Started
You will need to create an OpenAI API Key. If you have an account, you can create a key here

https://platform.openai.com/account/api-keys

> Do not share your API key with others, or expose it in the browser or other client-side code.
> You will incur any charges if someone uses your key. Don't check your key into any public repository.

Create a file that contains your API Key (the one below is not real). In our example. we name the file **api_key** and add the key.
```
sk-gKtTxOumv4orO6cfWlh0ZK
```
## Install This tool
Make sure your have dart installed. Follow the instructions, in the link below.

https://dart.dev/get-dart

After installation, you can install the gpt program with the following command

> dart pub global activate gpt

## Usage
The following are the use cases supported
* [Generate ChatGPT Plugin](#generate-chatgpt-plugin)
* [Generate Image Project](#generate-image-project)
* [Generate Batch Project](#generate-batch-project)
* [Generate Prompt Project](#generate-prompt-project)
* [Generate Chain Project](#generate-chain-project)
* [Add Report Plugin](#add-report-plugin)

## Creating Projects
Run the generate project command
```
air genp 
```
You will first need to select the archetype
```
? Project Archetype ›                                                                                                                                                                                                                
❯ Prompt                                                                                                                                                                                                                             
  Chain                                                                                                                                                                                                                              
  Batch                                                                                                                                                                                                                              
  Image                                                                                                                                                                                                                              
  ChatGPT Plugin  
```
Enter the projectName and projectVersion
```
✔ Project Archetype · Prompt
✔ Project Name:  · myproject 
✔ Project Version:  · 1.0
```

Depending on the project, you may need to enter your API Key. You can skip, use an existing key file or create a new key file
```
? Import Key › 
❯ Skip      
  Use Existing OpenAI API Key File 
  Create New OpenAI API Key File 
```
The following option allows us to enter the api key directly. It will 
save the key to a file. If you have trouble copying and pasting the key, 
just enter a few characters and then edit the file afterwards.
```                                                                                                                                                                                                   
✔ Import Key · Create New OpenAI API Key File
? API Key:  › sk-gKtTxOumv4orO6cfWlh0ZK
```
### Generate ChatGPT Plugin
The ChatGPT Plugin project allows you to do rapid prototyping of a ChatGPT Plugin. Specifically it
allows you to mock responses to ChatGPT. The project is based upon the quickstart project at: https://github.com/openai/plugins-quickstart

Your project file will look like 

```yaml
---
projectName: plugin-quickstart
projectVersion: '1.0'
projectType: plugin
pluginServers:
  - serverId: todo-json
    # mocked requests
    requests:
      - path: "/todos/mike"
        method: get
        response: responses/todos-mike.json # returns the content of this file
      - path: "/todos/global"
        method: get
        response: responses/todos-global.json
      - path: "/todos/user"
        method: get
        response: responses/todos-global.json
    resources:
      logo: resources/logo.png
      api: resources/openapi.yaml
      manifest: resources/ai-plugin.json
    configuration:
      manifestPrompt: manifest.prompt # The prompt for plugin manifest
      apiDescription: description.txt # The openapi description

  # Changes content type to text, adds a different user for testing
  - serverId: todo-text
    requests:
      - path: "/todos/kaleb"
        method: get
        contentType: text/plain
        response: responses/todos-kaleb.text
      - path: "/todos/global"
        contentType: text/plain
        method: get
        response: responses/todos-global.text
      - path: "/todos/user"
        contentType: text/plain
        method: get
        response: responses/todos-global.text
    resources:
      logo: resources/logo.png
      api: resources/openapi.yaml
      manifest: resources/ai-plugin.json
    configuration:
      prompt: manifest.prompt
      apiDescription: description.txt
      showHttpHeaders: true # Show http headers in logs

```
The contents of the _manifest.prompt_ file will be substituted into the 
_description_for_model_ field of the plugin manifest.
```
A plugin that allows the user to create and manage a TODO list using ChatGPT.
If you do not know the user's username, ask them first before making queries to the plugin.
Otherwise, use the username global.
```
The _description.txt_ file will be substituted into the _info.description_ field of _resources/openapi.yaml_ file

```
A plugin that allows the user to create and manage a TODO list using ChatGPT.
```
A sample mocked response (_responses/todos-mike.json_) is given below. This will be returned on a call to **/todos/mike**

```json
{
  "todos": [
    "Clean out a septic tank",
    "Repair a broken sewer pipe",
    "Collect roadkill for disposal",
    "Assist in bee hive relocation",
    "Service a grease trap at a restaurant"
  ]
}
```
To start a mocked instance of the plugin server
```
air plugin
```
or to start a specific server add the _serverId_ option

```
air plugin --serverId todo-text
```
For more information about creating and using a 
[ChatGPT-Plugin](https://github.com/sisbell/stackwire-gpt/wiki/ChatGPT-Plugin)

### Generate Image Project
If you chose to create an image project, you will be asked for a description.
Don't worry you can change it later after generating the project.
```
? Image Description:  › A goldfish with big eyes
```
Your project file will look like
```yaml
projectName: image-2
projectVersion: 2.0
apiKeyFile: api_key
blocks:
  - blockId: image-block-1
    pluginName: ImageGptPlugin
    executions:
      #First Image
      - id: img-1
        sizes:
          - 256
          - 256
          - 1024
        prompt: image.prompt
        properties:
          imageDescription: A goldfish with big eyes
```
You prompt file will be
```
Generate a picture of a ${imageDescription}
```

For more information about [images](https://github.com/sisbell/stackwire-gpt/wiki/Images)

![image](https://user-images.githubusercontent.com/64116/235335782-ce438b16-45eb-4413-a12f-ca33136a63b2.png)

### Generate Batch Project
The following asks how many times to execute the batch data. If you choose 5 times,
it will run all the batch data calls 5 times each.

```
? Number of Times to Run The Block:  › 5
```
You will see a project file like the following
```yaml
---
projectName: mybatch
projectVersion: 1.0
apiKeyFile: api_key
blocks:
  - blockId: batch-1
    pluginName: BatchGptPlugin
    blockRuns: 5
    configuration:
      requestParams:
        model: gpt-3.5-turbo
        temperature: 0.7
        top_p: 1
        max_tokens: 500
    executions:
      - id: batch-1
        dataFile: batch-data.json
        prompt: batch.prompt
```
The prompt is a simple Hello World prompt
```
Write me a paragraph about the world I live in

World: ```${my_world}```
```
The batch-data.json file contains the batch data.

```json
{
  "my_world" : [
    "Hello World, I live in a magical place with magical creatures",
    "Hello World, I live in a futuristic Utopia",
    "Hello World, I live in a futuristic Dystopia"
  ]
}
```
Modify these two files with your own data.
For more information about [batches](https://github.com/sisbell/stackwire-gpt/wiki/Batches)

## Generate Prompt Project
The following asks how many times to run the prompt request. If you choose 5 times,
it will run all the prompt request 5 times.

```
? Number of Times to Run The Block:  › 5
```
Next choose the output format. Do you just want a straight text response, or do you want it in JSON format.
```
? Response Format › 
  JSON 
❯ TEXT
```
If you choose JSON, you will be asked if you want to enable fixing the JSON response.
This will attempt to parse any extraneous text that the AI assistant may add.

```
? Attempt to FIX JSON Responses? (y/n) › no   
```

The project file will look like
```yaml
---
projectName: prompt-1
projectVersion: 1.0
apiKeyFile: api_key
blocks:
  - blockId: single-1
    pluginName: ExperimentGptPlugin
    blockRuns: 5
    configuration:
      requestParams:
        model: gpt-3.5-turbo
        temperature: 1.2
        top_p: 1
        max_tokens: 500
    executions:
      - id: exp-1
        responseFormat: json
        fixJson: false
        promptChain:
          - prompt-json.prompt
        properties:
          character: Commander in Starfleet
          mainCharacterName: ''
  - blockId: report-1
    pluginName: ReportingGptPlugin
    executions:
      - id: report-1
        blockIds:
          - single-1
```
The file includes some default values for the OpenAI requests. Change them to suit your needs.
By default, it also adds the reporting plugin which generated HTML output of the user/assistant response.

The _prompt-json.prompt_ looks like the following. Note how the output specifies
to use JSON. Modify the prompt and properties to your needs.

```
Write me a story about ${character}. The main character is ${mainCharacterName}.
If no main character is given, choose one. Write one sentence only.

The response should be in JSON using the following structure:
Only use these fields. {"mainCharacterName": "", "story": ""}
```
For more information about [prompts](https://github.com/sisbell/stackwire-gpt/wiki/Prompts)

## Generate Chain Project
Choose the _Chain_ project archetype. Then go through the options.

```
? Number of Times to Run The Block:  › 1
```
```
? Attempt to FIX JSON Responses? (y/n) › yes  
```

```
? Number of Times to Run The Prompt Chain:  › 2
```

The generated _project.yaml_ file. 

```yaml
---
projectName: "chain-project"
projectVersion: "1.0"
apiKeyFile: "api_key"
blocks:
  # Block demonstrates the use of importing properties
  - blockId: chain-1
    pluginName: ExperimentGptPlugin
    blockRuns: 1 # Number of Stories
    configuration:
      requestParams:
        model: gpt-3.5-turbo
        temperature: 1.2
        top_p: 1
        max_tokens: 500
    executions:
      - id: exp-1-import
        chainRuns: 2 # Number of times to run the promptChain
        promptChain:
          - story.prompt
          - user-action.prompt # Simulates user input
        excludesMessageHistory:
          - user-action.prompt
        fixJson: true
        responseFormat: json
        # Import properties from a properties file
        import:
          propertiesFile: properties.json # predefined values
          properties:
            planet: 1 # Earth
            action: 3 # Lands on the planet

  - blockId: report-1
    pluginName: ReportingGptPlugin
    executions:
      - id: report-1
        blockIds:
          - chain-1
```

The property fields in the above _project.yaml_ file point to
the index within the _properties.json_ file is below. This file
allows you to easily change test input.

```json
{
  "planet": [
    "Earth",
    "Venus",
    "Jupiter"
  ],
  "action": [
    "Blows up the planet",
    "Observes the planet From Orbit",
    "Lands on the planet",
    "Zips around the planet and hopes no one notices"
  ]
}
```
The tool will substitute the planet "Earth" and the action "Lands on the planet" into
the story prompt below. Notice that the AI will generate the character's name and 
the first paragraph of the story.

```
The response will be in JSON Format.

Captain ${captainsName} is near ${planet}. .
The last part of the story is: ${story}
Then the captain ${action}

Tell me a story about what happens next.
Be very descriptive. Write two sentences only.
Give me the captains name, if I haven't given it.

RESPONSE
The response must only be in JSON using the following structure.
Only use these fields. {"captainsName": "${captainsName}", "story": ""}
```
The tool will now pass the returned captain's name and the story from the first
prompt into the _user-action.prompt_. We will get back an action that the
character takes.

```
Give me an action for ${captainsName} for the following story:
${story}

The response must be in JSON using the following structure.
Only use these fields. {"action": ""}
```
Now we will run the _story.prompt_ again but this time we will have both
the captain's name and the next action he takes.

The follow is sample output from an actual run
```
As Captain John lands on the planet, he feels the trembling beneath his feet and sees the vibrant green flora around him. 
He plants the Earth's flag to claim its new discovery and soon finds a thriving alien civilization welcoming him with open arms.

[user action "plants the flag to claim the new discovery"]

As Captain John plants the Earth's flag on the newfound planet, he is approached by the leaders of the alien civilization 
who speak his language and reveal that they have known about Earth for centuries. They invite him to partake in a feast in
his honor, where he learns about their advanced technology and way of life.
```
Notice that chain run is the same as the number of paragraphs we have in the
output. If we wanted another paragraph, we would set _chainRuns_ to 3. If
we had set blockRuns to 5, we would have generated 5 different stories.

For more information about [chains](https://github.com/sisbell/stackwire-gpt/wiki/Chains)

## Add Report Plugin
To generate an HTML report, add the _ReportingGptPlugin_ as the last block. Under the blockIds
add any previous block id that you want to add to the generated report.

```yaml
---
projectName: experiment-reporting
projectVersion: '1.7'
apiKeyFile: "../../api_key"
blocks:
  - blockId: chain-1
    pluginName: ExperimentGptPlugin
    blockRuns: 1
    ...
    # Generate HTML Report
  - blockId: report-1
    pluginName: ReportingGptPlugin
    executions:
      - id: report-execution
        blockIds:
          - chain-1
```
#### Sample Report
The report will display the entire chat for the configured block executions.

<img width="1527" alt="report" src="https://user-images.githubusercontent.com/64116/236595603-aa37df83-0bd5-4997-b67a-e4357b912b6e.png">

For more information about [reporting](https://github.com/sisbell/stackwire-gpt/wiki/Reporting)

## Command Help
> air --help

```
A command line tool for running GPT commands

Usage: air <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  clean    Cleans project's output directory
  count    Returns the number of OpenApiCalls that would be made
  genp     Generates a new project
  plugin   Runs local version of ChatGPT Plugin
  run      Runs a project's blocks

Run "air help <command>" for more information about a command.

```
## Additional Commands
### Clean Project
To clean a project, run the following

> air clean

This deletes the _output_ directory for the project.

### Count of OpenAI Calls for a Project
Running OpenAI calls with a tool can be costly if you mis-configure it. 
To determine how many OpenAI calls a project will create, run the following command

> air count

or for the count of a specific block

> air count -b myblockId

It will output 

```
Project: product-summary-2.8
Total OpenAPI Calls would be 12
```

### DryRun
If you want to know that your project is doing before incurring costs to OpenAI, use the dryRun flag.

>  air run --dryRun

```
Executing Block
Running Project: image-generation-2.3
BlockId: image-1, PluginName: ImageGptPlugin
----------
Starting Block Run: 1
Starting execution: 1 - Requires 1 calls to OpenAI
	POST to https://api.openai.com/v1/images/generations
		{"prompt":"Generate a picture of a Unicorn with a gold horn and wings","n":1,"size":"256x256","response_format":"url"}
Finished execution: 1

Starting execution: 2 - Requires 2 calls to OpenAI
	POST to https://api.openai.com/v1/images/generations
		{"prompt":"Generate a picture of a fish with giant eyes","n":1,"size":"256x256","response_format":"b64_json"}
	POST to https://api.openai.com/v1/images/generations
		{"prompt":"Generate a picture of a fish with giant eyes","n":1,"size":"512x512","response_format":"b64_json"}
Finished execution: 2


--------
Finished running project: 0 seconds
```
