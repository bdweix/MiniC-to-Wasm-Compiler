# Breaking Down MiniC

As stated in the docs the `MiniC` pipeline goes as follows:

```bash
miniC pgm -> Lexer -> Parser -> Typechcker -> Name -> Lift -> Control -> Codegen -> MIPS pgm
```

Let's break this down step by step for the following intentionally simplistic program called `basic.mc`:

```c
int main() {
  int a;
  a = 1 + 2;
  print a;
	return a;
}
```

As you can see, this program has one function (main, required) that simply creates a variable `a` and prints it's value after adding `1 + 2`. The print statement is so we can see the result in the command line, which technically isn't required.

## Makerfile

When we call `make` from our project root it goes into the Makerfile and runs the following code:

```ocaml
SOURCES = util.ml symbol.ml label.ml typ.ml basis.ml env.ml ast.ml \
		  lexer.ml debug.ml parser.ml \
          staticbasis.ml static.ml \
		  name.ml lift.ml copyprop.ml \
          quads.ml control.ml copyprop_quads.ml \
		  mips.ml dynamicbasis.ml codegen.ml \
          compile.ml 

PACKS = unix
INCDIRS = ~/cs3366/lib/
LIBS = code
RESULT = mc
OCAMLMAKEFILE = ~/.opam/default/lib/ocaml-makefile/OCamlMakefile
include $(OCAMLMAKEFILE)
```

This is what ultimately creates our executuble `mc` file that we run for the program. We can see in our sources input we define all of the files, and the program presumably starts in the `compile.ml` file. 

**Question: does this just run through each source and run everything, but compile.mc is the only file with an actual function call so it starts the process then?**

## Compile.ml

### Part 1 - Setup

At the end of this file on Line 134 we can see compile function is called with `let () = compile ()`. Diving into the function line by line we start with:

```ocaml
let n = compilerOptions () in
```

This runs the compilerOptions() function which counts the number of system arguments given to the program and returns the position where the source file should be. If there are two items, then in position 0 is the program invocation and position 1 is the position of the source file. If there are 3 arguments we check whether it's one of the supported parameters (-nocheck or -t). If it is, it appears that we are modifying some global variables (`typeChecking` in the current `compile.ml` file, and `debugLexer` in the `Debug.ml` file). These are both declared as pointers with the `ref` keyword. If there are more than 3 arguments or no match, then the program fails immediately with an argument error.

**Question, why isn't compilerOptions (and other helpers) in the .mli file?**

### Part 2 - System Args

Straightforward getting of the filename using the place we just determined:

```ocaml
let filename = Sys.argv.(n) in
```

### Part 3 - Debugging

Using another reference, we then modify the `debugSetup` variable in `Debug.ml` . This is the `stdout` and presumbly is what creates the resulting `basic.dbg` file.

```ocaml
let dbgOut = Debug.debugSetup filename in
```

### Part 4 - Enviroment Creation

We now need to create the base type environment:

```ocaml
let typeEnv = Env.make Staticbasis.operatorTypes in
```

This runs the function `make` in the `Env.ml` file and passes in `Staticbasis.operatorTypes`. Looking at the paramter first, `operatorTypes` defines all of the required types for operators. The supported operaters are:  +, -, *, /, %, **, <, <=, ==, <>, >=, >, not. These operators all accept two `int`'s and the output is either an `int` or a `bool`, classified as one would assume. The outlier case is the `not` operator, which goes from a bool to a bool. Each operator is then associated with one of the functions `intCrossInt2Int`, `intCrossInt2Bool`, or `bool2Bool`.

Overall this is the paramter than is going to be passed to our Env to create the enviroment. This adheres closely to our defined grammer and typing checking we have layed out.

**Question: where specifically in our grammar is this? Trying to visual the translation from definition to code here…is this all just matching up with the operator definition and then typing checking with injection tags?**

**Personal note: practice the conversions with this again, review problem on the test**

Now inside of the Env make function we have:

