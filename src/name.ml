(* file: name.ml
 * author: Bob Muller
 * date: January 5, 2009
 * revised: March, 2017
 *
 * The Name module implements a source-to-source transformation for
 * naming the values of subterms in miniC. In addition to naming values,
 * the Name module translates "or" and "and" forms into special-cases
 * of the conditional form nested within a let-form.
 *)

open Ast

let rec translate (Ast.Program procedures)  =
  Ast.Program (List.map translateProcedure procedures)
and
  translateProcedure (Ast.Procedure {id; formals; typ; body}) =
  Ast.Procedure { id
                ; formals
                ; typ
                ; body = translateStatement body
                }
and
  translateStatement statement =
    match statement with
    | Ast.Block {decls; statements} ->
      Ast.Block { decls
                ; statements = List.map translateStatement statements
                }
    | Ast.Assign {id; expr} ->
      Ast.Assign { id
                 ; expr = translateTerm expr
                 }
    | Ast.While {expr; statement} ->
      Ast.While { expr = translateTerm expr
                ; statement = translateStatement statement
                }
    | Ast.IfS {expr; thn; els} ->
      Ast.IfS { expr = translateTerm expr
              ; thn  = translateStatement thn
              ; els  = translateStatement els
              }

    | Ast.Call {rator; rands} ->
      Ast.Call { rator
               ; rands = List.map translateTerm rands
               }
    | Ast.Print term ->
      Ast.Print (translateTerm term)
    | Ast.Return term ->
      Ast.Return (translateTerm term)
and
  translateTerm term =
  match term with
  | Ast.Id _ as i -> i
  | Ast.Literal _ as w -> w
  | Ast.If {expr; thn; els} ->
    Ast.If { expr = translateTerm expr
           ; thn = translateTerm thn
           ; els = translateTerm els
           }
  | Ast.Or {left; right} ->         (* FREE CODE Removes OR *)
    let x = Symbol.fresh() in
    let expr = Ast.Id x in
    let bv = {Ast.id = x; typ = Typ.Bool}
    in
    Ast.Let { decl = Ast.ValBind { bv
                                 ; defn = translateTerm left
                                 }
            ; body = Ast.If { expr
                            ; thn = expr
                            ; els = translateTerm right
                            }
            }

  | Ast.And {left; right} ->      (* FREE CODE Removes AND *)
    let x = Symbol.fresh() in
    let expr = Ast.Id x in
    let bv = {Ast.id = x; typ = Typ.Bool}
    in
    Ast.Let { decl = Ast.ValBind { bv
                                 ; defn = translateTerm left
                                 }
            ; body = Ast.If { expr
                            ; thn = translateTerm right
                            ; els = expr
                            }
            }

  | Ast.App {rator; rands} ->
    (* build list of fresh variables for existing operands *)
    let decl_var _ = Symbol.fresh() in
    let vars = List.map decl_var rands in

    (* function that wraps ast with
              Let var = value in ast *)
    let createTreeRight var value ast =
      let var_typ = Typ.Int (*********** FIX **************)
      in
      Ast.Let { decl = Ast.ValBind { bv = { id = var
                                          ; typ = var_typ
                                          }
                                   ; defn = translateTerm value
                                   }
              ; body = ast
              } in

    (* expr_var is the extra Symbol for the result of this Ast.App tree *)
    let expr_var = Symbol.fresh() in
    (* for mapping Symbol.t list "vars" to Ast.term list *)
    let to_term var = Ast.Id var
    in
    List.fold_right2 createTreeRight
      vars
      rands
      (Ast.Let { decl =
                   Ast.ValBind { bv = { id = expr_var
                                      ; typ = Typ.Int
                                      }
                               ; defn = Ast.App { rator
                                                ; rands = List.map to_term vars
                                                }
                               }
               ; body = to_term expr_var
               })

  | Ast.Let { decl = Ast.ValBind {bv; defn}; body} ->
    Ast.Let { decl = Ast.ValBind {bv; defn}
            ; body = translateTerm body
            }
