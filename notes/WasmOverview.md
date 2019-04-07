# Mini-C to Web Assmebly (Wasm) Overview

​	We are defining below a subset of the Web Assmebly (`.wasm`) language. Unlike other languages, Web Assmebly is a compilation target that developers can compile code from multiple languages into. For the purposes of this document, we are specifying a limited version of Web Assembly that works as a compilation target of Mini-C. Although it is a compilation target, Web Assembly has a human-readable text format (`.wat`) that makes it possible to both read and write directly in Web Assembly. This format is in the language of S-Expressions.

​	Our implementation will compile Mini-C files into Web Assembly `.wat` files that can be run directly on the browser, relying in part upon the existing Mini-C compilation chain. An example of this pipeline is displayed below:

Mini-C is run with the following `sample.mc` program:

```c
int main() {
  int a;
  int b;
  a = 1;
  b = 2;
  return a + b;
}
```

Mini-C will generate an output, `Quads` that is displayed below. This is post naming, lifting, and control phases. Note: the duplication of variable names is due to the Mini-C implementation that initializes variables to 0.

```asm
main:	()
	a = 0
	b = 0
	a = 1
	b = 2
	x2 = a + b
	x3 = x2
	return x3
```

Our compiler will intake the `Quads` language and export the following Web Assmebly `.wat` file:

```c
(module
	(func $main (result i32) (local $a i32) (local $b i32) (local $x2 i32) (local $x3 i32) 
		i32.const 0
		set_local $a
		i32.const 0
		set_local $b
		i32.const 1
		set_local $a
		i32.const 2
		set_local $b
		get_local $a
		get_local $b
		i32.add
		set_local $x2
		get_local $x2
		set_local $x3
		get_local $x3
	)
	(export "main" (func $main))
)
```

## Grammar

Main Web Assembly grammar can be found here (quite similar!): <https://webassembly.github.io/spec/core/syntax/index.html>

List of Web Assmebly instructions can be found here: <https://webassembly.github.io/spec/core/appendix/index-instructions.html>

Although Web Assembly is significantly more complex than the grammar above, this is a reduced version that is applicable to the outputs of `Quads`:

```latex
valType 	::= i32 | i64
i32 		::= digit | digit i32
digit 		::= 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
name		::= $string | i32 | ϵ

module 		::= ( node ) | ( node ) module
node 		::= ( func ) | ( export )
func		::= name result params locals body
result		::= ( result valType )
params		::= ( param ) | ( param ) params | ϵ
param		::= ( param name valType )
locals		::= ( local ) | ( local ) locals | ϵ
local		::= ( local name valType )
body		::= { instructions }

instructions ::= 
				| valType.const i32
				| valType.op
				| set_local name
				| get_local name

op			::=
				| valType.add
				| valType.sub
				| valType.mul
				| valType.div_u

exports		::= (export "name" (func name))
```
Note: there are a few errors to be corrected in the grammar. A name can be any string pre-pended by a `$` (dollar sign). Exports require the name without a dollar sign in quotation marks. 

## S-Expressions ([source](https://developer.mozilla.org/en-US/docs/WebAssembly/Understanding_the_text_format))

S-expressions are a set of trees, and each node in the tree goes inside of a pair of parentheses. These paratheneses make the underlying tree structure extremely clear. Let's take a look at some basic `.wat` code:

```wasm
(module (memory 1) (func))
```

Overall the structure goes such that first item inside of the parenthesis tells you what type of node it is, and after that there is a space-seperated list of attribtues or child nodes. This code represents a tree with a root node "module" and two child nodes, "memory" and "func". The "memory" node has an attribute "1". A single Web Assmebly file will have one module.

## Types

Web Assembly currently has four types:

- `i32` - 32 bit integer
- `i64` - 64 bit integer
- `f32` - 32 bit float
- `f64` - 64 bit float

As you can see in the grammar, we are only supporting the `i32` type.

## Node Types

- **`module` - the main node**
- **`func` - function declaration**
- **`export` - export declaration**
- `import` - import declaration
- `global` - globals, can be immutable or mutable
- `memory` - used for storing more comlex data types
- `table` + `elem` - declaring and using the indirect function table
- `type` - function signature declarations, I believe this is used by indirect function calls to asset type

Our compiler is only supporting the first three, bolded node types.

## Stack Machine

Original source for code and examples: <https://rsms.me/wasm-intro#import_section>

Web Assembly execution runs a stack machine where ever instruction pushes and/or pops a certain number of values (of the above types) to and from the stack. The beginning of every function starts with an empty stack. At the end of the function, there should only be one item on the stack, and that item should match the return type. If there is no return type, then the stack must be empty. The code should not compile if this isn't true.

```asm
get_local 0  // push parameter 0 on stack (our dividend)
i64.const 2  // push constant int64 "2" on stack (our divisor)
i64.div_u    // unsigned division pushes result onto stack
end          // ends function, resulting in one i64 (top of stack)
```

## Functions

Most of the code within a Web Assembly module is grouped into functions. Functions follow the following format:

```wasm
func ::= name result params locals body

(func $main (result i32) (param $p1 i32) (local $v1 i32) 
	{instructions}
)
```

- `name` - optional, sets the name of the function
- `result` - sets the return type, should be last item on stack
- `params` - sets the params and their names, name are optional
- `locals` - sets the local variables and their names, name are option
- `instructions` - list of instructions that will be run, see Stack Machine above

## Instructions

As we see in our grammar, we only have a handful of code instructions. Here are their stack implications:

```asm
i32.const 1			#Pushes an integer "1" onto the stack

i32.add				#Pops two items off stack and pushes result
i32.sub				# see above
i32.div_u			# see above, this is for unsigned division
i32.mul				# see above

set_local $name		#Pop top of stack and store into index/name var
get_local $name		#Push local var onto stack

```

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
    i32.add
   )
 )
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

## Running .wat Files

One of the easiest ways to run Web Assmebly `.wat` files is directly in your browser in a program called [Web Assmebly Studio](https://webassembly.studio/). Start by creating a new "Empty Wat Project". Your set up should look like this:

![studio1](/source_imgs/studio1.png)

On our left hand side you can click between the different files. They start with a very basic add funciton. To run this function, click the "Build & Run" button in the top toolbar. As we discussed earlier, we must export the functions so they are callable via Javascript. If you click into the `main.js` file you will see the following Javascript:

```javascript
fetch('../out/main.wasm').then(response =>
  response.arrayBuffer()
).then(bytes => WebAssembly.instantiate(bytes)).then(results => {
  instance = results.instance;
  document.getElementById("container").textContent = instance.exports.add(1,1);
}).catch(console.error);
```

We can see on Line 3 that we are calling WebAssmebly and then on Line 5 we say `instance.exports.add(1,1);`. Because we exported `(export "add" (func $add))` we now have the `add` function available. In the Javascript we are passing it two parameters, which are also specified in the `main.wat` code.



