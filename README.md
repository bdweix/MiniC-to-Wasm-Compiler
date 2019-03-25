# Web Assembly

**Goal**: compile `MiniC` assembly code into Web Assembly `wasm`.

**Proposed Solution**: all web assembly code can be represented in a more readble, `.wat` text format. The proposed solution will involve compiling `MIPS` code generated from the `MiniC` compiler, into `S-Expressions`. The fundamental units of WASM are modules, and can be thought of as a "tree of nodes that describe the modules structure and code" ([source](https://developer.mozilla.org/en-US/docs/WebAssembly/Understanding_the_text_format)). We can build a compiler that will compile the list of assembly instructions into a list of `S-Expressions` . This `.wat` file can then be converted to `.wasm` using existing toolchains. Once complete a user would be able to run:

```bash
./compile input.asm output.wasm
```

**Resources**: see the Resources.md folder for a collection of notes on web assembly

**Proposed Goals:**

- [x] Explore Fundamentals of WebAssembly
- [x] Configure local environment for running WebAseembly
- [ ] Break down `MiniC`
  - [x] Step 1 - Setup
  - [x] Step 2 - System Args
  - [x] Step 3 - Debugging Setup
  - [x] Step 4 - Enviromnent Creation
  - [x] Step 5 - Parsing/Lexing
  - [x] Step 6 - Debugging File
  - [x] Step 7 - Static Type Checking
  - [x] Step 8 - Checking for Main
  - [x] Step 9 - Naming
  - [ ] Step 10 - Lifting
  - [ ] Step 11 - Copying
  - [ ]  Step 12 - Quads
  - [ ] Step 13 - MIPS Codestream
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

- 

