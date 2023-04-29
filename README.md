A command line tool for running GPT commands. 

> Currently only chat completion API is supported.

This is the tool I use for refining the StanTrek and StanQuest games. It demonstrates some of the techniques I use for the game.

## Features
Use this tool to
* Create **batch** processing of GPT requests. Run a set of data against a prompt and record the responses.
* Create **experiments** to see how different config parameters and prompts affect performance and output.

## Getting Started
You will need to create an OpenAI API Key. If you have an account, you can create a key here

https://platform.openai.com/account/api-keys

> Do not share your API key with others, or expose it in the browser or other client-side code.
> You will incur any charges if someone uses your key. Don't check your key into any public repository.

Create a file that contains your API Key (the one below is not real). In our example. we name the file **api_key** and add the key.
```
sk-gKtTxOumv4orO6cfWlh0ZK
```

## Usage
The following are the use cases supported
* [Batch Command](#batch-command)
* [Simple Experiment](#simple-experiment)
* [Chain Experiment with Single Prompt](#chain-experiment-with-single-prompt)
* [Chain Experiment with Multiple Prompts](#chain-experiment-with-multiple-prompts)

### Batch Command
First create a prompt file. Borrowing an example prompt from DeepLearning.AI, create a prompt file. 
Name the file whatever you like. In our case, it's **product.prompt**.

```
Your task is to generate a short summary of a product
review from an ecommerce site to give feedback to the
pricing department, responsible for determining the
price of the product.

Summarize the review below, delimited by triple
backticks, in at most 30 words, and focusing on any aspects
that are relevant to the price and perceived value.

Review: ```${prod_review}```
```
Next create a data file called **data.json**. Note how ${prod_review} in the prompt file matches
the name of prod_review in the data file. This is how the tool does the substitution for creating 
the calculated prompt. You can configure multiple variables in the prompt and data file. 

```json
{
  "prod_review" : [
    "Got this panda plush toy for my daughter's birthday, who loves it and takes it everywhere. It's soft and  super cute, and its face has a friendly look...",
    "Needed a nice lamp for my bedroom, and this one had additional storage and not too high of a price point. Got it fast - arrived in 2 days. The string to..",
   ]
}
```

Lastly, create a project file called **product.eom**. Note that the prompt and data file point to the files we previously created. 
You may include more than one batch object in the array.
```json
{
  "project_name": "product-summary",
  "project_version": "2.0",
  "project_runs": 2,
  "output_dir": "output",
  "api_key_file": "../../api_key",
  "ai_config": {
    "model": "gpt-3.5-turbo",
    "temperature": 0.3,
    "top_p": 1,
    "max_tokens": 500
  },
  "batches": [
    {
      "id": "bid-1",
      "prompt": "product.prompt",
      "system_message_file": "../system-message.txt",
      "data_file": "data.json"
    }
  ]
}
```

| Field                | Description                                                                                                          |
|----------------------|----------------------------------------------------------------------------------------------------------------------|
| ai_config            | configuration parameters that are sent to OpenAI. You may add any legal parameters that OpenAI uses. Required field. |
| api_key_file         | path of your api key file. Default value is "api_key" but you must have this file.<br/>                              |
| output_dir           | directory where you want to put the output. Default value is "output".                                               |
| project_name         | name of your project. Don't use spaces or illegal characters. Required field.                                        |
| project_version      | version  of your project. Don't use spaces or illegal characters. Required field                                     |
| project_runs         | number of times to run your project. This will be the number of times you call OpenAI API. Default value is 1.       |
| batches[n].data_file | path of your data file. This is the input into the prompt. Required field.                                           |
| batches[n].id        | unique id of the batch job. Required field.                                                                          |
| batches[n].prompt    | path of your prompt template file. Required field.                                                                   |

To run the batch command with _id_ bid-1

> air batch -p product.eom --id bid-1

If you don't specify the id, it will default to the first batch in the array.

> air batch -p product.eom

Your calls to OpenAI will be project_runs * {number of array items in data file}. In the case above, its 2 * 2 = 4 

The output looks like:
```json
{
  "results": [
    {
      "input": {
        "prod_review": "Got this panda plush toy for my daughter's birthday,...with it myself before I gave it to her."
      },
      "output": "The panda plush toy is soft, cute, and has a friendly face, but the size may not be worth the price. Other options may offer better value for the same price."
    },
    {
      "input": {
        "prod_review": "Needed a nice lamp for my bedroom, and ... cares about their customers and products."
      },
      "output": "Affordable lamp with additional storage, fast shipping, and excellent customer service. Perceived value is high due to the company's care for customers and products."
    }
  ]
}
```

### Simple Experiment

Start by creating a **simple-story.prompt** file. 

```
Write me a story about ${character}. One Sentence Only.
```
Now create the project file called **project-simple.eom** with an eom extension (experiment object model).

```json
{
  "project_name": "experiment-simple",
  "project_version": "1.0",
  "project_runs": 5,
  "response_format": "text",
  "output_dir": "output",
  "api_key_file": "../../api_key",
  "ai_config": {
    "model": "gpt-3.5-turbo",
    "temperature": 1.2,
    "top_p": 1,
    "max_tokens": 500
  },
  "experiments": [
    {
      "id" : "exp-1",
      "prompts": {
        "system_message_file": "../system-message.txt",
        "chain_runs": 1,
        "chain": [
          "simple-story.prompt"
        ],
        "properties": {
          "character": "Commander in Starfleet"
        }
      }
    }
  ]
}
```

| Field                                     | Description                                                                                                                                                                                   |
|-------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ai_config                                 | the configuration parameters that are sent to OpenAI. You may add any legal parameters that OpenAI uses. Required field.                                                                      |
| api_key_file                              | the path of your api key file. Default value is "api_key.txt" but you must have this file.                                                                                                    |
| output_dir                                | directory where you want to put the output. Default value is "output".                                                                                                                        |
| project_name                              | The name of your project. Don't use spaces or illegal characters. Required field.                                                                                                             |
| project_version                           | version  of your project. Don't use spaces or illegal characters. Required field                                                                                                              |
| project_runs                              | the number of times to run your project. This will be the number of times you call OpenAI API. Default value is 1.                                                                            |
| response_format                           | either "json" or "text". The default value is "text" if not specified                                                                                                                         |
| experiments[n].id        | unique id of the experiment. Required field.                                                                                                                                                  |
| experiments[n].prompts.chain              | the path of your prompt template files. Required field.                                                                                                                                       |
| experiments[n].prompts.properties         | any properties you want to fill-in to the prompt template. This field is optional.                                                                                                            |
| experiments[n].prompts.chain_runs         | the number of times to run the chain of defaults. Default value is 1                                                                                                                          |
| experiments[n].prompts.system_message_file | file containing the system message to use. Optional field.                                                                                                                                    |
| experiments[n].prompts.fixJson            | if your response is in JSON format, this will flag the tool to try to extract a valid JSON that is surrounded by unwanted external text that the AI may generate. The default value is false. |

Give the the _${character}_ value in **prompts.properties.character** field.
By setting **experiment_runs** to say 10, you will generate 10 runs of this prompt so you can view the results, and determine average performances and token usage.
For a simple experiment, just leave **prompts.chain_runs** at 1.

To run the experiment command. 

> air experiment -p project-simple.eom --id exp-1

This runs with simple-story.prompt 5 times. The calculated prompt for the experiment will be
````
Write me a story about Commander in Starfleet. One Sentence Only.
````
### Chain Experiment with Single Prompt
Chained prompts are useful when you want to use the results from one prompt in the next prompt.
In the following case we will use a single prompt feeding back into itself.

Create the prompt file.
```
Write me a story about ${character}. The main character is ${mainCharacterName}. If no main character is given, choose one. Write one sentence only.
The response should be in JSON using the following structure. Only use these fields. {"mainCharacterName": "", "story": ""}
```

Now create the project file: **project-single.eom**. Note that we are defining the _character_ value as "Commander in Starfleet"
but are not defining any _mainCharacterName_. We will let the AI do this for us.

```json
{
  "project_name": "experiment-chain-single",
  "project_version": "1.0",
  "project_runs": 1,
  "response_format": "text",
  "output_dir": "output",
  "api_key_file": "../../api_key",
  "ai_config": {
    "model": "gpt-3.5-turbo",
    "temperature": 1.2,
    "top_p": 1,
    "max_tokens": 500
  },
  "experiments": [
    {
      "id" : "exp-1",
      "prompts": {
        "system_message_file": "../system-message.txt",
        "chain_runs": 2,
        "chain": [
          "simple-story.prompt"
        ],
        "properties": {
          "character": "Commander in Starfleet"
        }
      }
    }
  ]
}
```
Since we are chaining requests, it's important to set the _response_format_ field to "json".
This is how the response knows how to map itself to the properties in the next request.

You may also choose to set _fixJson_ to true. This will try to cleanup any extra text
the AI may add in addition to the JSON response.

To run the experiment command

> air experiment -p project-single.eom --id exp-1

On the first (chain) request, the prompt sent to OpenAI will be
```
Write me a story about Commander in Starfleet. The main character is . If no main character is given, choose one. Write one sentence only.
The response should be in JSON using the following structure. Only use these fields. {"mainCharacterName": "", "story": ""}
```
The content of the response looks like
```json
{
  "mainCharacterName": "Kiera", 
  "story": "Commander Kiera was a respected officer in Starfleet, known for her exceptional leadership skills and bravery in the face of danger."
}
```
On the second (chain) request, we use the _mainCharacterName_ from the above JSON and substitute it into the prompt.
```
Write me a story about Commander in Starfleet. The main character is Kiera. If no main character is given, choose one. Write one sentence only.
The response should be in JSON using the following structure. Only use these fields. {"mainCharacterName": "Kiera", "story" :""}
```
So you can see once the story starts with "Commander Kiera", it will now continue on with that same character.

If we set the _chain_run_ to 3, then there would be another call of the prompt above.

### Chain Experiment with Multiple Prompts
Take the following example as the first prompt in the chain. Call it **structured-story.prompt**. 
There are three possible values you can configure for substitution.
* story
* character
* characterAction

```
The response will be in JSON Format.

PREVIOUS SCENE
${story}

CHARACTER
Role: ${character}
Main Character Name: ${mainCharacterName}
If no main character name is given, choose one based on role

CHARACTER ACTION
${characterAction}

Write me a story based on the character role. If character name, action and the previous scene 
are given also use those. Write two sentences only.

RESPONSE
The response must only be in JSON using the following structure. 
Only use these fields. {"mainCharacterName": "", "story": ""}
```
We can see from the above prompt that the previous scene and _characterAction_ should
change every request, while the _mainCharacterName_ and _character_ should remain the same
through the prompt chain. It's clear that we can use the _story_ in the JSON response
in the next prompt request, but how do we get the _characterAction_?

In a real application the _characterAction_ would come from the user input. We can 
ask the AI to give us an action to simulate a user response.

So create a second prompt called **character-action.prompt**. 
```
Give me an action for ${mainCharacterName} for the following story:
${story}
The response must be in JSON using the following structure. Only use these fields. {"characterAction": ""}
```

Now create a eom project file called **project-chain.eom**

```json
{
  "project_name" : "experiment-chain-multiple",
  "project_version" : "1.0",
  "project_runs" : 1,
  "response_format" : "json",
  "output_dir" : "output",
  "api_key_file": "../../api_key",
  "ai_config" : {
    "model": "gpt-3.5-turbo",
    "temperature": 1.2,
    "top_p": 1,
    "max_tokens": 500
  },
  "experiments" : [
    {
      "id" : "exp-1",
      "prompts" : {
        "chain_runs" : 2,
        "chain": [
          "structured-story.prompt",
          "character-action.prompt"
        ],
        "excludesMessageHistory" : [
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
  ]
}
```
In the project file above, notice that we have added both prompts to the chain. Since
the chain runs 2 times, it will run the prompts in the following order
1. structured-story.prompt
2. character-action.prompt
3. structured-story.prompt
4. character-action.prompt

We also have the **character-action.prompt** excluded from the message history. What this
means is that this prompt and its result will not be part of the main chat context. It's a one-shot.
This will be clearer in the explanation below.

To run the experiment

> air experiment -p project-chain.eom --id exp-1

The **first** request will look like

```
The response will be in JSON Format.

PREVIOUS SCENE

CHARACTER
Role: Commander in Starfleet
Main Character Name:
If no main character name is given, choose one based on role

CHARACTER ACTION

Write me a story based on the character role. If character name, action and the previous scene 
are given also use those. Write two sentences only.

RESPONSE
The response must only be in JSON using the following structure. 
Only use these fields. {"mainCharacterName": "", "story": ""}
```
Since only the character property was given in the eom, it's the only one that is non-blank in the prompt.

The following is an example of a response. The Klingons are threatening the Federation.
```
{
    "mainCharacterName": "Captain Kirk",
    "story": "As soon as Captain Kirk received news of a possible threat to the Federation 
    from the Klingons, he swiftly ordered his crew to high alert, and set course towards the
     Neutral Zone to investigate."
}
````
For the **second** request, let's ask AI for the _characterAction_ using the **character-action.prompt**
```
Give me an action for Captain Kirk for the following story:
     As soon as Captain Kirk received news of a possible threat to the Federation 
     from the Klingons, he swiftly ordered his crew to high alert, and set course towards the
     Neutral Zone to investigate
The response must be in JSON using the following structure. Only use these fields. {"characterAction": ""}
```
The response is the following. AI has generated a plausible user response for testing.

```json
{
  "characterAction": "Captain Kirk ordered his crew to high alert and set course towards the Neutral Zone to investigate the threat from the Klingons."
}
```
Now we do the **third** request using the **structured-story.prompt**. Notice how we substitute in the _characterAction_ generated from the previous prompt.

```
The response will be in JSON Format.

PREVIOUS SCENE
As soon as Captain Kirk received news of a possible threat to the Federation 
from the Klingons, he swiftly ordered his crew to high alert, and set course towards the
Neutral Zone to investigate
     
CHARACTER
Role: Commander in Starfleet
Main Character Name: Captain Kirk
If no main character name is given, choose one based on role

CHARACTER ACTION
Captain Kirk ordered his crew to high alert and set course towards the Neutral Zone to investigate the threat from the Klingons.

Write me a story based on the character role. If character name, action and the previous scene 
are given also use those. Write two sentences only.

RESPONSE
The response must only be in JSON using the following structure. 
Only use these fields. {"mainCharacterName": "", "story": ""}
```
Based on the character action of "entering the Neutral Zone", we get the next scene.
```
{
    "mainCharacterName": "Captain Kirk", 
    "story": "As news of a possible threat from the Klingons reached him, Captain Kirk swiftly 
    ordered his crew to high alert and set course towards the Neutral Zone to investigate. Determined 
    to protect the Federation from any harm, the brave commander led his crew forward, ready to face 
    whatever danger lay ahead."
}
```
This example shows how we can use chaining to simulate user input in a chain. 

### Experiment Output Files

For each run you will get a record of the request sent:

```json
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
```json
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

The metrics.csv file will give you the performance times and token usage for each experiment. In this case, there was an alternating run of two prompts. The story prompt takes 3.9 and 5.7 seconds to run.
```
request_id, prompt_name, request_time, prompt_tokens, completion_tokens, total_tokens
chatcmpl-774QSUZEM0qGzIHSkjdc1YB6SnqqU, structured-story.prompt, 3872, 126, 55, 181
chatcmpl-774QWC735h8zqC48NdDvQBbAK4wtI, character-action.prompt, 2361, 91, 30, 121
chatcmpl-774QYzgnx9x3UjxPjd4ef4lotUPI1, structured-story.prompt, 5668, 190, 72, 262
chatcmpl-774QelDpcSp02xIJSH2kpdj1WyNsJ, character-action.prompt, 2057, 111, 23, 134
```

## Install Program
If you have dart installed, you can use this program with the following command

> dart pub global activate air
> 
## Download Program
Download the air executable for your platform from Artifacts. They are under the Actions tab. Unzip after downloading.

https://docs.github.com/en/actions/managing-workflow-runs/downloading-workflow-artifacts

For macos and linux you will need to make the file executable
```
chmod a+x air
```

## Building this project
Make sure that you have dart installed. And then from the directory root
> dart pub get
> 
> dart compile exe bin/gpt.dart -o air

