# Stackwire Runner for OpenAI
A command line app for experimenting with OpenAI API prompts
> Currently only chat completion API is supported.

## Setup Experiment
An experiment will require three files
* experiment file - this contains all the configuration info needed to make the call to OpenAI
* prompt file - this is the file that you want to include as the prompt to OpenAI
* API key file - contains your OpenAI API Key

First create your experiment file. You can name it anything, by default the program will look for 'experiment.json'
 ```
 {
  "experiment_name" : "my_exp",
  "number_of_runs" : 2,

  "output_dir" : "output",
  "api_key_file": "api_key.txt",
  "prompt_template" : "data/prompt.template",
  "ai_config" : {
    "model": "gpt-3.5-turbo",
    "temperature": 1.2,
    "top_p": 1,
    "max_tokens": 500
  },
  "template_values" : {
    "COMMANDER_NAME" : "Commander in Starfleet",
    "COMMANDER_DESCRIPTION" : "My Example Description"
  }
}
 ```
| Field           | Description                                                                                             |
|-----------------|---------------------------------------------------------------------------------------------------------|
| experiment_name | The name of your experiment. Don't use spaces or illegal characters.                                    |
| number_of_runs  | The number of times to run your experiment. This will be the number of times you call OpenAI API.       |
| output_dir           | directory where you want to put the output                                                              |
| api_key_file           | the path of your api key file                                                                           |
| prompt_template           | the path of your prompt template                                                                        |
| template_values           | any values you want to fill-in to the prompt template. This field must exist but may have no values.    |
| ai_config           | the configuration parameters that are sent to OpenAI. You may add any legal parameters that OpenAI uses |

Next create your prompt file: You can name it anything, in our case it is **data/prompt.template**. An example is given below. The template value from the experiment file will replace the special syntax {{COMMANDER_NAME}}
```
Write me a story about {{COMMANDER_NAME}}. One Sentence Only.
```
The prompt sent to OpenAI will be

````
Write me a story about Commander in Starfleet. One Sentence Only.
````

Finally, add a file that contains your your API Key (the one below is not real). In our example. we call it **api_key.txt**
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

## Building this project
Make sure that you have dart installed. And then From the project root
> dart pub get
> 
> dart compile exe bin/stackwire.dart -o stackwire

