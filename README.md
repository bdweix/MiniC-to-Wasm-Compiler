# WebAssembly

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
