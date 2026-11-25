(* Gable modification notice. This file was changed by Gable.ai:
     2026-11-19  Preserve JavaScript destructuring defaults in the generic AST
     2026-11-24  Evaluate destructuring targets before defaults; bind catch defaults
   See GABLE-MODIFICATIONS.md. End of Gable modification notice. *)
open Common
open Fpath_.Operators

let t = Testo.create

(*****************************************************************************)
(* Unit tests *)
(*****************************************************************************)

let timeout_secs = 1.0

(* ran from the root of the semgrep repository *)
let tests_path = "tests"

let target_before_default_test () : Testo.t =
  t "JS destructuring evaluates an assignment target before its default"
    (fun () ->
      let module G = AST_generic in
      let tok = Tok.unsafe_fake_tok "=" in
      let call (name : string) : G.expr =
        G.Call
          ( G.N (G.Id ((name, tok), G.empty_id_info ())) |> G.e,
            Tok.unsafe_fake_bracket [] )
        |> G.e
      in
      let with_default (target : G.expr) : G.expr =
        G.Assign (target, tok, call "fallback") |> G.e
      in
      let record (value : G.expr) : G.expr =
        let field =
          G.F
            (G.DefStmt
               ( G.basic_entity ("a", tok),
                 G.FieldDefColon
                   { vinit = Some value; vtype = None; vtok = None } )
            |> G.s)
        in
        G.Record (tok, [ field ], tok) |> G.e
      in
      let array (value : G.expr) : G.expr =
        G.Container (G.Array, (tok, [ value ], tok)) |> G.e
      in
      let member_target =
        G.ArrayAccess (call "target", Tok.unsafe_fake_bracket (call "key"))
        |> G.e
      in
      let variable_target =
        G.N (G.Id (("value", tok), G.empty_id_info ())) |> G.e
      in
      (* Calls by callee, and "read" for a projection of the destructured
       * value, in the order of the lowered statements, each with whether it
       * is inside a conditional branch. *)
      let event_of_instr (instr : IL.instr) : string option =
        match instr.IL.i with
        | IL.Call
            (_, { e = IL.Fetch { base = IL.Var callee; rev_offset = [] }; _ }, _)
          ->
            Some (fst callee.ident)
        | IL.Assign (_, { e = IL.Fetch { rev_offset = _ :: _; _ }; _ }) ->
            Some "read"
        | _ -> None
      in
      let rec events (conditional : bool) (stmts : IL.stmt list) :
          (string * bool) list =
        List.concat_map
          (fun (stmt : IL.stmt) ->
            match stmt.IL.s with
            | IL.Instr instr ->
                event_of_instr instr |> Option.to_list
                |> List.map (fun (event : string) -> (event, conditional))
            | IL.If (_, _, yes, no) -> events true (yes @ no)
            | _ -> [])
          stmts
      in
      [
        ( "object member target",
          record (with_default member_target),
          [ "input"; "target"; "key"; "read"; "fallback" ] );
        ( "array member target",
          array (with_default member_target),
          [ "input"; "target"; "key"; "read"; "fallback" ] );
        ( "object variable target",
          record (with_default variable_target),
          [ "input"; "read"; "fallback" ] );
        ( "array variable target",
          array (with_default variable_target),
          [ "input"; "read"; "fallback" ] );
      ]
      |> List.iter
           (fun ((label : string), (lhs : G.expr), (expected : string list)) ->
             let lowered =
               AST_to_IL.stmt Lang.Js
                 (G.exprstmt (G.Assign (lhs, tok, call "input") |> G.e))
             in
             let lowered_events = events false lowered in
             Alcotest.(check (list string))
               (label ^ ": evaluation order")
               expected
               (List.map fst lowered_events);
             Alcotest.(check (list string))
               (label ^ ": only the default is conditional")
               [ "fallback" ]
               (List.filter_map
                  (fun ((event : string), (conditional : bool)) ->
                    if conditional then Some event else None)
                  lowered_events)))

