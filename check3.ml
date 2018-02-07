type tyvar = Var of string;;
type tyname = Name of string;;
type mode = Sep | Ind;;

type ty = Unit | Int | Float | Bool | Char | Arrow of (ty * ty) | Cons of (ty * ty) | Tyvar of tyvar | Param of (tyvar list * tyname) | Exists of tyvar * ty;;

type context = (tyvar * mode) list;;

type def = Def of (tyvar * mode) list * tyname * ty * mode;;

exception Existential_is_not_sep of tyvar;;

let rec print_ty (u : ty) = 
  let rec aux t = match t with
    | Unit | Int | Float | Bool | Char -> print_string "base"
    | Arrow (a, b) -> let _ = aux a in let _ = print_string " -> " in aux b
    | Cons (a, b) -> let _ = aux a in let _ = print_string " : " in aux b
    | Tyvar (Var a) -> print_string a
    | Param (a, b) -> let print c d = let _ = print_string "param" in
                                      let _ = (List.iter (fun (Var x) -> print_string x) c)
                                         in let _ = begin match d with Name s -> print_string s end
                                            in let _ = (print_string "(")
                                               in let _ = (aux u)
                                                  in print_string ")\n"
                      in (print a b)
    | Exists (a, b) -> let _ = print_string "exists"
                       in let _ = begin match a with Var c -> print_string c end
                          in (print_ty b)
  in aux u;;

let rec print_ctx (ctx : context) =
  let print_mode (m : mode) =
    match m with
    | Sep -> print_endline "sep"
    | Ind -> print_endline "ind"
  in
  match ctx with
  | [] -> ()
  | (Var name, mode) :: tl -> let _ = print_string name in let _ = print_mode mode in let _ = print_newline in print_ctx tl;;

Random.self_init ();;

let rec rand_ty a =
  let n = (Random.int 6) in match n with
                            | 0 -> Int
                            | 1 -> (Arrow (rand_ty a, rand_ty a))
                            | 2 -> (Cons (rand_ty a, rand_ty a))
                            | 3 -> (Tyvar (Var " a "))
                            | 4 -> (Param ((Var " b " :: Var " c " :: []), Name "e"))
                            | 5 -> (Exists ((Var "c"), rand_ty ()))
                            | _ -> Int;;

let rec rand_tyvars n = match n with
  | 0 -> []
  | a -> ((Var (String.make 1 (Char.chr (Random.int 255)))), Ind) :: (rand_tyvars (n - 1));;

let rand_def a = 
  Def (rand_tyvars (Random.int 10), (Name (String.make 1 (Char.chr (Random.int 255)))), rand_ty (), Sep);;

let rec rand_defs n = match n with
  | 0 -> []
  | a -> (rand_def 1) :: (rand_defs (a - 1));;

let rec rand_tys a = match a with
  | 1 -> (rand_ty ()) :: []
  | b -> (rand_ty ()) :: (rand_tys (b - 1));;
(*
let rec tynames n = match n with
  | [] -> []
  | Def (tm, tyn, t, _) :: b -> tyn :: tynames b;; *)

let getmode (c : context) (t : tyvar) = if List.mem (t, Sep) c then Sep else
                                       Ind;;
(*
let getmodefromdef (d : def list) (t : tyvar) (a : ty) =
  try let definition = (List.find (fun (Def (x, y, z, _)) -> z = a) d)
      in match definition with Def (tym, tyn, l, _) ->
                            if List.mem (t, Sep) tym then Sep else Ind
  with Not_found -> assert false;; *)

let getdef (tofind : tyname) (defs : def list) =
  List.find (fun (Def (_, name, _, _)) -> name = tofind);;

let rec replacedef (defs : def list) (olddef : def) (newdef :def) =
  match defs with
  | [] -> []
  | hd :: tl when hd = olddef -> newdef :: tl
  | hd :: tl -> hd :: (replacedef tl olddef newdef);;

let rec updatedef (d : def) (l : tyvar list) =
  match d with Def (tym, name, bod, mode) -> Def ((List.map (fun (a, b) -> if List.mem a l then (a, Sep) else (a, b)) tym), name, bod, mode);;

let gettyvarmode (name : tyname) (defs : def list) =
  match (List.find (fun (Def (_, x, _, _)) -> name = x) defs) with Def(tym, _, _, _) -> tym;;



let rec checkargs (par : tyvar list) (d : (tyvar * mode) list) (ctx : context) =
  let rec aux (l : (tyvar * mode * tyvar * mode) list) =
    match l with
    | [] -> []
    | (_, mpar, _, md) :: tl when mpar = md -> aux tl
    | (a, mpar, _, md) :: tl -> a :: (aux tl)
  in
  aux (List.map2 (fun x (y, z) -> (x, (getmode ctx x), y, z)) par d);;



let rec checkdef (tocheck : def) (defs : def list) (ctx : context) =
  let checkexists (tocheck : def) (defs : def list) (ctx : context) =
  match (checkdef tocheck defs ctx) with
  | [] -> []
  | a -> List.append a (checkdef tocheck defs (List.append (List.map (fun a -> (a, Sep)) a) ctx)) in
  match tocheck with
    Def (partocheck, nametocheck, tytocheck, mode) ->
     match tytocheck with
     | Unit | Int | Float | Bool | Char -> []
     | Arrow (_, _) | Cons (_, _) -> []
     | Tyvar a -> if List.mem (a, Sep) ctx then [] else a :: []
     | Param (par, name) -> checkargs par (gettyvarmode name defs) ctx
     | Exists (ex, bod) -> begin
         let newtocheck = Def ([], nametocheck, bod, mode) in
         let newdefs = replacedef defs tocheck newtocheck in
         let out = (checkexists newtocheck newdefs ((ex, Ind) :: ctx)) in
         if List.mem ex out then raise (Existential_is_not_sep ex) else out
       end;;



let check (defs : def list) (ctx : context) =
  let rec aux (todo : def list) (defs : def list) (ctx : context) =
    match todo with
    | [] -> ctx
    | hd :: tl ->
       begin
         match (checkdef hd defs ctx) with
         | [] -> aux tl defs ctx
         | a -> aux defs (replacedef defs hd (updatedef hd a)) (List.append ctx (List.map (fun x -> (x, Sep)) a))
       end
  in aux defs defs ctx;;

let defs = (Def ([], Name "def1", Int, Sep))
           :: ((Def (([(Var "a", Ind); (Var "b", Ind)]), (Name "def2"), (Tyvar (Var "b")), Sep))
               :: ((Def (([(Var "c", Ind); (Var "d", Ind)]), (Name "def3"), (Param (([(Var "c"); (Var "d")]), (Name "def2"))), Sep))
                   :: (Def ([], (Name "def4"), (Exists (Var "e", Tyvar (Var "e"))), Sep)) :: []))

let ctx = [];;

print_ctx (check defs ctx);;