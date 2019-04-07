(* file: wasm.mli
   author: Shaan Bijwadia and Branick Weix
   date: March 2, 2019
*)

type wType = I32 | I64

(* type wVar = {id: Symbol.t; wasmType: wType} *)
type wVar = WVar of {id: Symbol.t; wasmType: wType}

type wInstruction =
  | SetLocal of wVar
  | GetLocal of wVar
  | Add32
  | Mul32
  | Sub32
  | Div32
  | Const32 of int

(* (func $name (param $name i32) (local $name i32) (return i32) ) *)
type wFunction =
  | WFunction of
      { name: Label.t
      ; params: wVar list
      ; locals: wVar list
      ; body: wInstruction list
      ; return: wType }

type wModule = wFunction list

val translate : Quads.instructionstream -> wModule

val formatFunction : wFunction -> string

type instructionstream = wFunction list

val dumpInstructionStream : instructionstream -> unit
