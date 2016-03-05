# Sample MDP Web-app using Sinatra

From the [Sinatra homepage](http://www.sinatrarb.com/) README file: "Sinatra is a DSL for quickly creating web applications in Ruby with minimal effort"

The purpose of this demo app is to show how you can interact with the MDP API in a web-server format. If you'd like a command-line demonstration go up a level to the "Ruby" samplecode directory.

## Setup

Download the MDP sample code repository
    
    git clone https://github.com/athenahealth/mdp
    
    cd mdp/samplecode/sinatra

You'll need to create a `.key` and `.secret` file in this directory to gain access. DO NOT ADD THESE TO THE REPO! There is already an exception for .key and .secret files in the .gitignore for this repository, but if you're copying just this subfolder, you'll have to add that exception to your own .gitignore file.

If you don't know your key and secret, go to developer.athenahealth.com and login using the username and password you signed up with. Go to the IO Docs and select the 'Taco' application from the 'Existing Client Credentials' drop-down. Copy the 'Client ID' into your plain text .key file and copy the 'Client Secret' into your plain text .secret file.

## Running Sinatra
From within this directory, run

    ruby app.rb

Then visit your [http://localhost:4567](http://localhost:4567), or whatever port Sinatra displays on the command line.

## Third Party Software Included
- [Bootstrap 3.3.6](https://getbootstrap.com)
- [jQuery 1.12.1](https://jquery.com)