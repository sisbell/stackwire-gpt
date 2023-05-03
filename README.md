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

## Usage
The following are the use cases supported
* [Generate Images](#generate-images)
* [Batch Command](#batch-command)
* [Simple Experiment](#simple-experiment)
* [Chain Experiment with Single Prompt](#chain-experiment-with-single-prompt)
* [Chain Experiment with Multiple Prompts](#chain-experiment-with-multiple-prompts)

### General Information
#### Experiment Object Model
The experiment object model (or eom) is the project file for running commands. The skeleton structure is given below.

```json
{
  "projectName": "your-project-name",
  "projectVersion": "1.0",
  "apiKeyFile": "../../api_key",
  "blocks": [
    {
      "blockId": "blockId-A",
      "pluginName": "MyGptPlugin",
      "configuration": {
        
      },
      "executions": [
      
      ]
    }
  ]
}
```

| Field                    | Description                                                                                                                         |
|--------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| apiKeyFile               | path of your api key file. Default value is "api_key" but you must have this file.                                                  |
| outputDir                | directory where you want to put the output. Default value is "output".                                                              |
| projectName              | name of your project. Don't use spaces or illegal characters. Required field.                                                       |
| projectVersion           | version  of your project. Don't use spaces or illegal characters. Required field                                                    |
| blocks                   | an array of executable blocks. A block is equivalent to a plugin with execution actions.                                            | 
| blocks.[n].blockId       | unique id of a block.                                                                                                               | 
| blocks.[n].pluginName    | name of the plugin. This will match to a dart class that implements the block.                                                      | 
| blocks.[n].configuration | configuration for the block. This is a common configuration for all executions of the plugin. This will change based on the plugin. |   
| blocks.[n].executions    | an array of execution details. This is used to provide command parameters to the plugin.                                            | 

#### Skeleton Output

```json
{
  "projectName": "your-project-name",
  "projectVersion": "1.0",
  "blockId": "blockId-A",
  "blockRuns": [
    {
      "blockRun": 1,
      "blockResults": [
      
      ]
    },
    {
      "blockRun": 2,
      "blockResults": [
      
      ]
    }
  ]
}
```

| Field                      | Description                                                                        |
|----------------------------|------------------------------------------------------------------------------------|
| projectName                | name of your project.                                                              |
| projectVersion             | version  of your project.                                                          |
| blockId                    | version  of your project.                                                          |
| blockRuns                  | array of block output                                                              |
| blockRuns.[n].blockRun     | order the blocks were run. Starts at 1.                                            |
| blockRuns.[n].blockResults | results of the block run. The content of this node is dependent on the plugin type |

#### CLI
To run a specific block, use the _blockId_ arg.

> air run -p project.eom -b blockId-A

If you want to run all blocks, don't specify a blockId. This also works if there is only one block.

> air run -p project.eom

If your eom file name is _project.eom_, then simply type then following to run all blocks.

> air run

The commands for run are given below
```
Runs a plugin

Usage: air run [arguments]
-h, --help           Print this usage information.
-p, --projectFile    
-b, --blockId        
    --[no-]dryRun    

Run "air help" to see global options.
```
### Generate Images
First, create a prompt file for images. Call it **image.prompt**.
```
Generate a picture of a ${creature} with ${feature}
```
The _${}_ is a value that can be substituted with a property. You don't have to use these
in the prompt but they can be convenient if you want to vary the prompt without needing
to create a separate file each time.

Now create an eom file **project-image.eom**. 

```json
{
  "projectName": "image-generation",
  "projectVersion": "2.3",
  "apiKeyFile": "../../api_key",
  "blocks": [
    {
      "blockId": "image-1",
      "pluginName": "ImageGptPlugin",
      "configuration": {
        "blockRuns": 2
      },
      "executions": [
        {
          "id": "img-unicorn",
          "sizes": [
            256
          ],
          "imageCount": 1,
          "responseFormat": "url",
          "prompt": "image.prompt",
          "properties": {
            "creature": "Unicorn",
            "feature": "a gold horn and wings"
          }
        },
        {
          "id": "img-fish",
          "sizes": [
            256,
            512
          ],
          "imageCount": 2,
          "responseFormat": "b64_json",
          "prompt": "image.prompt",
          "properties": {
            "creature": "fish",
            "feature": "giant eyes"
          }
        }
      ]
    }
  ]
}
```

The eom above uses the **ImageGptPlugin**. The configuration is:

| Field          | Description                                                                                             |
|----------------|---------------------------------------------------------------------------------------------------------|
| sizes          | sizes of images to create: 256, 512, and 1024                                                           |
| imageCount     | number of images to generate.                                                                           |  
| responseFormat | url or b64_json. Url points to a remote location for the images, while b64_json is embedded in the output field |  
| prompt         | prompt file to use for generating the image                                                             |  
| properties     | properties to substitute into the prompt                                                                |  

Note: the total images generated is:
> sizes.length * imageCount

For instance, for img-fish we have a _sizes_ array of 2 items and an _imageCount_ of 2.

> 2 * 2 = 4

The would produce 2 images of size 256 and two images of size 512.

The calculated prompts in the above example are:
```
Generate a picture of a Unicorn with a gold horn and wings
```
and

```
Generate a picture of a fish with giant eyes
```

#### Output
 If b64_json is specified as the responseFormat, the b64 blob will be included in the response,
otherwise it includes a URL to the generated image.

Since img-fish has two sizes specified, two images for it are included in the output file.
The output will be giving in the following format.
```json
{
  "projectName": "image-generation",
  "projectVersion": "2,3",
  "blockId": "image-1",
  "blockRuns": [
    {
      "blockRun": 1,
      "blockResults": [
        {
          "prompt": "Generate a picture of a Unicorn with a gold horn and wings",
          "size": "256x256",
          "images": [
            {
              "url": "https://oaidalleapiprodscus.blob.core.windows.net/private/..."
            }
          ]
        },
        {
          "prompt": "Generate a picture of a fish with giant eyes",
          "size": "256x256",
          "images": [
            {
              "url": "https://oaidalleapiprodscus.blob.core.windows.net/private/..."
            }
          ]
        },
        {
          "prompt": "Generate a picture of a fish with giant eyes",
          "size": "512x512",
          "images": [
            {
              "url": "https://oaidalleapiprodscus.blob.core.windows.net/private/..."
            }
          ]
        }
      ]
    }
  ]
}
```
The URL formate images will be downloaded. For b64, the file will be converted to png format.
All images are saved in the following directory.
```
${output}/${projectName}/${projectVersion}/${blockId}/images
```

![image](https://user-images.githubusercontent.com/64116/235335686-ebd7245e-5401-4275-b3a6-73e0c55635ae.png)
![image](https://user-images.githubusercontent.com/64116/235335738-70e0c076-f845-4341-9895-bbf10bcede0a.png)
![image](https://user-images.githubusercontent.com/64116/235335782-ce438b16-45eb-4413-a12f-ca33136a63b2.png)

#### CLI
To generate the unicorn image, use the following command

> air run -p project-image.eom -b img-unicorn

Or generate all images with

> air run -p project-image.eom
> 
### Batch Command
Batches are useful when you have a number prompts that you want to generate output for.

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
Next create a data file called **data.json**. This file contains your batch inputs.

Note how ${prod_review} in the prompt file matches the name of _prod_review_ key in the data file. This is how the tool does the substitution for creating 
the calculated prompt. You can configure multiple variables in the prompt and data file. 

```json
{
  "prod_review" : [
    "Got this panda plush toy for my daughter's birthday, who loves it and takes it everywhere. It's soft and  super cute, and its face has a friendly look...",
    "Needed a nice lamp for my bedroom, and this one had additional storage and not too high of a price point. Got it fast - arrived in 2 days. The string to..",
   ]
}
```

You could also include another set of inputs to your prompt. Note that the size of the arrays must be the same.
```json
{
  "prod_review" : [
    "Got this panda plush toy for my daughter's birthday, who loves it and takes it everywhere. It's soft and  super cute, and its face has a friendly look...",
    "Needed a nice lamp for my bedroom, and this one had additional storage and not too high of a price point. Got it fast - arrived in 2 days. The string to..",
   ],
  "some_action" : [
    "Expand this statement",
    "Reduce this statement"
  ]
}
```
The first prompt for
```
${some_action}: ${prod_review}`
```
would calculate to
```
Expand this statement: Got this panda plush toy for my daughter's birthday, who loves it and takes it everywhere. It's soft and  super cute, and its face has a friendly look...
```
The second prompt would be
```
Reduce this statement: Needed a nice lamp for my bedroom, and this one had additional storage and not too high of a price point. Got it fast - arrived in 2 days. The string to..
```
To continue the example, create a project file called **product.eom**. Note that the prompt and data file point to the files we previously created. 
You may include more than one batch object in the array.
```json
{
  "projectName": "product-summary",
  "projectVersion": "2.8",
  "apiKeyFile": "../../api_key",
  "blocks": [
    {
      "blockId": "product-1",
      "pluginName": "BatchGptPlugin",
      "configuration": {
        "blockRuns": 2,
        "requestParams": {
          "model": "gpt-3.5-turbo",
          "temperature": 0.3,
          "top_p": 1,
          "max_tokens": 500
        }
      },
      "executions": [
        {
          "dataFile": "data.json",
          "prompt": "product.prompt",
          "systemMessageFile": "../system-message.txt"
        },
        {
          "dataFile": "data.json",
          "prompt": "product.prompt",
          "systemMessageFile": "../system-message.txt"
        }
      ]
    },
    {
      "blockId": "product-2",
      "pluginName": "BatchGptPlugin",
      "configuration": {
        "blockRuns": 1,
        "requestParams": {
          "model": "gpt-3.5-turbo",
          "temperature": 1,
          "top_p": 1,
          "max_tokens": 500
        }
      },
      "executions": [
        {
          "dataFile": "data.json",
          "prompt": "product.prompt"
        },
        {
          "dataFile": "data.json",
          "prompt": "product.prompt"
        }
      ]
    }
  ]
}
```

| Field                       | Description                                                                                                          |
|-----------------------------|----------------------------------------------------------------------------------------------------------------------|
| configuration.requestParams | configuration parameters that are sent to OpenAI. You may add any legal parameters that OpenAI uses. Required field. |
| configuration.blockRuns     | number of times to run your block. This will be the number of times you call OpenAI API. Default value is 1.         |
| executions[n].dataFile      | path of your data file. This is the input into the prompt. Required field.                                           |
| executions[n].id            | unique id of the batch job. Required field.                                                                          |
| executions[n].prompt        | path of your prompt template file. Required field.                                                                   |


#### Output
The output looks something like below. I've truncated the actual results to improve readability.
```json
{
  "projectName": "product-summary",
  "projectVersion": "2.8",
  "blockId": "product-1",
  "blockRuns": [
    {
      "blockRun": 1,
      "blockResults": [
        {
          "input": {
            "prod_review": "Got this panda plush toy for my daughter's birthday..."
          },
          "output": "The panda plush toy is soft, cute, and has a friendly look, but the reviewer thinks..."
        },
        {
          "input": {
            "prod_review": "Needed a nice lamp for my bedroom, and this one had..."
          },
          "output": "The lamp has additional storage and is reasonably priced. The company has excellent customer..."
        },
        {
          "input": {
            "prod_review": "Got this panda plush toy for my daughter's birthday.."
          },
          "output": "The panda plush toy is soft, cute, and loved by the recipient. However, the price may be too high..."
        },
        {
          "input": {
            "prod_review": "Needed a nice lamp for my bedroom, and this one had..."
          },
          "output": "The customer found the lamp to be a good value with additional storage and fast shipping. The company's..."
        }
      ]
    }
  ]
}
```
#### CLI
To run the batch command with _blockId_ product-1

> air run -p product.eom -b product-1

The number of calls to OpenAI will be

> block_runs * {number of array items in data file}.

In the case above, its

> 2 * 2 = 4

### All Experiments

The following fields are for a block in an experiment plugin. Use this is as a reference.

| Field                           | Description                                                                                                                                                                                   |
|---------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| configuration.requestParams     | the request parameters that are sent to OpenAI. You may add any legal parameters that OpenAI uses. Required field.                                                                            |
| configuration.blockRuns         | the number of times to run your block. This will be the number of times you call OpenAI API. Default value is 1.                                                                              |
| configuration.responseFormat    | either "json" or "text". The default value is "text" if not specified                                                                                                                         |
| executions[n].id                | unique id of the experiment. Currently optional but this may change in future releases.                                                                                                       |
| executions[n].promptChain       | the path of your prompt template files. Required field. Must contain at least one element.                                                                                                    |
| executions[n].properties        | any properties you want to fill-in to the prompt template. This field is optional.                                                                                                            |
| executions[n].chainRuns         | the number of times to run the chain of defaults. Default value is 1                                                                                                                          |
| executions[n].systemMessageFile | file containing the system message to use. Optional field.                                                                                                                                    |
| executions[n].fixJson           | if your response is in JSON format, this will flag the tool to try to extract a valid JSON that is surrounded by unwanted external text that the AI may generate. The default value is false. |


### Simple Experiment

The following sample project shows how to run a single prompt multiple times and to collect the results.
These experiments are independent of each other. In the sections on chaining, we will see how to run
experiments where the prompts are dependent on each other.

Start by creating a **simple-story.prompt** file. 

```
Write me a story about ${character}. One Sentence Only.
```
Now create the project file called **project-simple.eom** with an eom extension (experiment object model).

```json
{
  "projectName": "experiment-simple",
  "projectVersion": "1.1",
  "apiKeyFile": "../../api_key",
  "blocks": [
    {
      "blockId": "simple-1",
      "pluginName": "ExperimentGptPlugin",
      "configuration": {
        "blockRuns": 5,
        "requestParams": {
          "model": "gpt-3.5-turbo",
          "temperature": 1.2,
          "top_p": 1,
          "max_tokens": 500
        }
      },
      "executions": [
        {
          "id": "exp-1",
          "systemMessageFile": "../system-message.txt",
          "responseFormat" : "text",
          "promptChain": [
            "simple-story.prompt"
          ],
          "properties": {
            "character": "Commander in Starfleet"
          }
        }
      ]
    }
  ]
}
```

The _${character}_ value under the executions properties is substituted into the prompt. 
The calculated prompt for the experiment is
````
Write me a story about Commander in Starfleet. One Sentence Only.
````

#### Output
The output will look something like the following. It shows the interaction of chat completion.
Since it is not chained, it only contains a simple request/response. You can also see
how many _promptTokens_ were used, as well as the _completionTokens_ that were used in the response.
This will be useful in calculating the cost of your requests.

```json
{
  "projectName": "experiment-simple",
  "projectVersion": "1.1",
  "blockId": "simple-1",
  "blockRuns": [
    {
      "blockRun": 1,
      "blockResults": [
        {
          "role": "user",
          "content": "Write me a story about Commander in Starfleet. One Sentence Only.",
          "promptFile": "simple-story.prompt",
          "chainRun": 1,
          "promptTokens": 32,
          "promptValues": {
            "character": "Commander in Starfleet"
          }
        },
        {
          "role": "assistant",
          "content": "After traveling through various galaxies and fighting countless battles, the commander retired to a peaceful planet and lived out the rest of their days among local communities.",
          "promptFile": "simple-story.prompt",
          "chainRun": 1,
          "completionTokens": 29,
          "totalTokens": 61,
          "promptValues": {
            "character": "Commander in Starfleet"
          }
        }
      ]
    }
  ]
}
```


#### CLI
To run the experiment command. 

> air run -p project-simple.eom

This runs with _simple-story.prompt_ 5 times.

### Chain Experiment with Single Prompt
Chained prompts are useful when you want to use the results from one prompt in the next prompt.
In the following case we will use a single prompt feeding back into itself. This technique
can be used for maintaining a strong context between requests, something particularly
useful for generating stories.

Create the prompt file.
```
Write me a story about ${character}. The main character is ${mainCharacterName}. If no main character is given, choose one. Write one sentence only.
The response should be in JSON using the following structure. Only use these fields. {"mainCharacterName": "", "story": ""}
```

Now create the eom project file: **project-single.eom**. Note that we are defining the _character_ value as "Commander in Starfleet"
but are not defining any _mainCharacterName_. We will let the AI do this for us.

```json
{
  "projectName": "experiment-chain-single",
  "projectVersion": "1.1",
  "apiKeyFile": "../../api_key",
  "blocks": [
    {
      "blockId": "single-1",
      "pluginName": "ExperimentGptPlugin",
      "configuration": {
        "blockRuns": 1,
        "requestParams": {
          "model": "gpt-3.5-turbo",
          "temperature": 1.2,
          "top_p": 1,
          "max_tokens": 500
        }
      },
      "executions": [
        {
          "id": "exp-1",
          "systemMessageFile": "../system-message.txt",
          "responseFormat" : "json",
          "chainRuns": 1,
          "promptChain": [
            "simple-story.prompt"
          ],
          "properties": {
            "character": "Commander in Starfleet",
            "mainCharacterName": ""
          }
        }
      ]
    }
  ]
}
```
Since we are chaining requests on the single prompt, it's important to set the _response_format_ field to "json".
This is how the response knows how to map itself to the properties in the next request.

You may also choose to set _fixJson_ to true. This will try to cleanup any extra text
the AI may add in addition to the JSON response. For example, the following case is common:

> "As an AI assistant...{"foo" :" "bar"}"

To run the experiment command

> air run -p project-single.eom -b exp-1

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
The following example shows how we can use a chain to run prompts with simulated user input. This
user input will be generated by OpenAI based on the context of the chat completions.

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

Now create an eom project file called **project-chain.eom**

```json
{
  "projectName": "experiment-chain-multiple",
  "projectVersion": "1.4",
  "apiKeyFile": "../../api_key",
  "blocks": [
    {
      "blockId": "chain-1",
      "pluginName": "ExperimentGptPlugin",
      "configuration": {
        "blockRuns": 1,
        "requestParams": {
          "model": "gpt-3.5-turbo",
          "temperature": 1.2,
          "top_p": 1,
          "max_tokens": 500
        }
      },
      "executions": [
        {
          "id": "exp-1",
          "responseFormat" : "json",
          "chainRuns": 2,
          "promptChain": [
            "structured-story.prompt",
            "character-action.prompt"
          ],
          "excludesMessageHistory": [
            "character-action.prompt"
          ],
          "fixJson": true,
          "properties": {
            "rank": "Commander in Starfleet",
            "show": "The Original Star Trek",
            "mainCharacterName": "",
            "story": "",
            "characterAction": ""
          }
        }
      ]
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

#### CLI
To run the experiment

> air run -p project-chain.eom -b exp-1
> 
### Experiment Output Files

For each run, you will get a record of the request sent and response received:

#### Request
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
#### Response
The response allows you to determine tokens used.
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

#### Metrics
The metrics.csv file will give you the performance times and token usage for each experiment. In this case, there was an alternating run of two prompts. 
The story prompt takes 3.9 and 5.7 seconds to run.
```
request_id, prompt_name, request_time, prompt_tokens, completion_tokens, total_tokens
chatcmpl-774QSUZEM0qGzIHSkjdc1YB6SnqqU, structured-story.prompt, 3872, 126, 55, 181
chatcmpl-774QWC735h8zqC48NdDvQBbAK4wtI, character-action.prompt, 2361, 91, 30, 121
chatcmpl-774QYzgnx9x3UjxPjd4ef4lotUPI1, structured-story.prompt, 5668, 190, 72, 262
chatcmpl-774QelDpcSp02xIJSH2kpdj1WyNsJ, character-action.prompt, 2057, 111, 23, 134
```

## Install Program
Make sure your have dart installed. Follow the instructions, in the link below.

https://dart.dev/get-dart

After installation, you can install the gpt program with the following command

> dart pub global activate gpt

After activating, use the command in the next section.

## Command Help
> air --help

```
A command line tool for running GPT commands

Usage: air <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  clean   Cleans project's output directory
  count   Returns the number of OpenApiCalls that would be made
  run     Runs a plugin

Run "air help <command>" for more information about a command.
```
## Additional Commands
### Clean Project
To clean a project, run the following

> air clean -p myproject

This deletes the _output_ directory for the project.

### Count of OpenAI Calls for a Project
Running OpenAI calls with a tool can be costly if you mis-configure it. 
To determine how many OpenAI calls a project will create, run the following command

> air count -p myproject

or for the count of a specific block

> air count -p myproject -b myblockId
It will output 

```
Project: product-summary-2.8
Total OpenAPI Calls would be 12
```

### DryRun
If you want to know that your project is doing before incurring costs to OpenAI, use the dryRun flag.

>  air run -p project-image.eom --dryRun

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
