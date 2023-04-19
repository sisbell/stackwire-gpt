# Stackwire Runner for OpenAI
A command line app for experimenting with OpenAI API prompts. This is the tool I use for refining the StanTrek and StanQuest games. It demonstrates some of the techniques I use for the game.
> Currently only chat completion API is supported.

## Setup Experiment
An experiment will require three files
* experiment file - this contains all the configuration info needed to make the call to OpenAI
* prompt file - this is the file that you want to include as the prompt to OpenAI. You may have one or more of these files.
* API key file - contains your OpenAI API Key

You experiment may optionally use:
* system message file - this contains the system message you would like to use

First create your experiment file. You can name it anything, by default the program will look for 'experiment.eom'. EOM is the file extension for the **experiment object model**. 

The following eom is for running a prompt multiple times. 
 ```
{
  "experiment_name": "singlerun-experiment",
  "number_of_runs": 1,
  "response_format": "text",
  "output_dir": "output",
  "api_key_file": "../../api_key",
  "ai_config": {
    "model": "gpt-3.5-turbo",
    "temperature": 1.2,
    "top_p": 1,
    "max_tokens": 500
  },
  "prompts": {
    "system_message_file": "../system-message.txt",
    "chain": [
      "simple-story.prompt"
    ],
    "properties": {
      "rank": "Commander in Starfleet",
      "show": "The Original Star Trek"
    }
  }
}
 ```
You can also chain prompts by setting the response_format to "json". The prompt will need to return in JSON and the json fields will be used to fill-in the values for the next prompt sent to OpenAI. You can look in the "example/chain-experiment" directory to see how this is done.
```
{
  "experiment_name" : "chain-experiment",
  "experiment_runs" : 1,
  "response_format" : "json",
  "output_dir" : "output",
  "api_key_file": "../../api_key",
  "ai_config" : {
    "model": "gpt-3.5-turbo",
    "temperature": 1.2,
    "top_p": 1,
    "max_tokens": 500
  },
  "prompts" : {
    "system_message_file" : "../system-message.txt",
    "chain_runs" : 2,
    "chain": [
      "structured-story.prompt",
      "character-action.prompt"
    ],
    "fixJson" : true,
    "properties" : {
      "rank" : "Commander in Starfleet",
      "show" : "The Original Star Trek",
      "mainCharacterName": "",
      "story": "",
      "characterAction" : ""
    }
  }
}
```
| Field                       | Description                                                                                                                                                                                   |
|-----------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| experiment_name             | The name of your experiment. Don't use spaces or illegal characters. Required field.                                                                                                          |
| experiment_runs             | The number of times to run your experiment. This will be the number of times you call OpenAI API. Default value is 1.                                                                         |
| output_dir                  | directory where you want to put the output. Default value is "output".                                                                                                                        |
| api_key_file                | the path of your api key file. Default value is "api_key.txt" but you must have this file.                                                                                                    |
| prompts.chain               | the path of your prompt template files. Required field.                                                                                                                                       |
| prompts.properties          | any properties you want to fill-in to the prompt template. This field is optional.                                                                                                            |
| response_format             | either "json" or "text". The default value is "text" if not specified                                                                                                                         |
| prompts.chain_runs          | the number of times to run the chain of defaults. Default value is 1                                                                                                                          |
| prompts.system_message_file | file containing the system message to use. Optional field.                                                                                                                                    |
| prompts.fixJson             | If your response is in JSON format, this will flag the tool to try to extract a valid JSON that is surrounded by unwanted external text that the AI may generate. The default value is false. |
| ai_config                   | the configuration parameters that are sent to OpenAI. You may add any legal parameters that OpenAI uses. Required field.                                                                      |

### Single Prompt Requests
Next create your prompt file(s): You can name it anything, in our case it is **example/experiment-single-run/simple-story.prompt**. An example is given below. The template value from the experiment file will replace the special syntax ${rank}
```
Write me a story about ${rank}. One Sentence Only.
```
The prompt sent to OpenAI will be

````
Write me a story about Commander in Starfleet. One Sentence Only.
````
While this is a single prompt requests, by setting **experiment_runs** to say 20, you will generate 20 runs of this prompt so you can view the results, and determine average performances and token usage.

### Chain Requests with Single Prompt
If you are doing prompt chaining, consider the following example. It contains just single prompt. By setting **chain_runs** to say 10, it runs the single prompt 10 times per experiment. Properly structured, these allow the json values from one response to become input into the next response.
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


### Chain Requests with Multiple Prompts
This approach is more powerful than the Single Prompt approach because it allows you to create a series of different prompts that feed into each other.

Take the following example as the first prompt in the chain. I may choose to specify the initial story scene and character name or I may let those be empty and let the AI choose them. I then instruct the AI to return me the story it generated with the main character's name.

```
The response will be in JSON Format.

PREVIOUS SCENE
${story}

CHARACTER
Role: ${rank}
Main Character Name: ${mainCharacterName}
If no main character name is given, choose one based on role

CHARACTER ACTION
${characterAction}


Write me a story based on the character role. If character name, action and the previous scene are given also use those. Write two sentences only.

RESPONSE
The response must only be in JSON using the following structure. Only use these fields. {"mainCharacterName": "", "story": ""}
```
In the StanTrek and StanQuest games, I have the user input Stanley's actions. But here, I want to have the AI generate for me. The **mainCharacterName** and **story** are coming from the previous response.

````
Give me an action for ${mainCharacterName} for the following story:
${story}
The response must be in JSON using the following structure. Only use these fields. {"characterAction": ""}
````
The following is an actual example of a response. The Klingons are threatening the Federation.
```
{
    "mainCharacterName": "Captain Kirk",
    "story": "As soon as Captain Kirk received news of a possible threat to the Federation 
    from the Klingons, he swiftly ordered his crew to high alert, and set course towards the
     Neutral Zone to investigate."
}
````

The response was the following. It has AI generate a plausible user response for testing.

```
{"characterAction": "Captain Kirk ordered his crew to high alert and set course towards 
the Neutral Zone to investigate the threat from the Klingons."}
```

Based on the character action of "entering the Neutral Zone", we get the next scene.
```
{"mainCharacterName": "Captain Kirk", 
"story": "As news of a possible threat from the Klingons reached him, Captain Kirk swiftly 
ordered his crew to high alert and set course towards the Neutral Zone to investigate. Determined 
to protect the Federation from any harm, the brave commander led his crew forward, ready to face 
whatever danger lay ahead."}
```
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
stackwire experiments.eom
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
The metrics.csv file will give you the performance times and token usage for each experiment. In this case, there was an alternating run of two prompts. The story prompt takes 3.9 and 5.7 seconds to run.
```
request_id, prompt_name, request_time, prompt_tokens, completion_tokens, total_tokens
chatcmpl-774QSUZEM0qGzIHSkjdc1YB6SnqqU, structured-story.prompt, 3872, 126, 55, 181
chatcmpl-774QWC735h8zqC48NdDvQBbAK4wtI, character-action.prompt, 2361, 91, 30, 121
chatcmpl-774QYzgnx9x3UjxPjd4ef4lotUPI1, structured-story.prompt, 5668, 190, 72, 262
chatcmpl-774QelDpcSp02xIJSH2kpdj1WyNsJ, character-action.prompt, 2057, 111, 23, 134
```
## Building this project
Make sure that you have dart installed. And then from the project root
> dart pub get
> 
> dart compile exe bin/stackwire.dart -o stackwire

