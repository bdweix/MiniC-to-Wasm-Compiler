# Web Assembly

**Goal**: compile `MiniC` assembly code into Web Assembly `wasm`.

**Proposed Solution**: all web assembly code can be represented in a more readble, `.wat` text format. The proposed solution will involve compiling `MIPS` code generated from the `MiniC` compiler, into `S-Expressions`. The fundamental units of WASM are modules, and can be thought of as a "tree of nodes that describe the modules structure and code" ([source](https://developer.mozilla.org/en-US/docs/WebAssembly/Understanding_the_text_format)). We can build a compiler that will compile the list of assembly instructions into a list of `S-Expressions` . This `.wat` file can then be converted to `.wasm` using existing toolchains. Once complete a user would be able to run:

```bash
./compile input.asm output.wasm
```

**Notes**: see the notes folder for a collection of notes on web assembly

**Proposed Goals:**

- [ ] Explore Fundamentals of WebAssembly
- [ ] Configure local environment for running WebAseembly
- [ ] Write Basic Function in `MiniC`
- [ ] Write Basic Function `.wat`
  - [ ] Breakdown syntax of `S-Expressions`
  - [ ] Competently write by hand `.wat` functions 
- [ ] Convert functions from `C` to `.wat` by hand
- [ ] Map out corresponding types between potential `MiniC` code and `S-Expressions`
- [ ] Compile `MiniC` assembly into `.wat`
  - [ ] Understand and implement `OCaml` processes for reading in files (`.asm`)
  - [ ] Understand and implement `OCaml` processes for writing out files (`.wat`)
  - [ ] Compile `.asm` into `.wat` 
  - [ ] Compile `.wat` into .`wasm` (in any tool chain)
  - [ ] Compile `.wat` into `.wasm` (in OCaml toolchain)


# Web Assembly Notes

Article Resources:

- https://www.infoworld.com/article/3291780/what-is-webassembly-the-next-generation-web-platform-explained.html
- https://medium.com/javascript-scene/what-is-webassembly-the-dawn-of-a-new-era-61256ec5a8f6
- https://hackernoon.com/write-and-run-webassembly-in-your-browser-today-77b39c92ead0

General Idea (mostly notes from source 1):

- Javascript is the only programming language that we can use natively in a web browser
- Javascript can be slow and sluggish for high intensity applications like CAD, 3D Modeling, Video games, etc.
- WebAssembly (.wasm) is a new language that is supported by all browsers can be run alongside Javascript (eventually could replace)
- WA is a "compilation target", meaning you write in a different language and your code is compiled into web assembly byte code, and this bytecode is run on the client (web browser), eventually becoming native machine code
- Asm.js (http://asmjs.org/) is a low-level subset of JavaScript, WebAssembly is different and seems to offer the same or better efficiencies, but you can write in any language you please

Three Ways to make WA Code:

1. Direct Compilation: source is translated directly into WebAssembly by the languages own compiler toolchain. Rust, C/C++, Kotlin/Native, and D all support those languages
2. 3rd Party Tools: Java, Lua, and .NET all have some tools to support this 
3. WebAssembly Based Intrepreter: "Here, the language itself isn’t translated into WebAssembly; rather, an interpreter for the language, written in WebAssembly, runs code written in the language. This is the most cumbersome approach, since the interpreter may be several megabytes of code, but it allows existing code written in the language to run all but unchanged. Python and Ruby both have interpreters translated to WASM."

Demos:

- WebAsssembly Video Editor (https://d2jta7o2zej4pf.cloudfront.net/)

WASM Fiddle: 

- https://wasdk.github.io/WasmFiddle/?tz9tu
- https://wasdk.github.io/WasmFiddle/?ttxwx
- https://github.com/WebAssembly/spec
- web assembly S Expression syntax 
- S Expression - learn that 
- mini c while loops if statements variables recursive functions 
- https://blog.scottlogic.com/2018/04/26/webassembly-by-hand.html
- https://webassembly.studio/?f=ivzzdwn7fcn (this is great!!)

PHP and WebAssembly:

- https://github.com/wasmerio/php-ext-wasm
- https://github.com/oraoto/pib

S Expression:

- we want to turn MiniC into S Expressions code
- then turn S Expressions code into WASM
- should'nt be too hard
- https://developer.mozilla.org/en-US/docs/WebAssembly/Text_format_to_wasm
- https://developer.mozilla.org/en-US/docs/WebAssembly/Understanding_the_text_format



Project Goals:

- Be able to turn S expression into web assemble (https://developer.mozilla.org/en-US/docs/WebAssembly/Text_format_to_wasm)
