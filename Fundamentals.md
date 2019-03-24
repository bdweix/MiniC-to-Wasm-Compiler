# Fundamentals of Web Assembly

- Javascript is the only programming language that we can use natively in a web browser
- Javascript can be slow and sluggish for high intensity applications like CAD, 3D Modeling, Video games, etc.
- WebAssembly (.wasm) is a new language supported by all browsers that can be run alongside Javascript in the browser
- WA is a "compilation target", meaning you write in a different language and your code is compiled into web assembly byte code, and this bytecode is run on the client (web browser), eventually becoming native machine code
- Asm.js (http://asmjs.org/) is a low-level subset of JavaScript, notably different than WebAssembly.

Methods for Creating Web Assembly*:

1. Direct Compilation: source is translated directly into WebAssembly by the languages own compiler toolchain. Rust, C/C++, Kotlin/Native, and D all support those languages
2. 3rd Party Tools: Java, Lua, and .NET all have some tools to support this 
3. WebAssembly Based Intrepreter: "Here, the language itself isn’t translated into WebAssembly; rather, an interpreter for the language, written in WebAssembly, runs code written in the language. This is the most cumbersome approach, since the interpreter may be several megabytes of code, but it allows existing code written in the language to run all but unchanged. Python and Ruby both have interpreters translated to WASM."

***Source:** https://www.infoworld.com/article/3291780/what-is-webassembly-the-next-generation-web-platform-explained.html

## 