```ocaml
  let make values =
  	let folder map (key, value) = add key value map in
  	let keyValuePairs = List.combine Basis.primOps values
  	in
 	List.fold_left folder empty keyValuePairs 
```

This is slightly difficult to understand, but it's seemingly created a key value map between the Basis.primOps and the values we are inputting (remembering that these values are the `Staticbasis.operatorTypes` from above. As we look into the `Basis.ml` file we see a list of the same operations we have defined in Staticbasis.

**Question: why is there the seperation between `Staticbasis.ml` and `Basis.ml`. Is this because `Basis.ml` is going to be applied both for the static and dynamic implementations? To make sure I understand, your comment says that `makeBasis` can be applied to `list implementationsOfPrimitives` to make the dynamic basis. This dynamic basis is basically a type checker/guarentee for the functions that a user may be defining? And the static basis is for the built in operators that we already know?**

### Part 5 - Parsing/Lexing

Back in the `compile.ml`file, we now have line 53 which is:

```ocaml
let ast = parseFile filename in
```

As we did in previous homeworks we are parsing the input file text into an `ast` that we can then manipulate. Out of curiosity, here is the parseFile function:

```ocaml let parseFile fileName =
  let inch = open_in fileName in
  let lexbuf = Lexing.from_channel inch in
  let ast = (if !Debug.debugLexer then
               let _ = Debug.dumpTokens Lexer.token lexbuf
               in
               Ast.Program([])
             else
               Parser.program Lexer.token lexbuf)
  in
  close_in inch ;
  ast 
```

This uses the the `open_in` [function](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Pervasives.html) to open a new file stream and the input file is then run through the Lexer/Parse to make a TokenStream and finally after closing the stream it returns the generate AST. The `Parser.ml` and `Lexar.ml` files are both auto-genearted as discussed in class.

### Part 6 - Debugging File

We then run the line:

```ocaml
let _ = Debug.debugInfo(dbgOut, "The input program is:", ast) in
```

The notation `let _` simply denotes that we know we are not going to use whatever is returned, but we need to assign it some name. I believe this line only matters if Debug is set to false, in which case it will simply write out to the debug file immediately with just the name of the file. 

**Questions:**

**A) it seems when I try to run the command: `./mc -t basic.mc` I'm getting the error `Fatal error: exception Failure("main() not found")`**

**B) Any reason for requiring the system args `-t` and `-nocheck` before the file? Most programs seem to accept optional requirements after the required input**

### Part 7 - Static Type Checking

```ocaml
  (* See if the user wants this program typed-checked. *)
  let _ = (if !typeChecking then
             let msg = (try
                          let _ = Static.typeCheck typeEnv ast
                          in
                          "\nThe program is well-typed.\n"
                        with Static.TypeError s ->
                          let _ = print_string s in
                          let _ = Util.writeln(dbgOut, 0, s)
                          in
                          failwith "Compilation failed.\n")
             in
             (if !Debug.debug then Util.writeln(dbgOut, 0, msg) else ())
           else
             (* No type checking, pretend the program was well-typed. *)
             ()) in
```

**Question: I must be reading this wrong, but it looks like the if statement is only proceeding if "typeChecking" is equal to `false`, whereas if it is equal to `true` then it will jump to else clause which says "No type checking"?** 

Here we are checking if the variable we originally set in Part 1 is false, if it is false then due to the bang operator (not sure the OCaml term). If it's true, it will jump to the else clause which does nothing. Inside of the message variable we are passing the `typeEnv` we built in Part 4 along with the `ast` we made in Part 5 into the `Static.typeCheck` funciton.

The `Static.typeCheck` function is where all of the type checking occurs that we've covered briefly in previous problem sets. This similarily matches up fairly closely with the grammer we have defined and goes recursively through the `ast` after creating a new `env'`.  The result of this is all within a `try/with` statement that will either pass or fail. If it passes then the message "The program is well-typed." will be printed into the debug file (assuming debug is turned on).

### Part 8 - Checking for Main Function

```ocaml
  (* Check for the presence of main function *)
  let Program ps = ast in
  let _ =
    match List.exists (fun (Ast.Procedure Ast.{id; formals}) ->
        Symbol.format id = "main" && formals = []) ps with
    | true -> ()
    | false -> failwith "main() not found"
  in
