(* file: codegen.ml
 * author: Bob Muller
 * revised: March/April 2017, by Art Zhu
 * revised: February, 2019 by Bob Muller
 *
 * This file contains code for inserting control in the compilation
 * of mini-C. This code translates from the language of quads to
 * MIPS assembly code. The calling protocols is as follows:
 *
 * Register Conventions:
 *  t0 - t9 : caller-save regs
 *  s0 - s7 : callee-save regs
 *  fp : frame pointer
 *  ra : return address
 *  a0 - a3 : argument registers for first 4 arguments
 *  v0 - v1 : return values
 *
 * 1. Stack Frame Layout:

       +----------------------------+
       |      Caller-Save Regs      |                 higher addresses
       +----------------------------+
       |       Value of Arg 1       |
       +--           :            --+
       |             :              |
       +--                        --+
       |       Value of Arg n       |
       +----------------------------+
       |   Caller's Return Address  |
       +----------------------------+
       |   Caller's Frame Pointer   | <-- fp
       +----------------------------+
       |      Local Variable 1      |
       +--            :           --+
       |              :             |
       +--                        --+
       |      Local Variable k      |
       +----------------------------+
       |   Callee Save Registers    |                 lower addresses
       +----------------------------+
                                      <-- sp
 *)

(* Some abbreviations for frequently used modules. *)

module Q = Quads
module Opn = Mips.Operation
module Opnd = Mips.Operand
module I = Mips.Instruction
module CS = Mips.Codestream

let makeLabel = Label.fromString
let fIL = CS.fromInstructionList
let toIn = I.toInstruction

let offsetsOf cgenv =
  let bindings = Env.bindings cgenv in
  let rec loop bindings =
    match bindings with
    | [] -> []
    | (key, Dynamicbasis.Offset n) :: bindings ->
      (key, n) :: loop bindings
    | _ :: bindings -> loop bindings
  in
  loop bindings

(* The dynamicBasis is an environment mapping built-in operators
   to code generator functions. This environment will also be used
   to store storage offsets for identifiers, including formal
   parameters as well as local and temporary variables.
*)
let dynamicBasis = Env.make Dynamicbasis.codeGenerators

(* Conventions
 *
 *   This section binds names to enforce some code generator conventions.
 *
 * Word size is 4 bytes.
 *)
let wordSize = 4

(* Conventions for system calls on MARS. These codes go in $v0.
 *)
let syscallPrintInt = 1
let syscallReturn = 10
let syscallReturnWithVal = 17

(* accumulator register used to accumulate results.
 *)
let accumulator =  Opnd.Value 0
let operand1Reg =  Opnd.Temp 1
let operand2Reg =  Opnd.Temp 2

(* dataBaseAddr is the register that is used to to hold the base
 * address of the data area. All variables accessed via indirect
 * addressing off of this register.
 *)
let dataBaseAddr = Opnd.Temp 1

(* targetLabelReg is the number of the register that is used to
 * hold the destination of a branch.
 *)
let targetLabelReg = Opnd.Temp 2

let push reg maybeLabel comment =
  let i1 = toIn (maybeLabel,
                 Opn.Addi { rd = Opnd.Reg Opnd.StackPointer
                          ; rs = Opnd.Reg Opnd.StackPointer
                          ; const16 = Opnd.Const16 (-4)
                          },
			           Some ("push " ^ comment)) in
  let i2 = toIn (None,
                 Opn.Sw { rs = reg
                        ; rt = Opnd.Indirect { offset = Some 0
                                             ; reg = Opnd.StackPointer
                                             }
                        },
                 None)
  in
  fIL [i1; i2]

let pushRA maybeLabel = push (Opnd.Reg Opnd.ReturnAddress) maybeLabel ""

let pop dstreg maybeLabel comment =
  let i1 = toIn (None,
                 Opn.Lw { rd = dstreg
                        ; rs = Opnd.Indirect { offset = Some 0
                                             ; reg = Opnd.StackPointer
                                             }
                        },
			           Some ("pop " ^ comment)) in
  let i2 = toIn (None,
                 Opn.Addi { rd = Opnd.Reg Opnd.StackPointer
                          ; rs = Opnd.Reg Opnd.StackPointer
                          ; const16 = Opnd.Const16 4
                          },
                 None)
  in
  fIL [i1; i2]

let calleePrologue name nLocals =
  let pushFP = push (Opnd.Reg Opnd.FramePointer) (Some name) "fp" in
  let sp2fp = toIn (None,
                    Opn.Move { rd = Opnd.Reg Opnd.FramePointer
                             ; rs = Opnd.Reg Opnd.StackPointer
                             },
                    Some "fp <- sp") in
  let allocate =
    toIn (None,
          Opn.Addi { rd = Opnd.Reg Opnd.StackPointer
                   ; rs = Opnd.Reg Opnd.StackPointer
                   ; const16 = Opnd.Const16 (-wordSize * nLocals)
                   },
          Some "allocate locals")
  in
  CS.concat pushFP (fIL [sp2fp; allocate])

