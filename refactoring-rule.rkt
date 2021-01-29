#lang racket/base


(require racket/contract)


(provide
 (contract-out
  [refactoring-rule? predicate/c]
  [standard-refactoring-rules (listof refactoring-rule?)]))


(module+ private
  (provide
   (contract-out
    [refactoring-rule-refactor (-> refactoring-rule? syntax? (option/c syntax-replacement?))])))


(require (for-syntax racket/base)
         fancy-app
         (only-in racket/class
                  define/augment
                  define/augment-final
                  define/augride
                  define/overment
                  define/override
                  define/override-final
                  define/public
                  define/public-final
                  define/pubment
                  define/private)
         racket/list
         racket/match
         racket/sequence
         racket/set
         racket/syntax
         rebellion/base/immutable-string
         rebellion/base/option
         rebellion/private/guarded-block
         rebellion/type/object
         resyntax/let-binding
         resyntax/source-code
         resyntax/syntax-replacement
         syntax/id-set
         syntax/parse
         syntax/parse/define
         syntax/parse/lib/function-header
         syntax/stx)


(module+ test
  (require (submod "..")
           rackunit))


;@----------------------------------------------------------------------------------------------------


(define-object-type refactoring-rule (transformer)
  #:omit-root-binding
  #:constructor-name constructor:refactoring-rule)


(define (refactoring-rule-refactor rule syntax)
  (define rule-introduction-scope (make-syntax-introducer))
  (option-map
   ((refactoring-rule-transformer rule) (rule-introduction-scope syntax))
   (λ (new-syntax)
     (syntax-replacement
      #:original-syntax syntax #:new-syntax (rule-introduction-scope new-syntax)))))


(define-simple-macro
  (define-refactoring-rule id:id parse-option ... [pattern pattern-directive ... replacement])
  (define id
    (constructor:refactoring-rule
     #:name 'id
     #:transformer
     (syntax-parser
       parse-option ...
       [pattern pattern-directive ... (present #'replacement)]
       [_ absent]))))


(define-syntax-class define-struct-id-maybe-super
  #:attributes (id super-id)
  (pattern id:id #:attr super-id #false)
  (pattern (id:id super-id:id)))


(define-refactoring-rule struct-from-define-struct-with-default-constructor-name
  #:literals (define-struct)
  [(define-struct id-maybe-super:define-struct-id-maybe-super fields
     (~and option (~not #:constructor-name) (~not #:extra-constructor-name)) ...)
   #:with make-id (format-id #'id-maybe-super.id "make-~a" #'id-maybe-super.id)
   (struct id-maybe-super.id (~? id-maybe-super.super-id) fields NEWLINE
     #:extra-constructor-name make-id NEWLINE
     option ...)])


(define-refactoring-rule false/c-migration
  #:literals (false/c)
  [false/c
   #false])


(define-refactoring-rule symbols-migration
  #:literals (symbols)
  [(symbols sym ...)
   (or/c sym ...)])


(define-refactoring-rule vector-immutableof-migration
  #:literals (vector-immutableof)
  [(vector-immutableof c)
   (vectorof c #:immutable #true)])


(define-refactoring-rule vector-immutable/c-migration
  #:literals (vector-immutable/c)
  [(vector-immutable/c c ...)
   (vector/c c ... #:immutable #true)])


(define-refactoring-rule box-immutable/c-migration
  #:literals (box-immutable/c)
  [(box-immutable/c c)
   (box/c c #:immutable #true)])


(define-refactoring-rule flat-contract-migration
  #:literals (flat-contract)
  [(flat-contract predicate)
   predicate])


(define-refactoring-rule flat-contract-predicate-migration
  #:literals (flat-contract-predicate)
  [(flat-contract-predicate c)
   c])


(define-refactoring-rule contract-struct-migration
  #:literals (contract-struct)
  [(contract-struct id fields)
   (struct id fields)])


(define-refactoring-rule define-contract-struct-migration
  #:literals (define-contract-struct)
  [(define-contract-struct id fields)
   #:with make-id (format-id #'id "make-~a" #'id)
   (struct id fields #:extra-constructor-name make-id)])


(define/guard (free-identifiers=? ids other-ids)
  (define id-list (syntax->list ids))
  (define other-id-list (syntax->list other-ids))
  (guard (equal? (length id-list) (length other-id-list)) else
    #false)
  (for/and ([id (in-list id-list)] [other-id (in-list other-id-list)])
    (free-identifier=? id other-id)))


(define-refactoring-rule define-lambda-to-define
  #:literals (define lambda)
  [(define header (lambda formals body ...))
   (define (header . formals) (~@ NEWLINE body) ...)])


(define-refactoring-rule define-case-lambda-to-define
  #:literals (define case-lambda)
  [(define id:id
     (case-lambda
       [(case1-arg:id ...)
        (usage:id usage1:id ... default:expr)]
       [(case2-arg:id ... bonus-arg:id)
        body ...]))
   #:when (free-identifier=? #'id #'usage)
   #:when (free-identifiers=? #'(case1-arg ...) #'(case2-arg ...))
   #:when (free-identifiers=? #'(case1-arg ...) #'(usage1 ...))
   (define (id case2-arg ... [bonus-arg default])
     (~@ NEWLINE body) ...)])


(define-refactoring-rule if-then-begin-to-cond
  #:literals (if begin)
  [(if condition (begin then-body ...) else-branch)
   (cond
     NEWLINE [condition (~@ NEWLINE then-body) ...]
     NEWLINE [else NEWLINE else-branch])])


(define-refactoring-rule if-else-begin-to-cond
  #:literals (if begin)
  [(if condition then-branch (begin else-body ...))
   (cond
     NEWLINE [condition NEWLINE then-branch]
     NEWLINE [else (~@ NEWLINE else-body) ...])])


(define-refactoring-rule if-else-cond-to-cond
  #:literals (if cond)
  [(if condition then-branch (cond clause ...))
   (cond
     NEWLINE [condition NEWLINE then-branch]
     (~@ NEWLINE clause) ...)])


(define-refactoring-rule if-else-if-to-cond
  #:literals (if)
  [(if condition then-branch (if inner-condition inner-then-branch else-branch))
   (cond
     NEWLINE [condition NEWLINE then-branch]
     NEWLINE [inner-condition NEWLINE inner-then-branch]
     NEWLINE [else else-branch])])


(define-refactoring-rule cond-else-if-to-cond
  #:literals (cond else if)
  [(cond clause ... [else (if inner-condition inner-then-branch else-branch)])
   (cond
     (~@ NEWLINE clause) ...
     NEWLINE [inner-condition NEWLINE inner-then-branch]
     NEWLINE [else NEWLINE else-branch])])


(define-refactoring-rule cond-begin-to-cond
  #:literals (cond begin)
  [(cond clause-before ...
         [condition (begin body ...)]
         clause-after ...)
   (cond
     (~@ NEWLINE clause-before) ...
     NEWLINE [condition (~@ NEWLINE body) ...]
     (~@ NEWLINE clause-after) ...)])


(define-refactoring-rule or-cond-to-cond
  #:literals (or cond)
  [(or condition (cond clause ...))
   (cond
     NEWLINE [condition #t]
     (~@ NEWLINE clause) ...)])


(define-refactoring-rule or-or-to-or
  #:literals (or)
  [(or first-clause clause ... (or inner-clause ...))
   (or first-clause
       (~@ NEWLINE clause) ...
       (~@ NEWLINE inner-clause) ...)])


(define-refactoring-rule and-and-to-and
  #:literals (and)
  [(and first-clause clause ... (and inner-clause ...))
   (and first-clause
        (~@ NEWLINE clause) ...
        (~@ NEWLINE inner-clause) ...)])


(define-refactoring-rule and-match-to-match
  #:literals (and match)
  [(and and-subject:id (match match-subject:id match-clause ...))
   #:when (free-identifier=? #'and-subject #'match-subject)
   (match match-subject
     NEWLINE [#false #false]
     (~@ NEWLINE match-clause) ...)])


;@----------------------------------------------------------------------------------------------------
;; DEFINITION CONTEXT RULES


(define-refactoring-rule let-to-define
  [(header:header-form-allowing-internal-definitions let-expr:refactorable-let-expression)
   (header.formatted ... let-expr.refactored ...)])


(define-splicing-syntax-class header-form-allowing-internal-definitions
  #:attributes ([formatted 1])
  #:literals (let let* let-values when unless)

  (pattern (~seq lambda:lambda-by-any-name ~! formals:formals)
    #:with (formatted ...) #'(lambda formals))

  (pattern (~seq define:define-by-any-name ~! header:function-header)
    #:with (formatted ...) #'(define header))

  (pattern (~seq let ~! (~optional name:id) header)
    #:with (formatted ...) #'(let (~? name) header))

  (pattern (~seq let* ~! header)
    #:with (formatted ...) #'(let* header))

  (pattern (~seq let-values ~! header)
    #:with (formatted ...) #'(let-values header))

  (pattern (seq when ~! condition)
    #:with (formatted ...) #'(when condition))

  (pattern (seq unless ~! condition)
    #:with (formatted ...) #'(unless condition)))


;; λ and lambda aren't free-identifier=?. Additionally, by using a syntax class instead of #:literals
;; we can produce the same lambda identifier that the input syntax had instead of changing all lambda
;; identfiers to one of the two cases. There doesn't seem to be a strong community consensus on which
;; name should be used, so we want to avoid changing the original code's choice.
(define-syntax-class lambda-by-any-name
  #:literals (λ lambda)
  (pattern (~or λ lambda)))


;; There's a lot of variants of define that support the same grammar but have different meanings. We
;; can recognize and refactor all of them with this syntax class.
(define-syntax-class define-by-any-name
  #:literals (define
               define/augment
               define/augment-final
               define/augride
               define/overment
               define/override
               define/override-final
               define/public
               define/public-final
               define/pubment
               define/private)
  (pattern
      (~or define
           define/augment
           define/augment-final
           define/augride
           define/overment
           define/override
           define/override-final
           define/public
           define/public-final
           define/pubment
           define/private)))


(define-refactoring-rule and-let-to-cond-define
  #:literals (and let)
  [(and guard-expr (~and let-form (let header body ...)))
   (cond
     NEWLINE [(not guard-expr) #false]
     NEWLINE [else NEWLINE let-form])])


(define-syntax-class cond-clause
  #:attributes ([formatted 1])
  #:literals (else =>)
  (pattern (~and clause (~or [else body ...+] [expr:expr => body-handler:expr] [expr:expr body ...+]))
    #:with (formatted ...)
    #'(NEWLINE clause)))


(define-syntax-class refactorable-cond-clause
  #:attributes ([refactored 1])
  #:literals (else =>)

  (pattern [else let-expr:refactorable-let-expression]
    #:with (refactored ...) #'(NEWLINE [else let-expr.refactored ...]))
  
  (pattern (~and [expr let-expr:refactorable-let-expression] (~not [expr => _ ...]))
    #:with (refactored ...) #'(NEWLINE [expr let-expr.refactored ...])))


(define-refactoring-rule cond-let-to-cond-define
  #:literals (cond)
  [(cond
     clause-before:cond-clause ...
     refactorable:refactorable-cond-clause
     clause-after:cond-clause ...)
   (cond
     clause-before.formatted ... ...
     refactorable.refactored ...
     clause-after.formatted ... ...)])


(define-refactoring-rule if-then-let-to-cond-define
  #:literals (if else let)
  [(if condition
       (~and let-form (let header body ...))
       else-expr)
   (cond
     NEWLINE [condition NEWLINE let-form]
     NEWLINE [else NEWLINE else-expr])])


(define-refactoring-rule if-else-let-to-cond-define
  #:literals (if else let)
  [(if condition
       then-expr
       (~and let-form (let header body ...)))
   (cond
     NEWLINE [condition NEWLINE then-expr]
     NEWLINE [else NEWLINE let-form])])


(define-refactoring-rule let*-once-to-let
  #:literals (let*)
  [(let* (~and header ([id:id rhs:expr])) body ...)
   (let header (~@ NEWLINE body) ...)])


;@----------------------------------------------------------------------------------------------------
;; STANDARD RULE LIST


(define standard-refactoring-rules
  (list
   and-and-to-and
   and-let-to-cond-define
   and-match-to-match
   box-immutable/c-migration
   cond-begin-to-cond
   cond-else-if-to-cond
   cond-let-to-cond-define
   contract-struct-migration
   define-case-lambda-to-define
   define-contract-struct-migration
   define-lambda-to-define
   false/c-migration
   flat-contract-migration
   flat-contract-predicate-migration
   if-then-begin-to-cond
   if-then-let-to-cond-define
   if-else-begin-to-cond
   if-else-cond-to-cond
   if-else-if-to-cond
   if-else-let-to-cond-define
   let-to-define
   let*-once-to-let
   or-cond-to-cond
   or-or-to-or
   struct-from-define-struct-with-default-constructor-name
   symbols-migration
   vector-immutableof-migration
   vector-immutable/c-migration))