```

**Question: what does that first line "Program ps" mean, it's changing the type of the ast into a Program? Why can't we just use the ast and change the function to accept an ast, not a program? Additionally, why must the formals be true/what is that representing?"**

We now check if inside the Ast we have a function called `main`. We are mapping the `Program ps` over the lambda function to get out every procedures `ids` which are then checked with the name "main". Assuming it is true, do nothing, otherwise failwith it not being found.

### Part 9 - Naming

Goal of Naming: the goal of the naming phase it provide unique variable names for all of the variables in the code. We do keep original variable names provided by the programmer for easier debugging and readability.

```ocaml
  (* Perform the naming source-to-source transformation.*)
  let named = Name.translate ast in
  let _ = Debug.debugInfo(dbgOut, "After the naming phase:", named) in
```

Now into the core of the compiler, the first step of which is naming. We simply pass the ast into the Naming translation function. Here it goes:

```ocaml
let rec translate (Ast.Program procedures) =
  Ast.Program (List.map translateProcedure procedures)
```

Start by mapping all of the `ast` procedures over the function `translateProcedure`:

```ocaml
and translateProcedure (Ast.Procedure {id; formals; typ; body}) =
  Ast.Procedure {id; formals; typ; body= translateStatement body}
```

This `translateProcedure` function accepts a Procedure and gives us access to it's inner components, which as we can see we are actually returning, except upon the return we are passing the `body` to the function `translateStatement`:

```ocaml
and translateStatement statement =
  match statement with
  | Ast.Block {decls; statements} ->
      Ast.Block {decls; statements= List.map translateStatement statements}
  | Ast.Assign {id; expr} -> Ast.Assign {id; expr= translateTerm expr}
  | Ast.While {expr; statement} ->
      Ast.While
        {expr= translateTerm expr; statement= translateStatement statement}
  | Ast.IfS {expr; thn; els} ->
      Ast.IfS
        { expr= translateTerm expr
        ; thn= translateStatement thn
        ; els= translateStatement els }
  | Ast.Call {rator; rands} ->
      Ast.Call {rator; rands= List.map translateTerm rands}
  | Ast.Print term -> Ast.Print (translateTerm term)
  | Ast.Return term -> Ast.Return (translateTerm term)
```

This function takes the statement and matches it with the potential statement types defined in `Ast.ml`, which are Block, Assign, While, IfS, Call, Print, Return. Each of these statements are then either compromised of a `term` or `statement`, which are applied to the functions `translateTerm` and `translateStatement`, respectively.

**Question: we seem to be calling `translateStatement` within `translateStatement`, but `translateStatement` isn't defined as being recursive?**

`translateTerm`:

```ocaml
and translateTerm term =
  match term with
  | Ast.Id _ as i -> i
  | Ast.Literal _ as w -> w
  | Ast.If {expr; thn; els} ->
      Ast.If
        { expr= translateTerm expr
        ; thn= translateTerm thn
        ; els= translateTerm els }
  | Ast.Or {left; right} ->
      (* FREE CODE Removes OR *)
      let x = Symbol.fresh () in
      let expr = Ast.Id x in
      let bv = {Ast.id= x; typ= Typ.Bool} in
      Ast.Let
        { decl= Ast.ValBind {bv; defn= translateTerm left}
        ; body= Ast.If {expr; thn= expr; els= translateTerm right} }
  | Ast.And {left; right} ->
      (* FREE CODE Removes AND *)
      let x = Symbol.fresh () in
      let expr = Ast.Id x in
      let bv = {Ast.id= x; typ= Typ.Bool} in
      Ast.Let
        { decl= Ast.ValBind {bv; defn= translateTerm left}
        ; body= Ast.If {expr; thn= translateTerm right; els= expr} }
  | Ast.App {rator; rands} ->
      (* build list of fresh variables for existing operands *)
      let decl_var _ = Symbol.fresh () in
      let vars = List.map decl_var rands in
      (* function that wraps ast with
              Let var = value in ast *)
      let createTreeRight var value ast =
        let var_typ = Typ.Int (*********** FIX **************) in
        Ast.Let
          { decl=
              Ast.ValBind
                {bv= {id= var; typ= var_typ}; defn= translateTerm value}
          ; body= ast }
      in
      (* expr_var is the extra Symbol for the result of this Ast.App tree *)
      let expr_var = Symbol.fresh () in
      (* for mapping Symbol.t list "vars" to Ast.term list *)
      let to_term var = Ast.Id var in
      List.fold_right2 createTreeRight vars rands
        (Ast.Let
           { decl=
               Ast.ValBind
                 { bv= {id= expr_var; typ= Typ.Int}
                 ; defn= Ast.App {rator; rands= List.map to_term vars} }
           ; body= to_term expr_var })
  | Ast.Let {decl= Ast.ValBind {bv; defn}; body} ->
      Ast.Let {decl= Ast.ValBind {bv; defn}; body= translateTerm body}
