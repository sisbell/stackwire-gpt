# Stackwire Runner for OpenAI
A command line app for experimenting with OpenAI API prompts
> Currently only chat completion API is supported.

## Setup Experiment
An experiment will require three files
* experiment file - this contains all the configuration info needed to make the call to OpenAI
* prompt file - this is the file that you want to include as the prompt to OpenAI
* API key file - contains your OpenAI API Key

First create your experiment file. You can name it anything, by default the program will look for 'experiment.json'. The following is for running a prompt multiple times.
 ```
{
  "experiment_name" : "multirun-exp",
  "number_of_runs" : 1,
  "response_format" : "text",
  "output_dir" : "output",
  "api_key_file": "api_key.txt",
  "ai_config" : {
    "model": "gpt-3.5-turbo",
    "temperature": 1.2,
    "top_p": 1,
    "max_tokens": 500
  },
  "chat" : {
    "run_depth" : 0,
    "system_message_file" : "system-message.txt",
  },
  "prompts" : {
    "template_file" : "prompt.txt",
    "properties" : {
      "rank" : "Commander in Starfleet",
      "show" : "The Original Star Trek"
    }
  }
}
 ```
You can also chain prompts by setting the response_format to "json" and setting a run_depth > 0. The prompt will need to return in JSON and the json fields will be used to fill-in the values for the next prompt sent to OpenAI. You can look in the "example" directory to see how this is done.
```
{
  "experiment_name" : "chain-exp",
  "number_of_runs" : 1,
  "response_format" : "json",
  "output_dir" : "output",
  "api_key_file": "api_key.txt",
  "ai_config" : {
    "model": "gpt-3.5-turbo",
    "temperature": 1.2,
    "top_p": 1,
    "max_tokens": 500
  },
  "chat" : {
    "system_message_file" : "example/system-message.txt",
    "run_depth" : 1
  },
  "prompts" : {
    "template_file" : "example/prompt-json.txt",
    "properties" : {
      "rank" : "Commander in Starfleet",
      "show" : "The Original Star Trek"
    }
  }
}
```
| Field                    | Description                                                                                                              |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------|
| experiment_name          | The name of your experiment. Don't use spaces or illegal characters. Required field.                                     |
| number_of_runs           | The number of times to run your experiment. This will be the number of times you call OpenAI API. Default value is 1.    |
| output_dir               | directory where you want to put the output. Default value is "output".                                                   |
| api_key_file             | the path of your api key file. Default value is "api_key.txt" but you must have this file.                               |
| prompts.template_file    | the path of your prompt template file. Required field.                                                                   |
| prompts.properties       | any properties you want to fill-in to the prompt template. This field is optional.                                       |
| response_format          | either "json" or "text". The default value is "text" if not specified                                                    |
| chat.run_depth           | the depth of a prompt chain. Default value is 0                                                                          |
| chat.system_message_file | file containing the system message to use. Optional field.                                                               |
| ai_config                | the configuration parameters that are sent to OpenAI. You may add any legal parameters that OpenAI uses. Required field. |

Next create your prompt file: You can name it anything, in our case it is **data/prompt.txt**. An example is given below. The template value from the experiment file will replace the special syntax ${rank}
```
Write me a story about ${rank}. One Sentence Only.
```
The prompt sent to OpenAI will be

````
Write me a story about Commander in Starfleet. One Sentence Only.
````
If you are doing prompt chaining, consider the following example
```
Write me a story about ${rank}. The main character is ${mainCharacterName}. If no main character is given, choose one. Write one sentence only.
The response should be in JSON using the following structure. Only use these fields. {"mainCharacterName": "", "story": ""}
```
On the first request, the prompt sent to OpenAI will be
```
Write me a story about Commander in Starfleet. The main character is . If no main character is given, choose one. Write one sentence only.
The response should be in JSON using the following structure. Only use these fields. {"mainCharacterName": "", "story": ""}
```
The content of the response:
```
{"mainCharacterName": "Kiera", "story": "Commander Kiera was a respected officer in Starfleet, known for her exceptional leadership skills and bravery in the face of danger."}
```
The second request:
```
Write me a story about Commander in Starfleet. The main character is Kiera. If no main character is given, choose one. Write one sentence only.
The response should be in JSON using the following structure. Only use these fields. {"mainCharacterName": "Kiera", "story" :""}
```
So you can see once the story start with "Commander Kiera", it will now continue on that same character.

## Adding API Key
Add a file that contains your API Key (the one below is not real). In our example. we call it **api_key.txt**
```
sk-gKtTxOumv4orO6cfWlh0ZK
```

## Download Program
You can build this project yourself. Or download the stackwire executable for your platform from
Artifacts. They are under the Actions tab. Unzip after downloading.

https://docs.github.com/en/actions/managing-workflow-runs/downloading-workflow-artifacts

For macos and linux you will need to make the file executable
```agsl
chmod a+x stackwire
```
For mac, you will need to do something like the following before running from command-line.
https://thewiredshopper.com/apple-cannot-check-for-malicious-software-error/

## Run Experiment

Run the following command.
```
stackwire experiments.json
```
The above command will generate the output directory with a record of all of the requests and responses from OpenAI.

## Output
For each run you will get a record of the request sent:

```
{
  "model": "gpt-3.5-turbo",
  "temperature": 1.2,
  "top_p": 1,
  "max_tokens": 500,
  "messages": [
    {
      "role": "user",
      "content": "Write me a story about Commander in Starfleet. One Sentence Only."
    }
  ]
}
```

And the response from OpenAI. This will allow you to also determine tokens used.
```
{
  "id": "chatcmpl-74WgfENKxOmQwRwtpoJ6IFELyzNTL",
  "object": "chat.completion",
  "created": 1681313317,
  "model": "gpt-3.5-turbo-0301",
  "usage": {
    "prompt_tokens": 22,
    "completion_tokens": 27,
    "total_tokens": 49
  },
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "As Commander of the USS Enterprise, Jean-Luc Picard boldly leads his crew through perilous missions and treks through the galaxy."
      },
      "finish_reason": "stop",
      "index": 0
    }
  ]
}
```
You will also get a text-only output of the run

```
exp-multirun
Write me a story about Commander in Starfleet. One Sentence Only.
As Commander of the USS Enterprise, Jean-Luc Picard boldly leads his crew through perilous missions and treks through the galaxy.

```

## Building this project
Make sure that you have dart installed. And then from the project root
> dart pub get
> 
> dart compile exe bin/stackwire.dart -o stackwire

