(jbuild_version 1)

(alias ((name sexp) (deps (read_json.ml.sexp))))

(rule (
  (targets (read_json.ml.sexp))
  (deps    (read_json.ml))
  (fallback)
  (action (with-stdout-to ${@} (run rwo-build eval ${<})))))

(alias ((name sexp) (deps (run_read_json.sh.sexp))))

(rule (
  (targets (run_read_json.sh.sexp))
  (deps (run_read_json.sh book.json read_json.ml jbuild jbuild.inc))
  (fallback)
  (action (setenv TERM dumb (with-stdout-to ${@} (run rwo-build eval ${<}))))))

(alias ((name sexp) (deps (jbuild.sexp))))

(rule (
  (targets (jbuild.sexp))
  (deps    (jbuild))
  (fallback)
  (action (with-stdout-to ${@} (run rwo-build eval ${<})))))

(alias ((name sexp) (deps (book.json.sexp))))

(rule (
  (targets (book.json.sexp))
  (deps    (book.json))
  (fallback)
  (action (with-stdout-to ${@} (run rwo-build eval ${<})))))