```

We consistently use `Symbol.fresh()` to generate fresh variable names through this code. In each match statement we taking in the Ast and returning back a new Ast with a renamed variable, should a variable exist. As we see with literal and id, we just return as is. Diving into the `Ast.App` match statement, we map all of the `rands` acros the `decl_var` function which generates a new variable name for each, now called `vars`.

 We now define the function `createTreeRight` which takes in a `var` `value` and `ast `(diving in shortly). After that we make a function value called `expr_var` that will return fresh Symbols once called. Now we say that within the coming function, `to_term var` will equal `Ast.Id var`. This is seemingly matching up all of the `Ast.Id` with vars now.

The main working function here is:

```ocaml
List.fold_right2 createTreeRight vars rands
        (Ast.Let
           { decl=
               Ast.ValBind
                 { bv= {id= expr_var; typ= Typ.Int}
                 ; defn= Ast.App {rator; rands= List.map to_term vars} }
           ; body= to_term expr_var })
```

**Questions: A) We didn't want to run this on the entire program because we want to keep some of the original variable names for debugging purposes? B) I'm struggling to understand what is actually happening in the above statement and how `List.fold_right2` words. Docs for my reference: <http://caml.inria.fr/pub/docs/manual-ocaml/libref/List.html>**

Which takes three inputs, `createTreeRight vars rands Ast.let(…)`. This generally appears to be mapping all of the variables inside of a `Let` statement with new variable names for all of their rands.

The outputed `basic.mc` code after the naming phase is now. As we can see, the original variable names are preserved and each variable (rands) inside of the let statement has been named.

```c
int main()
{
  int a;
  a =   let 
      x0 : int = 1
      x1 : int = 2
      x2 : int = +(x0, x1)
  in
    x2
  ;
  print a;
  return
    a
}
```

### Part 10 - Lifting

Goal of Lifting: **unsure, need formal definition. Seems to be a flattening of the functions**

We now passed the `ast` that the naming phase returns into the `lifting` function.

```ocaml
  (* Remove nested let-defintions, another source-to-source translation. *)
  let lifted = Lift.translate named in
  let _ = Debug.debugInfo (dbgOut, "After the lifting phase:", lifted) in
```

Inside the `List.ml` file we have the function called `translate`:

```ocaml
let rec translate (Ast.Program procedures) =
  Ast.Program (List.map translateProcedure procedures)
```

Similar to naming, we get all of the procedures out of the Ast. These are mapped over the `translateProcedure` function:

```ocaml
and translateProcedure (Ast.Procedure {id; formals; typ; body}) =
  Ast.Procedure {id; formals; typ; body = translateStatement body}
