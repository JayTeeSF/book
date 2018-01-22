(** Generate jbuild files for code examples within the tree *)
open Printf
open Sexplib.Conv

(** Directory and file traversal functions *)

(** [find_dirs_containing ~exts base] will return all the sub-directories
    that contain files that match any of extension [ext], starting from
    the [base] directory. *)
let find_dirs_containing ?(ignore_dirs=[]) ~exts base =
  let rec fn base =
    Sys.readdir base |>
    Array.map (Filename.concat base) |>
    Array.map (fun d ->
      if Sys.is_directory d && not (List.mem (Filename.basename d) ignore_dirs) then
        fn d else [d]) |>
    Array.to_list |>
    List.flatten |>
    List.filter (fun f -> List.exists (Filename.check_suffix f) exts) in
  fn base |>
  List.map Filename.dirname |>
  List.sort_uniq String.compare

(** [files_with ~exts base] will return all the files matching the
    extension [exts] in directory [base]. *)
let files_with ~exts base =
  Sys.readdir base |>
  Array.to_list |>
  List.filter (fun f -> List.exists (Filename.check_suffix f) exts) 

(** [emit_sexp file sexp] writes [sexp] to [file] with a
    jbuild header and comment marking that it is autogenerated. *)
let emit_sexp file s =
  eprintf "Processing %s\n%!" file;
  let fout = open_out file in
  sprintf "((jbuild_version 1) %s)" s |>
  Sexplib.Sexp.of_string |> fun l ->
  match l with
  | Sexplib.Sexp.Atom _ -> assert false
  | Sexplib.Sexp.List l ->
      List.iter (fun s ->
        Sexp_pretty.sexp_to_string s |>
        output_string fout;
        output_string fout "\n") l;
      close_out fout

let book_extensions =
  [ ".ml"; ".mli"; ".mly"; ".mll"; ".rawtopscript";
    ".syntax"; ".scm"; ".rawscript"; ".java"; ".cpp";
    ".topscript"; ".sh"; ".errsh"; ".rawsh"; "jbuild";
    ".json"; ".atd"; ".rawsh"; ".c"; ".h"; ".cmd"; ".S" ]

let static_extensions =
  [ ".js"; ".jpg"; ".css"; ".png" ]

(** Process the book chapters *)

(** Find the dependencies within an HTML file *)
let sexp_deps_of_chapter file =
  let open Soup in
  read_file file |>
  parse |> fun s ->
  s $$ "link[rel][href]" |>
  fold (fun a n -> R.attribute "href" n :: a) [] |>
  List.sort_uniq String.compare

let jbuild_for_chapter base_dir file =
  let examples_dir = "../examples" in
  let deps =
    sexp_deps_of_chapter (Filename.concat base_dir file) |>
    List.map (sprintf "%s/%s.sexp" examples_dir) |>
    List.map (fun s -> "     " ^ s) |>
    String.concat "\n" in
  sprintf {|
  (alias ((name site) (deps (%s))))
  (rule
  ((targets (%s))
   (deps (../book/%s ../bin/bin/app.exe 
%s))
   (action (run rwo-build build chapter -o . -code ../examples -repo-root .. ${<})))) |} file file file deps

let starts_with_digit b =
  try Scanf.sscanf b "%d-" (fun _ -> ()); true
  with _ -> false

let frontpage_chapter name =
  sprintf {|
  (alias ((name site) (deps (%s.html))))
  (rule
    ((targets (%s.html))
    (deps (../book/%s.html ../bin/bin/app.exe))
    (action (run rwo-build build %s -o . -repo-root ..)))) |} name name name name

let find_static_files () =
  find_dirs_containing ~exts:static_extensions "static" |>
  List.map (fun d -> files_with ~exts:static_extensions d |> List.map (Filename.concat d)) |>
  List.flatten |>
  List.map (fun f ->
    String.split_on_char '/' f |>
    List.tl |>
    String.concat "/") |>
  String.concat "\n" |>
  sprintf "(alias ((name site) (deps (%s))))"

let process_chapters book_dir output_dir =
  files_with ~exts:[".html"] book_dir |>
  List.sort String.compare |>
  List.map (function
    | file when starts_with_digit file -> jbuild_for_chapter book_dir file
    | "install.html" -> frontpage_chapter "install"
    | "faqs.html" -> frontpage_chapter "faqs"
    | "toc.html" -> frontpage_chapter "toc"
    | "index.html" -> frontpage_chapter "index"
    | file -> eprintf "Warning: orphan html file %s in repo\n" file; ""
  ) |>
  String.concat "\n" |> fun s ->
  find_static_files () ^ s |>
  emit_sexp (Filename.concat output_dir "jbuild.inc")

(** Handle examples *)

let topscript_rule ~dep f =
  sprintf {|
(alias ((name code) (deps (%s.stamp))))
(alias ((name sexp) (deps (%s.sexp))))
(rule
 ((targets (%s.sexp))
  (deps    (%s))
  (action  (with-stdout-to ${@}
    (run ocaml-topexpect -dry-run -sexp -short-paths -verbose ${<})))))
(rule
 ((targets (%s.stamp))
  (deps    (%s %s))
  (action  (progn
    (setenv OCAMLRUNPARAM "" (run ocaml-topexpect -short-paths -verbose ${<}))
    (write-file ${@} "")
    (diff? %s %s.corrected)
    ))
  )) |} f f f f f f dep f f

let rwo_eval_rule ~dep f =
  sprintf {|
(alias ((name sexp) (deps (%s.sexp))))
(rule
  ((targets (%s.sexp)) (deps (%s %s))
  (fallback)
  (action (with-stdout-to ${@} (run rwo-build eval ${<}))))) |} f f f dep

let jbuild_rule ~dep f =
  (* TODO filter out the include here *)
  rwo_eval_rule ~dep f

let sh_rule ~dep f =
  (* see https://github.com/ocaml/dune/issues/431 is answered *)
  sprintf {|
(alias ((name sexp) (deps (%s.sexp))))
(rule
  ((targets (%s.sexp))
  (deps (%s %s))
  (fallback)
  (action (setenv TERM dumb (with-stdout-to ${@} (run rwo-build eval ${<})))))) |} f f f dep

type extra_deps = (string * string list) list [@@deriving sexp]

let find_extra_deps dir =
  let f = Filename.concat dir "jbuild.deps" in
  if Sys.file_exists f then begin
    Sexplib.Sexp.load_sexp_conv_exn f extra_deps_of_sexp
  end else []

let process_examples dir =
  Filename.concat dir "jbuild.inc" |> fun jbuild ->
  find_extra_deps dir |> fun deps ->
  files_with ~exts:book_extensions dir |>
  List.map (fun f ->
    let dep = List.assoc_opt f deps |> function None -> "" | Some v -> String.concat " " v in
    match f with 
    | "jbuild" -> jbuild_rule ~dep f 
    | f when Filename.extension f = ".topscript" -> topscript_rule ~dep f
    | f when Filename.extension f = ".sh" -> sh_rule ~dep f
    | f when Filename.extension f = ".errsh" -> sh_rule ~dep f
    | f when List.mem (Filename.extension f) book_extensions -> rwo_eval_rule ~dep f
    | _ -> printf "skipping %s/%s\n%!" dir f; ""
  ) |>
  List.filter ((<>) "") |>
  String.concat "\n" |>
  emit_sexp jbuild 

let _ =
  find_dirs_containing ~ignore_dirs:["_build"] ~exts:book_extensions "examples" |>
  List.iter process_examples;
  process_chapters "book" "static";
