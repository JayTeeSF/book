(jbuild_version 1)

(alias ((name sexp) (deps (custom_ops.c.sexp))))

(rule (
  (targets (custom_ops.c.sexp))
  (deps    (custom_ops.c))
  (fallback)
  (action (with-stdout-to ${@} (run rwo-build eval ${<})))))

(alias ((name code) (deps (simple_record.topscript.stamp))))

(alias ((name sexp) (deps (simple_record.topscript.sexp))))

(rule (
  (targets (simple_record.topscript.sexp))
  (deps    (simple_record.topscript))
  (action (
    with-stdout-to ${@} (
      run ocaml-topexpect -dry-run -sexp -short-paths -verbose ${<})))))

(rule (
  (targets (simple_record.topscript.stamp))
  (deps    (simple_record.topscript))
  (action (
    progn
    (setenv OCAMLRUNPARAM "" (run ocaml-topexpect -short-paths -verbose ${<}))
    (write-file ${@} "")
    (diff? simple_record.topscript simple_record.topscript.corrected)))))

(alias ((name sexp) (deps (jbuild.sexp))))

(rule (
  (targets (jbuild.sexp))
  (deps    (jbuild))
  (fallback)
  (action (with-stdout-to ${@} (run rwo-build eval ${<})))))

(alias ((name code) (deps (reprs.topscript.stamp))))

(alias ((name sexp) (deps (reprs.topscript.sexp))))

(rule (
  (targets (reprs.topscript.sexp))
  (deps    (reprs.topscript))
  (action (
    with-stdout-to ${@} (
      run ocaml-topexpect -dry-run -sexp -short-paths -verbose ${<})))))

(rule (
  (targets (reprs.topscript.stamp))
  (deps    (reprs.topscript))
  (action (
    progn
    (setenv OCAMLRUNPARAM "" (run ocaml-topexpect -short-paths -verbose ${<}))
    (write-file ${@}            "")
    (diff?      reprs.topscript reprs.topscript.corrected)))))