```

This function gives us access to the body of the procedures, which we run through the `translateStatement` function:

```ocaml
and translateStatement statement =
  match statement with
  | Block {decls; statements} ->
      Block {decls; statements= List.map translateStatement statements}
  | Assign {id; expr} -> Assign {id; expr= translateTerm expr}
  | While {expr; statement} ->
      While {expr= translateTerm expr; statement= translateStatement statement}
  | IfS {expr; thn; els} ->
      IfS
        { expr= translateTerm expr
        ; thn= translateStatement thn
        ; els= translateStatement els }
  | Call {rator; rands} -> Call {rator; rands= List.map translateTerm rands}
  | Print term -> Print (translateTerm term)
  | Return term -> Return (translateTerm term)
```

The ultimate goal of this function is to reduce the statements down to either statements or/then terms that we can run through the `translateTerm` function:

```ocaml
and translateTerm term =
  match term with
  | Id _ -> term
  | Literal _ -> term
  | App {rator; rands} -> App {rator; rands= List.map translateTerm rands}
  | If {expr; thn; els} ->
      If
        { expr= translateTerm expr
        ; thn= translateTerm thn
        ; els= translateTerm els }
  | And {left; right} -> failwith "lift: cannot have an And node"
  (* And {left = translateTerm left; right = translateTerm right} *)
  | Or {left; right} -> failwith "lift: cannot have an Or node"
  (* OR {left = translateTerm left; right = translateTerm right} *)
  | Let {decl; body} -> (
    match decl with
    | ValBind {bv; defn= Let {decl; body= innerBody}} ->
        translateTerm
          (Let {decl; body= Let {decl= ValBind {bv; defn= innerBody}; body}})
    | ValBind _ -> Let {decl; body= translateTerm body} )

```

The bulk of this phase occure in the final `Let {decl; body} -> …` pat of this function. As we discussed in class this lifting code from this:

```ocaml
let x1 = (let x2 = e2 in e3) in e4
```

To now (after the lifting):

```ocaml
let x2 = e2 in let x1 = e3 in e4
```

Technically the `And` and `Or` parts of the above code should never be hit, otherwise we do have the failwith cases.

After the lifting is done on all of the code, we get the resulting:

```c
int main()
{
  int a;
  a =   let 
      x0 : int = 1
      x1 : int = 2
      x2 : int = +(x0, x1)
  in
    x2
  ;
  print a;
  return
    a
}
```

**Personal Note: this is the same exact code as after the naming phase. The simplicity of the function doesn't highlight the importance of lifting, need to update to something with nested let statements**

**Question: I don't totally understand the need and/or goal of lifting. Are we just using unqiue naming to flatten out nested let statements to make it easier to make into assembly? And we're able to do this because we are controlling the naming so we can ensure that all of the scoping is entact, despite it technically being a bit different than the original implementation?**

### Part 11 - Copy Phase

Goal: to remove  unnescesary 'propogated' copies of code

```ocaml
  let copy = Copyprop.translate lifted in
  let _ = Debug.debugInfo (dbgOut, "After the copyprop phase:", copy) in
```

We now pass the lifted asm into the Copyprop.translate method. It is extremely similar to the previous translate code compositions and I will avoid the duplication of code here. The key part of this phase is the matching statement for `Let` inside of the `translateTerm` function:

```ocaml
  | Ast.Let {decl; body} -> (
    match decl with
    | Ast.ValBind {bv= Ast.({id; typ= _}); defn= Ast.Id keep} ->
        translateTerm (substitute keep id body)
    | Ast.ValBind _ -> Ast.Let {decl; body= translateTerm body} )