let calleeEpilogue entry =
  let restoreSP = toIn (None,
                        Opn.Move { rd = Opnd.Reg Opnd.StackPointer
                                 ; rs = Opnd.Reg Opnd.FramePointer
                                 },
                        None) in
  let restoreFP = pop (Opnd.Reg Opnd.FramePointer) None "restore fp" in
  let return =
    match entry = (Label.fromString "main") with
    | true  -> [ toIn (None,
                       Opn.Li { rd = Opnd.Reg (Opnd.Value 0)
                              ; imm32 = Opnd.Const32 syscallReturnWithVal
                              },
                       Some "$v0 gets exit code for syscall")
               ; toIn (None, Opn.Syscall, Some "Exit here")
               ]
    | false -> [ toIn(None,
                      Opn.Jr (Opnd.Reg Opnd.ReturnAddress),
                      Some "return")
               ]
  in
  CS.concat (fIL [restoreSP]) (CS.concat restoreFP (fIL return))

(* makeEnv constructs an environment for a given procedure. The
 * environment maps each identifier to its storage offset as suggested
 * by the picture at the top of the file. In particular, all variables
 * are accessed via indirect addressing using the frame pointer (fp) as
 * the base address. Formal parameters will have positive offsets while
 * local variables will have negative offsets.
 *)
let makeEnv formals instructions =
  let rec buildEnv idx inc syms env =
    match syms with
    | [] -> env
    | sym :: rest ->
      let dbidx = Dynamicbasis.Offset idx
      in
      buildEnv (idx+inc) inc rest (Env.add sym dbidx env) in
  let localVars =
    let buildLocalVars (varList : Symbol.t list) instruction =
      match instruction with
      | Q.Instruction {label; op = Q.Gets {dst = Q.Id i; src}} ->
        (match (List.mem i formals) with
         | true  -> varList
         | false -> varList @ [i])
      | _ -> varList
    in
    List.fold_left buildLocalVars [] instructions in
  let formals_env = buildEnv 2 1 (List.rev formals) dynamicBasis
  in
  (List.length localVars, buildEnv (-1) (-1) localVars formals_env)

let lookupOffset name env =
  match Env.find name env with
  | Dynamicbasis.Offset i -> i
  | _ -> failwith "lookupOffset: something is wrong with codegen env"

let lookupCodeGenerator name env =
  match Env.find name env with
  | Dynamicbasis.CodeGenerator cg -> cg
  | _ -> failwith "lookupCodeGenerator: something is wrong with codegen env"

let loadRegister reg env opnd maybeLabel =
  match opnd with
  | Q.Id name ->
    let index = lookupOffset name env in
    let offset = wordSize * index
    in
    toIn(maybeLabel,
         Opn.Lw { rd = Opnd.Reg reg
                ; rs = Opnd.Indirect { offset = Some offset
                                     ; reg = Opnd.FramePointer
                                     }
                },
         None)

  | Q.Word {typ; bits} ->
    toIn(maybeLabel,
         Opn.Li { rd = Opnd.Reg reg
                ; imm32 = Opnd.Const32 bits
                },
         None)

let storeRegister reg env opnd maybeLabel =
  match opnd with
  | Q.Id name ->
    let index = lookupOffset name env in
    let offset = wordSize * index
    in
    fIL [ toIn(maybeLabel,
               Opn.Sw { rs = Opnd.Reg reg
                      ; rt = Opnd.Indirect { offset = Some offset
                                           ; reg = Opnd.FramePointer
                                           }
                      },
               None)
        ]
  | _ -> failwith "storeRegister: bad store operand"

let translateOperand = loadRegister

let callerPrologue opnds maybeLabel env =
  let pushArgs =
    let pushArg maybeLabel opnd =
      CS.concat
        (fIL [loadRegister operand1Reg env opnd maybeLabel])
        (push (Opnd.Reg operand1Reg) None "")
    in
    match opnds with
    | [] -> pushRA maybeLabel
    | opnd :: opnds ->
      CS.concat
        (let cs1 = pushArg maybeLabel opnd
         in
         List.fold_left CS.concat cs1 (List.map (pushArg None) opnds))
        (pushRA None)
  in
  pushArgs

let callerEpilogue opnds =
  CS.concat
    (pop (Opnd.Reg Opnd.ReturnAddress) None "ra")
    (fIL [
        toIn (
          None,
          Opn.Addi { rd = Opnd.Reg Opnd.StackPointer
                   ; rs = Opnd.Reg Opnd.StackPointer
                   ; const16 = Opnd.Const16 (wordSize * (List.length opnds))
                   },
          Some "deallocate args")
      ])

