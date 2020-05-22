# solawibestellsystem

This is the Solawi Bestellsystem written in MySQL, Perl-REST, Javascript
 
## Setup

In principle the Javascript can be executed directly in the Browser but in order to get the
benefits of test-execution you will need [NodeJS](https://nodejs.org/en/).

### NodeJS

In order to use tests you first have to install NodeJS. This can be done via NVM or directly.

#### NVM

[NVM](https://github.com/nvm-sh/nvm) the *Node Version Manager* allows you to easily switch
between different versions of NodeJS. As a side-effect it makes installing NodeJS a breeze.

##### Linux / MacOS

In order to install simply paste the following code in your terminal in this sample bash.
```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
```
 
If you use e.g. zsh just enter 
```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | zsh
``` 
instead.

##### Windows

The installer for Windows can be found at [NVM-Windows](https://github.com/coreybutler/nvm-windows).

##### Installing NodeJS with NVM

You can verify that your installation was successful by typing
```
nvm --version
```
in the command line. It should print
```
0.34.0
```
Then install node by typing
```
nvm install --lts=dubnium
```
for the latest long-term support version of NodeJS.

#### NodeJS directly

Head over to the [NodeJS Download Page](https://nodejs.org/en/download/) and follow the instructions.

### Install the project

Now with the prerequisites done, checkout the project and inside its root folder type

```
npm i
```
That will install the required node packages. You're now set up.

### Run the project

You can run the project with multiple *npm* scripts.

####  Run

If you just want to startup the project type:

```
npm start
```
Because it uses ParcelJS under the hood you now can browse to [http://localhost:1234](http://localhost:1234)

If you prefer that the project will directly adapt to your changes run
```
npm run watch
```
instead. and then browse to [http://localhost:1234](http://localhost:1234)

#### Test

You can run the Jest tests by typing:
```
npm test
```

If you want to have the test run every time you save something run:
```
npm run test-watch
```
