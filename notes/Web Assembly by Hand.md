# Web Assembly by Hand

Note: outdated, using for reference. Most notes copied into Mini Web Assmebly Overview

Web Assmebly files are stored as `.wasm` files. However, Web Assmebly also offers a more readable, human friendly format called `.wat`. This format is in [S-expressions](https://en.wikipedia.org/wiki/S-expression).

**Note: the following notes have been assembled from various articles, sometimes copy-pasted with attributes provided. Intent is on a cohesive compilation.**

Running code by hand online here: <https://webassembly.studio/>

## S-Expressions ([source](https://developer.mozilla.org/en-US/docs/WebAssembly/Understanding_the_text_format))

S-expressions are a set of trees, and each node in the tree goes inside of a pair of parentheses. While a bit verbose for readability, these paratheneses make the underlying tree structure extremely clear. Let's take a look at some basic `.wat` code:

```wasm
(module (memory 1) (func))
```

Overall the structure goes such that first item inside of the parenthesis tells you what type of node it is, and after that there is a space-seperated list of attribtues or child nodes. This code represents a tree with a root node "module" and two child nodes, "memory" and "func". The "memory" node has an attribute "1". A single Web Assmebly function will have one module.

## Types

Web Assembly currently has four types:

- `i32` - 32 bit integer
- `i64` - 64 bit integer
- `f32` - 32 bit float
- `f64` - 64 bit float

## Types of Nodes

**More notes coming soon**

- Module - the main node
- Functions - function declaration
- Import - import declaration
- Exports - export declaration
- Globals - globals, can be immutable or mutable
- Code - function bodies
- Data (memory) - used for storing more comlex data types
- Tables + Elem - declaring and using the indirect function table
- Type - function signature declarations, I believe this is used by indirect function calls to asset type

## Calling WASM from Javascript

*more details to come*

```JavaScript
WebAssembly.instantiateStreaming(fetch('add.wasm'))
  .then(obj => {
    console.log(obj.instance.exports.add(1, 2));  // "3"
  });
```

## Stack Machine

Examples copied from source, great memory diagrams here as well: <https://rsms.me/wasm-intro#import_section>

Web Assembly execution ultimately runs a stack machine where ever instruction pushes and/or pops a certain number of values (of the above types) to and from the stack. The beginning of every function starts with an empty stack. At the end of the function, there should only be one item on the stack, and that item should match the return type. If there is no return type, then the stack must be empty. The code should not compile if this isn't true.

```asm
get_local 0  // push parameter 0 on stack (our dividend)
i64.const 2  // push constant int64 "2" on stack (our divisor)
i64.div_u    // unsigned division pushes result onto stack
end          // ends function, resulting in one i64 (top of stack)
```

Another example:

```asm
i32.const 123  // for the purpose of demonstration, push "123" to the stack
set_local 0    // pop "123" off of the stack and store it into local #0
// use the stack for other operations...
get_local 0    // "123" is pushed to the top of the stack
```

## Functions

Most of the code within a web assembly module is grouped into functions. Functions follow the following format:

```wasm
( func <signature> <locals> <body> )
```

- `signature` - declares what the function takes and returns
- `locals` - explicitly typed variables
- `body` - linear list of low-level instructions

### Signatures

Signatures declare that functions paramters and return type. Paramters are denoted with the `param` keyword and have the structure of "`param type`" or "`param $name type`". The return is denoted by the keyword `result` followed by a type. Locals are denoted with a keyword `local` followed by a type. All together it looks like this (within a module):

```asm
(func (param i32) (param i32) (local i32) (result f64) ... )
```

This would declare a function that has two parameters of types 32-bit integers, and the result would be 64-bit floating point number. Note: the absence of result means that the function does not return anything, and there is a limit of one return type currently ([on the list](https://webassembly.org/docs/future-features/#multiple-return))

### Getting/Setting Params and Locals

Params and locals can be get/set with the commands `get_local` and `set_local` ([reference here](http://webassembly.github.io/spec/core/syntax/instructions.html#syntax-instr-variable)). These commands accept either an index or a $name (covered in next section). Let's look at the following code:

```asm
(func (param i32) (param f32) (local f64)
  get_local 0
  get_local 1
  get_local 2)
```

In this example the `get_local 0` command is retrieving index 0 parameter (`param i32`), and the `get_local 2` would be retrieving the `local f64` local variable.

### Naming Parameters, Locals

Because it's difficult to read based purely on indexes, these functions also support naming:

```asm
(func (param $num1 i32) (param $num2 f32) (local $var1 f64)
  get_local $num1
  get_local $num2
  get_local $var1)
```

We simply denote the name of the paramter or local with a dollar sign followed by the name, as displayed. 

### Simple .wat Function

Let's look at a simple function that adds together to numbers:

```asm
(module
  (func (param $lhs i32) (param $rhs i32) (result i32)
    get_local $lhs
    get_local $rhs
    i32.add))**
```

This function takes into two paramters called `$lhs` and `$rhs`, both of type `i32`. It returns a single value or type `i32`.  We then run `get_local` function which according to the [documentation](http://webassembly.github.io/spec/core/exec/instructions.html) says:

```bash
F;(𝗅𝗈𝖼𝖺𝗅.𝗀𝖾𝗍 x) ↪ F;val (ifF.𝗅𝗈𝖼𝖺𝗅𝗌[x] = val)
```

1. Let FF be the [current](http://webassembly.github.io/spec/core/exec/conventions.html#exec-notation-textual) [frame](http://webassembly.github.io/spec/core/exec/runtime.html#syntax-frame).
2. Assert: due to [validation](http://webassembly.github.io/spec/core/valid/instructions.html#valid-local-get), F.[𝗅𝗈𝖼𝖺𝗅𝗌](http://webassembly.github.io/spec/core/exec/runtime.html#syntax-frame)[x]F.locals[x] exists.
3. Let [val](http://webassembly.github.io/spec/core/exec/runtime.html#syntax-val)val be the value F.[𝗅𝗈𝖼𝖺𝗅𝗌](http://webassembly.github.io/spec/core/exec/runtime.html#syntax-frame)[x]F.locals[x].
4. Push the value [val](http://webassembly.github.io/spec/core/exec/runtime.html#syntax-val)val to the stack.

More simply we are getting the parameters `$lhs` and `$rhs` and pushing them onto the stack. The `add` command then pops off two items from the stack and adds them together, pushing the result onto the stack now. This is our last instruction and the stack has one item, which is of our return type - the function now returns this type.

### Naming Functions

Like paramters and locals, functions can be named with a similar `$name` notation:

```bash
(func $add … )
```

### Exporting Functions

In order to call `wasm` functions in Javascript, we must explictly export them. To do this, we create an `export` node:

```asm
(module
  (func $add (param $lhs i32) (param $rhs i32) (result i32)
    get_local $lhs
    get_local $rhs
    i32.add)
  (export "add" (func $add))
)
```

The string "add" is the name of the function that will be used in Javascript, whereas the func $add is the `wasm` function. You can also call this by function index instead of name.

### Calling other Functions in the same Module

The `call` command allows you to call another function directly in the same module directly:

```asm
(module
  (func $getAnswer (result i32)
    i32.const 42)
  (func (export "getAnswerPlus1") (result i32)
    call $getAnswer
    i32.const 1
    i32.add))
```

### Declaring Globals

We can export globals for use in both Javascript and `wasm` functions. To do so, use the following syntax:

```asm
(global $g (import "js" "global") (mut i32))
```

This creates a global called `$g` and declares that it is mutable of type `i32`

### Memory

Because Web Assembly only supports four types (floats and integers), we need a way to store more complex data types such as strings. It more or less converts strings into an arrya of bytes that grows. We can use the `i32.load` and `i32.store` functions for reading and writing from memory. You can currently only have one memory instance per module. We can write data into the global memory by using the keyword `data`. We import the javascript global memory below as well.

```asm
(module
  (import "console" "log" (func $log (param i32 i32)))
  (import "js" "mem" (memory 1))
  (data (i32.const 0) "Hi")
  (func (export "writeHi")
    i32.const 0  ;; pass offset 0 to log
    i32.const 2  ;; pass length 2 to log
    call $log))
```

Note: Web Assmebly defines a page to be 64KB

Note: Comments are denoted by "`;;`"

In the above code we are actually importing the Javascript function `console.log()`, which accepts two parameters in this case. The first paramter is the offset in memory of the string, and the second is the lenght. We are then important the Javascript memory, and saying to create memory with the size of 1 page (64KB). We then write to global WASM memory the string "Hi", passing it the offset at which it's stored. We then define a function `writeHi` and put the offset of 0 and length of 2 on the stack, which are popped off when we `call $log`.

### Tables in Web Assembly ([see docs please](https://developer.mozilla.org/en-US/docs/WebAssembly/Understanding_the_text_format#WebAssembly_tables))

As we saw earlier, we are able to use the `call` with a specific type to call another function. However a problem arises, because functions can be first-class values in both Javascript and WASM, so we may not always know the type to call it at, and WASM is limited to only four types (`i32`/`i64`/`f32`/`f64`). To solve this, WASM introduced tables which resizable arrays of references of `i32` values that simply reference the functions. We can then use `call_indrect` to call these functions.

**Creating a Table**

We can create a table by using the `table` keyword. It accepts two arguments, the size and then type:

```asm
(table 2 anyfunc)
```

In the above code, it creates a table of size 2, and of type `anyfunc`. This is currently the only supported type of a table.

**Adding Functions to Tables**

After creating a table, we must add the functions to the table. We can do this with the keyword `elem`, which accept an `i32` offset and the name(s) or index(es) of the functions:

```asm
(elem (i32.const 0) $f1 $f2)
```

In the above code, we add functions `$f1` and `$f2` to the original table we created, and we start at offset of 0.

**Using Tables (copied and pasted from source, good reference there)**

```asm
(type $return_i32 (func (result i32))) ;; if this was f32, type checking would fail
(func (export "callByIndex") (param $i i32) (result i32)
  get_local $i
  call_indirect (type $return_i32))
```

- The `(type $return_i32 (func (param i32)))` block specifies a type, with a reference name. This type is used when performing type checking of the table function reference calls later on. Here we are saying that the references need to be functions that return an `i32` as a result.
- Next, we define a function that will be exported with the name `callByIndex`. This will take one `i32` as a parameter, which is given the argument name `$i`.
- Inside the function, we add one value to the stack — whatever value is passed in as the parameter `$i`.
- Finally, we use `call_indirect` to call a function from the table — it implicitly pops the value of `$i` off the stack. The net result of this is that the `callByIndex` function invokes the `$i`’th function in the table.

### Factorial Function, C++ to Text

Work on the analysis of this `.wat` code:

```c++
int factorial(int n) {
  if (n == 0)
    return 1;
  else
    return n * factorial(n-1);
}
```

```asm
get_local 0
i64.const 0
i64.eq
if i64
    i64.const 1
else
    get_local 0
    get_local 0
    i64.const 1
    i64.sub
    call 0
    i64.mul
end
```

## Common Commands

The following is all copy/pasted from [this source](https://webassembly.org/docs/semantics/). Note: this source is technically outdated, but provides a concise overview of types and available commands.

**Variables**

- `get_local`: read the current value of a local variable
- `set_local`: set the current value of a local variable
- `tee_local`: like `set_local`, but also returns the set value

**Global Variables:**

- `get_global`: get the current value of a global variable
- `set_global`: set the current value of a global variable

**Control Constructs:**

- `nop`: no operation, no effect
- `block`...`end`: the beginning and end of a block construct, a sequence of instructions with a label at the end
- `loop`…`end`: a block with a label at the beginning which may be used to form loops
- `if`…`end`: the beginning of an if construct with an implicit *then* block
- `else`…`end`: marks the else block of an if
- `br`: branch to a given label in an enclosing construct
- `br_if`: conditionally branch to a given label in an enclosing construct
- `br_table`: a jump table which jumps to a label in an enclosing construct
- `return`: return zero or more values from this function
- `end`: an instruction that marks the end of a block, loop, if, or function

**Effects of Control Instructions on Stack:**

- `return` - pops return value(s) off the stack and returns from the current function (pretty sure only one return type is supported)
- `block` or `loop` - no effect on the stack
- `end` of a `block` or `loop` - no effect on the stack (Unsure what this means: Executing the `end` of the implicit block for a function body pops the return value(s) (if any) off the stack and returns from the function.)
- `if` - pops an `i32` condition off of the stack and either continues or ends
- `else` - sets the program counter to after the corresponding `end` of the `if`
- branches and `loop` - they discard any new values pushed onto the stack in the loop and set the program countrer to the start of the loop
- `drop` - explicitly pop a value from the stack

**Constants:**

- `i32.const` - produce the value of an i32 immediate
- `i64.const`-  produce the value of an i64 immediate
- `f32.const` - produce the value of an f32 immediate
- `f64.const` - produce the value of an f64 immediate

**32-Bit/64-Bit Integer Operators**:

Integer operators are signed, unsigned, or sign-agnostic. Signed operators use two’s complement signed integer representation. There are the same operators for both 32-bit and 64-bit, just change the prefix.

- `i32.add`: sign-agnostic addition
- `i32.sub`: sign-agnostic subtraction
- `i32.mul`: sign-agnostic multiplication (lower 32-bits)
- `i32.div_s`: signed division (result is truncated toward zero)
- `i32.div_u`: unsigned division (result is [floored](https://en.wikipedia.org/wiki/Floor_and_ceiling_functions))
- `i32.rem_s`: signed remainder (result has the sign of the dividend)
- `i32.rem_u`: unsigned remainder
- `i32.and`: sign-agnostic bitwise and
- `i32.or`: sign-agnostic bitwise inclusive or
- `i32.xor`: sign-agnostic bitwise exclusive or
- `i32.shl`: sign-agnostic shift left
- `i32.shr_u`: zero-replicating (logical) shift right
- `i32.shr_s`: sign-replicating (arithmetic) shift right
- `i32.rotl`: sign-agnostic rotate left
- `i32.rotr`: sign-agnostic rotate right
- `i32.eq`: sign-agnostic compare equal
- `i32.ne`: sign-agnostic compare unequal
- `i32.lt_s`: signed less than
- `i32.le_s`: signed less than or equal
- `i32.lt_u`: unsigned less than
- `i32.le_u`: unsigned less than or equal
- `i32.gt_s`: signed greater than
- `i32.ge_s`: signed greater than or equal
- `i32.gt_u`: unsigned greater than
- `i32.ge_u`: unsigned greater than or equal
- `i32.clz`: sign-agnostic count leading zero bits (All zero bits are considered leading if the value is zero)
- `i32.ctz`: sign-agnostic count trailing zero bits (All zero bits are considered trailing if the value is zero)
- `i32.popcnt`: sign-agnostic count number of one bits
- `i32.eqz`: compare equal to zero (return 1 if operand is zero, 0 otherwise)

**32-Bit/64-Bit Floating Operators:**

- `f32.add`: addition
- `f32.sub`: subtraction
- `f32.mul`: multiplication
- `f32.div`: division
- `f32.abs`: absolute value
- `f32.neg`: negation
- `f32.copysign`: copysign
- `f32.ceil`: ceiling operator
- `f32.floor`: floor operator
- `f32.trunc`: round to nearest integer towards zero
- `f32.nearest`: round to nearest integer, ties to even
- `f32.eq`: compare ordered and equal
- `f32.ne`: compare unordered or unequal
- `f32.lt`: compare ordered and less than
- `f32.le`: compare ordered and less than or equal
- `f32.gt`: compare ordered and greater than
- `f32.ge`: compare ordered and greater than or equal
- `f32.sqrt`: square root
- `f32.min`: minimum (binary operator); if either operand is NaN, returns NaN
- `f32.max`: maximum (binary operator); if either operand is NaN, returns NaN

**Datatype Conversions, truncations, Reinterpretations, Promotions, and Demotions**

- `i32.wrap/i64`: wrap a 64-bit integer to a 32-bit integer
- `i32.trunc_s/f32`: truncate a 32-bit float to a signed 32-bit integer
- `i32.trunc_s/f64`: truncate a 64-bit float to a signed 32-bit integer
- `i32.trunc_u/f32`: truncate a 32-bit float to an unsigned 32-bit integer
- `i32.trunc_u/f64`: truncate a 64-bit float to an unsigned 32-bit integer
- `i32.reinterpret/f32`: reinterpret the bits of a 32-bit float as a 32-bit integer
- `i64.extend_s/i32`: extend a signed 32-bit integer to a 64-bit integer
- `i64.extend_u/i32`: extend an unsigned 32-bit integer to a 64-bit integer
- `i64.trunc_s/f32`: truncate a 32-bit float to a signed 64-bit integer
- `i64.trunc_s/f64`: truncate a 64-bit float to a signed 64-bit integer
- `i64.trunc_u/f32`: truncate a 32-bit float to an unsigned 64-bit integer
- `i64.trunc_u/f64`: truncate a 64-bit float to an unsigned 64-bit integer
- `i64.reinterpret/f64`: reinterpret the bits of a 64-bit float as a 64-bit integer
- `f32.demote/f64`: demote a 64-bit float to a 32-bit float
- `f32.convert_s/i32`: convert a signed 32-bit integer to a 32-bit float
- `f32.convert_s/i64`: convert a signed 64-bit integer to a 32-bit float
- `f32.convert_u/i32`: convert an unsigned 32-bit integer to a 32-bit float
- `f32.convert_u/i64`: convert an unsigned 64-bit integer to a 32-bit float
- `f32.reinterpret/i32`: reinterpret the bits of a 32-bit integer as a 32-bit float
- `f64.promote/f32`: promote a 32-bit float to a 64-bit float
- `f64.convert_s/i32`: convert a signed 32-bit integer to a 64-bit float
- `f64.convert_s/i64`: convert a signed 64-bit integer to a 64-bit float
- `f64.convert_u/i32`: convert an unsigned 32-bit integer to a 64-bit float
- `f64.convert_u/i64`: convert an unsigned 64-bit integer to a 64-bit float
- `f64.reinterpret/i64`: reinterpret the bits of a 64-bit integer as a 64-bit float