let translateRHS env rhs maybeLabel reg =
  match rhs with
  | Q.Operand op ->
    fIL [translateOperand reg env op maybeLabel]
  | Q.BinPrimOp {op; opnds = Q.{src1; src2}} -> (* ( *)
    let loadOpndsCS =
      fIL [ translateOperand operand1Reg env src1 maybeLabel
          ; translateOperand operand2Reg env src2 maybeLabel
          ] in
    let codeGenerator = lookupCodeGenerator op env in
    let ac = Opnd.Reg reg in
    let t1 = Opnd.Reg operand1Reg in
    let t2 = Opnd.Reg operand2Reg
    in
    CS.concat loadOpndsCS (codeGenerator [ac; t1; t2])

  | Q.UnPrimOp  {op; opnd} ->
    let loadOpndCS =
      fIL [translateOperand operand1Reg env opnd maybeLabel] in
    let codeGenerator = lookupCodeGenerator op env in
    let ac = Opnd.Reg reg in
    let t1 = Opnd.Reg operand1Reg
    in
    CS.concat loadOpndCS (codeGenerator [ac; t1])

  | Q.FunCall {label; opnds} ->
    let prologue = callerPrologue opnds maybeLabel env in
    let jumpAndLink = fIL [toIn (None, Opn.Jal (Opnd.Label label), None)] in
    let epilogue = callerEpilogue opnds
    in
    CS.concat prologue (CS.concat jumpAndLink epilogue)

let translateOperation env opn maybeLabel procedure_label =
  match opn with
  | Q.Gets {dst; src} ->
      let rhsCS   = translateRHS env src maybeLabel accumulator in
      let storeCS = storeRegister accumulator env dst None
      in
      CS.concat rhsCS storeCS
    (* Q.Gets *)

  | Q.Jmp lbl -> fIL [toIn(maybeLabel, Opn.J (Opnd.Label lbl), None)]

  | Q.JmpZero {cond; dest} ->
    let conditionCS = translateRHS env cond maybeLabel accumulator in
    CS.concat
      conditionCS
      (fIL [toIn (maybeLabel,
                  Opn.Beqz { rs = Opnd.Reg accumulator
                           ; off18 = Opnd.Label dest
                           },
                  None)])
  | Q.Call {label; opnds} ->
    let prologue = callerPrologue opnds maybeLabel env in
    let jumpAndLink = fIL [toIn (None, Opn.Jal (Opnd.Label label), None)] in
    let epilogue = callerEpilogue opnds
    in
    CS.concat prologue (CS.concat jumpAndLink epilogue)

  | Q.Print rhs ->
    CS.concat
      (translateRHS env rhs None (Opnd.Arg 0))
      (fIL [ toIn (None,
                   Opn.Li { rd = Opnd.Reg(Opnd.Value 0)
                          ; imm32 = Opnd.Const32 syscallPrintInt
                          },
                   Some "$v0 gets print_int code for syscall")
           ; toIn (None, Opn.Syscall, Some "print")
           ]) (* IMP *)

  | Q.Ret opnd ->
    let reg =
      if procedure_label = (Label.fromString "main") then (Opnd.Arg 0)
      else (Opnd.Value 0) in
    let set_v0_instr = translateOperand reg env opnd maybeLabel
    in
    fIL [set_v0_instr]

  | Q.Noop -> fIL [toIn(maybeLabel, Opn.Nop, None)]

let translateInstruction env procedure_label
    (Q.Instruction{label; op} : Q.instruction) : CS.t =
  translateOperation env op label procedure_label

let translateProcedure (Q.Procedure {entry; formals; code}) =
  let (nLocals, env) = makeEnv formals code in
  let prologue = calleePrologue entry nLocals in (* (nLocals + 1) in *)
  let instructions = List.map (translateInstruction env entry) code in
  let body = List.fold_left CS.concat CS.empty instructions in
  let epilogue = calleeEpilogue entry
  in
  Debug.dumpCGEnv entry (offsetsOf env) ;
  (entry, CS.concat prologue (CS.concat body epilogue))

(* The main function. *)
let translate procedures =
  let main_first_concat cs1 (tag, cs2) =
    match tag = Label.fromString "main" with
    | true  -> CS.concat cs2 cs1
    | false -> CS.concat cs1 cs2
  in
  CS.concat
    (fIL [ toIn (None, Mips.Operation.Data, None)
         ; toIn (None, Mips.Operation.Text, None)
         ])
    (List.fold_left
       main_first_concat
       CS.empty (List.map translateProcedure procedures))