```

**Personal Note: understand the difference between the two match statements here**

We are taking any declarations and then rerunning them through the `translateTerm` function but first passing the `keep id body` through the `substitute` function: 

```ocaml
let substitute x (*for*) y term =
  let rec translateTerm term =
    match term with
    | Ast.Id z as i -> (
      match Symbol.compare y z with 0 -> Ast.Id x | _ -> i )
    | Ast.Literal _ as w -> w
    | Ast.If {expr; thn; els} ->
        Ast.If
          { expr= translateTerm expr
          ; thn= translateTerm thn
          ; els= translateTerm els }
    (* The following two cases can't happen because Or and And were eliminated in the naming phase. *)
    | Ast.Or _ -> raise (Failure "Cannot happen.")
    | Ast.And _ -> raise (Failure "Cannot happen.")
    | Ast.App {rator; rands} ->
        Ast.App {rator; rands= List.map translateTerm rands}
    | Ast.Let {decl= Ast.ValBind {bv; defn}; body} ->
        Ast.Let
          { decl= Ast.ValBind {bv; defn= translateTerm defn}
          ; body= translateTerm body }
  in
  translateTerm term
```

The majority of the substitude function is self explanatory, with the key part being the Symbol match statement. This will check if the Ast.Id is the same than the inputted `id` and if not then will return the `keep`, otherwise return itself. As a result we turn the following code:

```ocaml
let x = e1 in let y = x in e2
```

Into the following (after copy prop):

```ocaml
let x = e1 in e2[y:=x]
```

**Question: unsure on some of the implications of differences above and what that means for our language. Also the substitute function seems very redundant as it shares almost all of the code with `translateTerm` function - is it possible to more closely combine them?**

### Part 12 - Control Phase & Quads (more details coming, work in progress)

Goal: this is a translation to the language of quads, which is much closer to assmebly. (We will be converting this to `.wat`)

Taking our output from Part 12, we now run the quads translation:

```ocaml
  let quads = Control.translate copy in
  let _ = Util.writeln (dbgOut, 0, "\nAfter the control phase:") in
  let _ = Quads.dumpInstructionStream quads in
```

After getting the procedures from this new `asm`, we are going to map them over the following function:

```ocaml
and translateProcedure (A.Procedure {id; typ; formals; body}) =
  let entry = Label.fromString (Symbol.format id) in
  let formals = List.map A.(fun bv -> bv.id) formals in
  let code = translateStatement body
  in
  Q.Procedure {entry; formals; code}
```

In the language of Quads Procedure we seem to have the following:

- Entry - each procedures id
- Formals - unsure specifically what this is…we are mapping formals and returning an Ast of something
- Code - run the body of the code through the `translateStatement`

Together these make up a Quads.Procedure, which is defined as the following:

```ocaml
type procedure   = Procedure of { entry   : Label.t
                                ; formals : Symbol.t list
                                ; code    : instruction list
                                }
```

Quads as a langauge is a series of these procedures, each procedure has one label, a list of formals, and an instruction list.

Every statement in our `ast` must match up with one of the following **(examples coming for each)**:

- `Block`
- `Assign`
- `While`
- `Ifs`
- `Call`
- `Print`
- `Return`

These can then be (usually) broken further down into expressions with the following types **(examples coming for each)**:

- `Id`
- `Literal`
- `App` (x3)
- `If`
- `And`
- `Or`
- `Let`

The result of this distilation is simple a series of 

**Question: what exactly are formals?** Can we go through the above types? Let's also break down these types further and how this is implemented inside of the `translateExpression` code:

```ocaml
instructions=
          List.concat
            [ expr.instructions
            ; switch
            ; thn.instructions
            ; passId thn
            ; jump endL
            ; mark switchL
            ; els.instructions
            ; passId els
            ; mark endL ]
```

### Part 13 - CodeGen (more details coming, work in progress)

- It seems `mips.ml` is a series of modules that are then implemented by CodeGen, where most of the transformation happens
- The emit function takes the code stream and writes it out to file

### Our Part 13:

- We will rewrite `codegen.ml` and most likely make a `s-expr.ml` that defines the appropiate outputs to generate S-Expression text

- This S-Expression text will go from `.wat` to `.wasm`

- Better map out all of the components of Quads, match them up better with S-Expressions then

  

