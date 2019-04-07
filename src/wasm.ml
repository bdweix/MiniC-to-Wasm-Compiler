(* file: wasm.mli
   author: Shaan Bijwadia and Branick Weix
   date: March 2, 2019
*)

module Q = Quads
module A = Ast

let fmt = Printf.sprintf

type wType = I32 | I64

type wVar = WVar of {id: Symbol.t; wasmType: wType}

type wInstruction =
  | SetLocal of wVar
  | GetLocal of wVar
  | Add32
  | Mul32
  | Sub32
  | Div32
  | Const32 of int

type wFunction =
  | WFunction of
      { name: Label.t
      ; params: wVar list
      ; locals: wVar list
      ; body: wInstruction list
      ; return: wType }

type wModule = wFunction list

type instructionstream = wFunction list

let opndMatch opnd =
  match opnd with
  | Q.Id id ->
      let var = WVar {id; wasmType= I32} in
      GetLocal var
  | Word {typ; bits} -> Const32 bits

let opLookup op =
  match Symbol.format op with
  | "+" -> Add32
  | "*" -> Mul32
  | "-" -> Sub32
  | "/" -> Div32
  | _ -> failwith "this doesn't match"

let rec translateFormals formals =
  List.map (fun formal -> WVar {id= formal; wasmType= I32}) formals

let rec translateLocal (Q.Instruction {label; op}) =
  match label with
  | Some label -> failwith "Label found...not currently supported"
  | None -> (
    match op with
    | Gets {dst; src} -> (
      match dst with
      | Id id -> [WVar {id; wasmType= I32}]
      | Word _ -> failwith "Cannot assign value to literal" )
    | Ret opnd -> []
    | _ -> failwith "Unsupported operation" )

let rec translateInstruction (Q.Instruction {label; op}) =
  match label with
  | Some label -> failwith "Label found..."
  | None -> (
    match op with
    | Gets {dst; src} -> (
      match src with
      | Operand opnd -> (
        match dst with
        | Id id ->
            let var = WVar {id; wasmType= I32} in
            [opndMatch opnd; SetLocal var]
        | Word _ -> failwith "Cannot assign value to literal" )
      | BinPrimOp {op; opnds= {src1; src2}} -> (
          let wOp = opLookup op in
          let left = opndMatch src1 in
          let right = opndMatch src2 in
          match dst with
          | Id id ->
              let var = WVar {id; wasmType= I32} in
              [left; right; wOp; SetLocal var]
          | Word _ -> failwith "Cannot assign value to literal" )
      | _ -> failwith "" )
    | Ret opnd -> [opndMatch opnd]
    | _ -> failwith "Unsupported operation" )

let rec translateBody instructions =
  match instructions with
  | [] -> []
  | instruction :: instructions ->
      translateInstruction instruction @ translateBody instructions

let rec translateLocals locals =
  match locals with
  | [] -> []
  | local :: locals -> translateLocal local @ translateLocals locals

let rec translateProcedure (Q.Procedure {entry; formals; code}) =
  WFunction
    { name= entry
    ; params= translateFormals formals
    ; locals= translateLocals code
    ; body= translateBody code
    ; return= I32 }

let translate procedures : wModule = List.map translateProcedure procedures

let formatWVar (WVar {id; wasmType}) =
  fmt "(local $%s i32) " (Symbol.format id)

let formatWParam (WVar {id; wasmType}) =
  fmt "(param $%s i32) " (Symbol.format id)

let formatWResult returnType =
  match returnType with I32 -> "(result i32)" | I64 -> "(result i64)"

(* Variables can be used multiple times within a code body,
   we must then remove the duplicates when decided what to
   import to the function  *)
let remove_elt e l =
  let rec go l acc =
    match l with
    | [] -> List.rev acc
    | x :: xs when e = x -> go xs acc
    | x :: xs -> go xs (x :: acc)
  in
  go l []

let remove_duplicates l =
  let rec go l acc =
    match l with
    | [] -> List.rev acc
    | x :: xs -> go (remove_elt x xs) (x :: acc)
  in
  go l []

(* End code, taken from here: https://gist.github.com/23Skidoo/1664038 *)

let formatWCode code =
  match code with
  | SetLocal (WVar {id; wasmType}) ->
      fmt "\t\tset_local $%s\n" (Symbol.format id)
  | GetLocal (WVar {id; wasmType}) ->
      fmt "\t\tget_local $%s\n" (Symbol.format id)
  | Add32 -> "\t\ti32.add\n"
  | Mul32 -> "\t\ti32.mul\n"
  | Sub32 -> "\t\ti32.sub\n"
  | Div32 -> "\t\ti32.div_u\n"
  | Const32 num -> fmt "\t\ti32.const %d\n" num

let formatFunction (WFunction {name; params; locals; body; return}) =
  let fName = "\t(func $" ^ Label.format name in
  let fParams = List.map (fun param -> formatWParam param) params in
  let fVars = List.map (fun var -> formatWVar var) locals in
  let fVars = remove_duplicates fVars in
  let fBody = List.map (fun code -> formatWCode code) body in
  let fResult = formatWResult return in
  let fExports =
    fmt "\t(export \"%s\" (func $%s))" (Label.format name) (Label.format name)
  in
  fName ^ " " ^ fResult ^ " "
  ^ List.fold_left ( ^ ) "" fParams
  ^ List.fold_left ( ^ ) "" fVars
  ^ "\n"
  ^ List.fold_left ( ^ ) "" fBody
  ^ "\t)\n" ^ fExports ^ "\n)\n"

let formatModule (WFunction {name; params; locals; body; return}) = "(module\n"

let dumpInstructionStream wModules =
  let print = output_string !Debug.dbgout in
  let _ = List.iter (fun wasmMod -> print (formatModule wasmMod)) wModules in
  List.iter (fun wFunction -> print (formatFunction wFunction)) wModules
