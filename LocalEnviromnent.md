# Setting up Local Enviroments

The Web Assembly organization offers some general instructions for setting up your local machine: <https://webassembly.org/getting-started/developers-guide/>. I will go through these instructions for getting everything installed in Mac OS X.

### Prerequisities

- Git. On Linux and OS X this is likely already present. On Windows download the [Git for Windows](https://git-scm.com/) installer.
- CMake. On Linux and OS X, one can use package managers like `apt-get` or `brew`, on Windows download [CMake installer](https://cmake.org/download/).
- Host system compiler. On Linux, [install GCC](https://askubuntu.com/questions/154402/install-gcc-on-ubuntu-12-04-lts). On OS X, [install Xcode](https://itunes.apple.com/us/app/xcode/id497799835). On Windows, install [Visual Studio 2015 Community with Update 3](https://www.visualstudio.com/downloads/) or newer.
- Python 2.7.x. On Linux and OS X, this is most likely provided out of the box. See [here](https://wiki.python.org/moin/BeginnersGuide/Download) for instructions.

### 1. Installing the Toolchain

We will be using the prebuilt Emscripten toolchain for use with Web Assembly development. As stated on their [website](https://emscripten.org/index.html):

 *"Emscripten is a toolchain for compiling to **asm.js** and **WebAssembly**, built using **LLVM**, that lets you run C and C++ on the web at near-native speed without plugins."*

This will allow us to local compile raw `C` and `C++` files directly into `.wasm` files. They also provide a nice web simulator that will allow us to easily run these `.wasm` files on our local machines, without the need to manually set up a server. 

Navigate to your root directory on your machine and run the following commands:

```bash
$ git clone https://github.com/emscripten-core/emsdk.git
$ cd emsdk
$ ./emsdk install latest
$ ./emsdk activate latest
```

This will create a folder called `emsdk` and install the appropiate software for you ([GitHub link here](https://github.com/emscripten-core/emsdk)). 

### 2. Adding to Path

We now need to add the toolchain to our path. Navigate into the `emsdk` folder and run the following:

```bash
$ source ./emsdk_env.sh --build=Release
```

This command will need to be rerun every time you wish to use the compiler toolchain. You can either permentatly add these variables to your `bash_profile`, or I added a simple alias with ZSH that I can run by calling `wasm-start`: 

```bash
alias wasm-start="cd ~/emsdk; source ./emsdk_env.sh --build=Release; cd ..;"
```

### 3. Creating a Project

In order to keep things organized, I set up a `Code` folder within my root directory, and within that a `projects` folder. Inside of the projects folder I made a new project called `web-assembly` . Let's start by creating a simple project that will compile `C` into `WASM` and run it in our browser. For this project let's compile the recursive factorial function into Web Assembly.

Inside of your projects folder make a new folder called Factorial (`mkdir factorial`). Open this up in Atom and create a `factorial.c` file (`touch factorial.c`). Inside of this file we will write the factorial function:

```c
#include <stdio.h>
long int multiplyNumbers(int n);

int main()
{
        int n;
        printf("Enter a positive integer: \n");
        scanf("%d", &n);
        printf("Factorial of %d = %ld \n", n, multiplyNumbers(n));
        return 0;
}
long int multiplyNumbers(int n)
{
        if (n >= 1)
                return n*multiplyNumbers(n-1);
        else
                return 1;
}
```

We will now run the following command from our terminal:

```bash
emcc factorial.c -s WASM=1 -o factorial.html
```

This command 1) accesses the `emcc` toolchain that we installed. We are then passing as an input the `factorial.c` file we created. Because the `emcc` toolchain can also compile to `asm.js` (not web assmebly), we must specify to make .wasm with the `-s WASM=1` linker flag. Finally we tell the program to create an output file called `factorial.html`. This will allow us to view and run the `.wasm` file (which is created with the same `factorial` name) in our browser. 

If all goes well, you will have no response and see that in your Factorial folder there is now:

![file_structure](/source_imgs/file_structure.png)

Congrats! You just turned a simple `C` program into `Web Assembly` without doing almost anything!

### 4. Running Web Assembly Locally

Now in order to test thigns, thankfully the `emcc` toolchain comes with a some basic server tools. Simply go into the Factorial folder and run:

```bash
emrun --no_browser --port 8080 .
```

This will deploy a webpage at http://localhost:8080 (Port 8080) that also contains an interactive simulator for running the newly created `.wasm` file. When you open this page you should see your folder directory:

![wasm_server](/source_imgs/wasm_server.png)

Click on the `factorial.html` file and you will be brought into the Emscripten simulator. You should immediately see a browser dialog asking for an input (aka our scanf in C). Enter a number and then hit the "Okay" button. Note: there seems to be a bug that sometimes keeps the input dialog open, if it doesn't disappear after submitting, click the cancel button and the function will run with your previous input. You will now see the output in the Emscripten console:

![emscripten_live](/source_imgs/emscripten_live.png)

You will see that I've also opened the console and can see our function properly logged to the console as well!

### Known Bugs

- When using a `printf` statement, you must always print a newline (`\n`) at the end of the statement 
- Input dialogs occasionally do not close. To fix, submit your input and then hit cancel for the program to proceed

### Alias Commands

The commands can be a bit verbose to remember and constantly type. For those looking for shortcuts I've added these aliases and functions to my `bash_profile`:

```bash
alias wasm-projects="cd ~/Code/projects/web-assembly; atom .;"
alias wasm-start="cd ~/emsdk; source ./emsdk_env.sh --build=Release; cd ..;"

#function shortcuts 
function wasm-make() { emcc "$1".c -s WASM=1 -o "$1".html }
function wasm-serve() { emrun --no_browser --port "$1" . }

```

- `wasm-projects` - this will quickly navigate me into my projects folder
- `wasm-start` - this will add all of the required variables to my current terminal path
- `wasm-make` - once inside of a folder, this will automatically create the required wasm files. It accepts the root of the `C` file name. For example, with factorial I would call `wasm-make factorial` and it will find the original `factorial.c` file and create an output `factorial.html`
- `wasm-serve` - this function accepts one paramters, the port, and launches a serve from the current directory on that specificed port. For example, I would run `wasm-server 8087` to deploy a serve on http://localhost:8087