let pattern_default_test (parse_program : Fpath.t -> AST_generic.program) () :
    Testo.t =
  t "JS pattern defaults evaluate only the undefined branch" (fun () ->
      let module G = AST_generic in
      let tok = Tok.unsafe_fake_tok "=" in
      let call (name : string) (args : G.expr list) : G.expr =
        G.Call
          ( G.N (G.Id ((name, tok), G.empty_id_info ())) |> G.e,
            Tok.unsafe_fake_bracket
              (List.map (fun (e : G.expr) -> G.Arg e) args) )
        |> G.e
      in
      let binding = G.PatId (("value", tok), G.empty_id_info ()) in
      let parsed =
        parse_program
          (Fpath.v
             (tests_path ^ "/naming/js/destructuring_default_initializer.ts"))
      in
      let parameter =
        match parsed with
        | [ { G.s = G.DefStmt (_, G.FuncDef fdef); _ } ] -> (
            match Tok.unbracket fdef.G.fparams with
            | [ G.ParamPattern (pat, _) ] -> pat
            | _ -> Alcotest.fail "expected the destructuring formal")
        | _ -> Alcotest.fail "expected one function"
      in
      let bindings =
        Visit_pattern_ids.visit (G.P parameter)
        |> List.map (fun (((name, _), _) : G.ident * G.id_info) -> name)
      in
      Alcotest.(check (list string))
        "initializer bindings belong to their own scope" [ "callback" ] bindings;
      let default = call "fallback" [ call "effect" [] ] in
      let pat = G.PatDefault (binding, tok, default) in
      let stmt = G.exprstmt (G.LetPattern (pat, call "input" []) |> G.e) in
      let lowered = AST_to_IL.stmt Lang.Js stmt in
      let calls (stmts : IL.stmt list) : string list =
        let names = ref [] in
        let visitor =
          object
            inherit [_] IL.iter as super

            method! visit_instr () (instr : IL.instr) =
              (match instr.IL.i with
              | IL.Call
                  ( _,
                    { e = IL.Fetch { base = IL.Var name; rev_offset = [] }; _ },
                    _ ) ->
                  names := fst name.ident :: !names
              | _ -> ());
              super#visit_instr () instr
          end
        in
        List.iter (visitor#visit_stmt ()) stmts;
        List.rev !names
      in
      let branches =
        List.filter_map
          (fun (stmt : IL.stmt) ->
            match stmt.IL.s with
            | IL.If (_, condition, yes, no) -> Some (condition, yes, no)
            | _ -> None)
          lowered
      in
      (match branches with
      | [
       ( {
           e =
             IL.Operator
               ( (G.PhysEq, _),
                 [
                   IL.Unnamed { e = IL.Fetch selected; _ };
                   IL.Unnamed { e = IL.Literal (G.Undefined _); _ };
                 ] );
           _;
         },
         yes,
         [] );
      ] ->
          Alcotest.(check (list string))
            "default effects stay conditional" [ "effect"; "fallback" ]
            (calls yes);
          let reads_selected (stmt : IL.stmt) : bool =
            match stmt.IL.s with
            | IL.Instr
                {
                  i =
                    IL.Assign
                      ( { base = IL.Var name; rev_offset = [] },
                        { e = IL.Fetch from; _ } );
                  _;
                }
              when String.equal (fst name.ident) "value" ->
                let as_exp (lval : IL.lval) : IL.exp =
                  { IL.e = IL.Fetch lval; eorig = IL.NoOrig }
                in
                IL_helpers.equal_exp (as_exp selected) (as_exp from)
            | _ -> false
          in
          Alcotest.(check int)
            "bind selected value once" 1
            (List.length (List.filter reads_selected lowered));
          let rec binding_after_branch (stmts : IL.stmt list) : bool =
            match stmts with
            | [] -> false
            | { IL.s = IL.If _ } :: rest -> List.exists reads_selected rest
            | _ :: rest -> binding_after_branch rest
          in
          Alcotest.(check bool)
            "bind after default selection" true
            (binding_after_branch lowered)
      | _ -> Alcotest.fail "expected a strict undefined-only fallback branch");
      Alcotest.(check (list string))
        "input and default calls occur once in order"
        [ "input"; "effect"; "fallback" ]
        (calls lowered);
      let id (name : string) : G.expr =
        G.N (G.Id ((name, tok), G.empty_id_info ())) |> G.e
      in
      let field (key : string) (value : G.expr) : G.field =
        G.F
          (G.DefStmt
             ( G.basic_entity (key, tok),
               G.FieldDefColon { vinit = Some value; vtype = None; vtok = None }
             )
          |> G.s)
      in
      let record (fields : G.field list) : G.expr =
        G.Record (tok, fields, tok) |> G.e
      in
      let with_default (binding : G.expr) : G.expr =
        G.Assign (binding, tok, default) |> G.e
      in
      let cases =
        [
          ( "array",
            G.Container (G.Array, (tok, [ with_default (id "value") ], tok))
            |> G.e,
            [],
            [ [ "effect"; "fallback" ] ] );
          ( "alias",
            record [ field "original" (with_default (id "value")) ],
            [ "original" ],
            [ [ "effect"; "fallback" ] ] );
          ( "shorthand",
            record [ G.F (G.exprstmt (G.LetPattern (binding, default) |> G.e)) ],
            [ "value" ],
            [ [ "effect"; "fallback" ] ] );
          ( "nested",
            record
              [
                field "outer"
                  (G.Assign
                     ( record [ field "inner" (with_default (id "value")) ],
                       tok,
                       call "outerFallback" [ call "outerEffect" [] ] )
                  |> G.e);
              ],
            [ "outer"; "inner" ],
            [ [ "outerEffect"; "outerFallback" ]; [ "effect"; "fallback" ] ] );
        ]
      in
      List.iter
        (fun ( (label : string),
               (lhs : G.expr),
               (expected_keys : string list),
               (expected_defaults : string list list) ) ->
          let lowered =
            AST_to_IL.stmt Lang.Js
              (G.exprstmt (G.Assign (lhs, tok, call "input" []) |> G.e))
          in
          let branches =
            List.filter_map
              (fun (stmt : IL.stmt) ->
                match stmt.IL.s with
                | IL.If
                    ( _,
                      {
                        e =
                          IL.Operator
                            ( (G.PhysEq, _),
                              [
                                IL.Unnamed { e = IL.Fetch selected; _ };
                                IL.Unnamed { e = IL.Literal (G.Undefined _); _ };
                              ] );
                        _;
                      },
                      yes,
                      [] ) ->
                    Some (selected, calls yes)
                | IL.If _ -> Alcotest.fail "expected strict undefined selection"
                | _ -> None)
              lowered
          in
          Alcotest.(check (list (list string)))
            (label ^ " conditional effects")
            expected_defaults (List.map snd branches);
          Alcotest.(check (list string))
            (label ^ " input read once")
            [ "input" ]
            (calls
               (List.filter
                  (fun (stmt : IL.stmt) ->
                    match stmt.IL.s with
                    | IL.If _ -> false
                    | _ -> true)
                  lowered));
          let keys = ref [] in
          let visitor =
            object
              inherit [_] IL.iter as super

              method! visit_exp () (exp : IL.exp) =
                (match exp.IL.e with
                | IL.Fetch { rev_offset = [ { o = IL.Dot key; _ } ]; _ } ->
                    keys := fst key.ident :: !keys
                | _ -> ());
                super#visit_exp () exp
            end
          in
          List.iter (visitor#visit_stmt ()) lowered;
          Alcotest.(check (list string))
            (label ^ " original source keys")
            expected_keys (List.rev !keys);
          let selected = fst (List.hd (List.rev branches)) in
          let rec bound_after_selection (seen : bool) (stmts : IL.stmt list) :
              bool =
            match stmts with
            | [] -> false
            | { IL.s = IL.If _ } :: rest -> bound_after_selection true rest
            | {
                IL.s =
                  IL.Instr
                    {
                      i =
                        IL.Assign
                          ( { base = IL.Var name; rev_offset = [] },
                            { e = IL.Fetch from; _ } );
                      _;
                    };
                _;
              }
              :: _
              when String.equal (fst name.ident) "value" ->
                let as_exp (lval : IL.lval) : IL.exp =
                  { IL.e = IL.Fetch lval; eorig = IL.NoOrig }
                in
                seen && IL_helpers.equal_exp (as_exp selected) (as_exp from)
            | _ :: rest -> bound_after_selection seen rest
          in
          Alcotest.(check bool)
            (label ^ " binds selected value after fallback")
            true
            (bound_after_selection false lowered))
        cases)

let tests (caps : < Cap.time_limit >)
    (parse_program : Fpath.t -> AST_generic.program) : Testo.t list =
  target_before_default_test ()
  :: pattern_default_test parse_program ()
  :: Testo.categorize "dataflow_python"
       [
         (* Just checking that it terminates without crashing. *)
         t "regression files" (fun () ->
             let dir = Filename.concat tests_path "dataflow/python" in
             let files = Common2.glob (spf "%s/*.py" dir) in
             files |> Fpath_.of_strings
             |> List.iter (fun file ->
                 let ast = parse_program file in
                 let lang = Lang.lang_of_filename_exn file in
                 Naming_AST.resolve lang ast;
                 match
                   Time_limit.set_timeout caps ~name:"cst_prop" timeout_secs
                     (fun () ->
                       Constant_propagation.propagate_basic lang ast;
                       Constant_propagation.propagate_dataflow lang ast)
                 with
                 | Some res -> res
                 | None ->
                     failwith
                       (spf
                          "constant propagation should finish in less than \
                           %gs: %s"
                          timeout_secs !!file)));
       ]
