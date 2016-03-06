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

# Contents
This app has a bunch of stuff all over the place for you to poke at.

## Basic Authentication
- apiconnection.rb
   - Handles setting up a secure connection to api.athenahealth.com, storing that connection in a global variable for other classes to use. Note: this app is single-threaded and very simple, but don't use global connection patterns in production!
- authenticator.rb
   - Manages tokens and authorizes requests by inserting them
   - It uses the .key and .secret files you've saved to ask athenahealth for a token then saves that token to a plain-text file `.token`. Don't add this .token file to version control
   - Uses ApiConnection to talk to the API

## Managing Requests
- apirequest.rb
   - Manages requests for REST-ful models from the API
   - Uses Authenticator to attach tokens to request
   - Uses the response from a request to set the properties of a local model instance
   - It's pretty dumb: if the request fails due to 'Not Authorized', it will request a new token via the Authenticator, but only once. It doesn't handle any other types of failures.
- model.rb
   - Basic (mostly) abstract class that contains a base_path method assuming a practiceid and the authentication version
- Other models
   - department.rb
      - Inherits from Model, has a subset of the full list of properties stored at the API's `/departments` url
   - provider.rb
      - Inherits from Model, also has a subset of `/providers` properties

## Main App
- app.rb
   - This file contains a few paths, including the home page, departments url and providers url. It also has a demonstration of a mustache template (for loading asynchronously) and a JSON path for passing example model data to a front-end mustache view to be rendered there

## Javascript
- All third party software is included under public/vendors
- All of our app's javascript is under public/scripts/
   - app.js
      - Pretty shallow, just initializes appointment.js
   - appointment.js
      - Attaches a click-handler to all of the appointment buttons when you're on the provider page. When the button is clicked, it will query the server for a list of appointments that match that provider's id (which is stored on the button). For now, the server has a hard-coded list of fake appointments
   - See templates/appointment.mustache for how the appointment HTML gets rendered

## Third Party Software Included
- [Bootstrap 3.3.6](https://getbootstrap.com)
- [jQuery 1.12.1](https://jquery.com)
- [require.js 2.1.22](http://requirejs.org/)
- [Mustache 2.2.1](https://github.com/janl/mustache.js/)