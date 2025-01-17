#lang racket/base


(require racket/contract/base)


(provide
 (contract-out
  [boolean-shortcuts refactoring-suite?]))


(require (for-syntax racket/base)
         rebellion/private/static-name
         resyntax/default-recommendations/private/syntax-lines
         resyntax/default-recommendations/private/syntax-tree
         resyntax/refactoring-rule
         resyntax/refactoring-suite
         syntax/parse)


;@----------------------------------------------------------------------------------------------------


(define-refactoring-rule nested-or-to-flat-or
  #:description "Nested or expressions can be flattened to a single, equivalent or expression."
  [or-tree
   #:declare or-tree (syntax-tree #'or)
   ;; Restricted to single-line expressions for now because the syntax-tree operations don't preserve
   ;; any formatting between adjacent leaves.
   #:when (oneline-syntax? #'or-tree)
   #:when (>= (attribute or-tree.rank) 2)
   (or or-tree.leaf ...)])


(define-refactoring-rule nested-and-to-flat-and
  #:description "Nested and expressions can be flattened to a single, equivalent and expression."
  [and-tree
   #:declare and-tree (syntax-tree #'and)
   ;; Restricted to single-line expressions for now because the syntax-tree operations don't preserve
   ;; any formatting between adjacent leaves.
   #:when (oneline-syntax? #'and-tree)
   #:when (>= (attribute and-tree.rank) 2)
   (and and-tree.leaf ...)])


(define simpler-boolean-expression
  "This boolean expression can be replaced with a simpler, logically equivalent expression.")


(define-refactoring-rule de-morgan-and-to-or
  #:description simpler-boolean-expression
  #:literals (and not)
  [(and (not expr) ...+)
   (not (or expr ...))])


(define-refactoring-rule de-morgan-or-to-and
  #:description simpler-boolean-expression
  #:literals (or not)
  [(or (not expr) ...+)
   (not (and expr ...))])


(define boolean-shortcuts
  (refactoring-suite
   #:name (name boolean-shortcuts)
   #:rules
   (list de-morgan-and-to-or
         de-morgan-or-to-and
         nested-and-to-flat-and
         nested-or-to-flat-or)))
