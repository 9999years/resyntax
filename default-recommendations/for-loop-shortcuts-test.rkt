#lang resyntax/testing/refactoring-test


require: resyntax/default-recommendations for-loop-shortcuts


test: "for-each with short single-form body not refactorable"
------------------------------
#lang racket/base
(define some-list (list 1 2 3))
(for-each (λ (x) (displayln x)) some-list)
------------------------------


test: "for-each with long single-form body to for"
------------------------------
#lang racket/base
(define some-list (list 1 2 3))
(for-each
 (λ (a-very-very-very-long-variable-name-thats-so-very-long)
   (displayln a-very-very-very-long-variable-name-thats-so-very-long))
 some-list)
------------------------------
#lang racket/base
(define some-list (list 1 2 3))
(for ([a-very-very-very-long-variable-name-thats-so-very-long (in-list some-list)])
  (displayln a-very-very-very-long-variable-name-thats-so-very-long))
------------------------------


test: "for-each with multiple body forms to for"
------------------------------
#lang racket/base
(define some-list (list 1 2 3))
(for-each
 (λ (x)
   (displayln x)
   (displayln x))
 some-list)
------------------------------
#lang racket/base
(define some-list (list 1 2 3))
(for ([x (in-list some-list)])
  (displayln x)
  (displayln x))
------------------------------


test: "for-each with let expression to for with definitions"
------------------------------
#lang racket/base
(define some-list (list 1 2 3))
(for-each (λ (x) (let ([y 1]) (displayln x))) some-list)
------------------------------
#lang racket/base
(define some-list (list 1 2 3))
(for ([x (in-list some-list)])
  (define y 1)
  (displayln x))
------------------------------


test: "for-each range to for"
------------------------------
#lang racket/base
(require racket/list)
(for-each
 (λ (x)
   (displayln x)
   (displayln x))
 (range 0 10))
------------------------------
#lang racket/base
(require racket/list)
(for ([x (in-range 0 10)])
  (displayln x)
  (displayln x))
------------------------------


test: "for-each string->list to for in-string"
------------------------------
#lang racket/base
(for-each
 (λ (x)
   (displayln x)
   (displayln x))
 (string->list "hello"))
------------------------------
#lang racket/base
(for ([x (in-string "hello")])
  (displayln x)
  (displayln x))
------------------------------


test: "for-each bytes->list to for in-bytes"
------------------------------
#lang racket/base
(for-each
 (λ (x)
   (displayln x)
   (displayln x))
 (bytes->list #"hello"))
------------------------------
#lang racket/base
(for ([x (in-bytes #"hello")])
  (displayln x)
  (displayln x))
------------------------------


test: "for/fold building hash to for/hash"
------------------------------
#lang racket/base
(for/fold ([h (hash)]) ([x (in-range 0 10)])
  (hash-set h x 'foo))
------------------------------
#lang racket/base
(for/hash ([x (in-range 0 10)])
  (values x 'foo))
------------------------------


test: "for*/fold building hash to for*/hash"
------------------------------
#lang racket/base
(for*/fold ([h (hash)]) ([x (in-range 0 10)])
  (hash-set h x 'foo))
------------------------------
#lang racket/base
(for*/hash ([x (in-range 0 10)])
  (values x 'foo))
------------------------------


test: "for/fold building hash can't be refactored when referring to hash"
------------------------------
#lang racket/base
(for/fold ([h (hash)]) ([x (in-range 0 10)])
  (displayln
   (hash-has-key? h x))
  (hash-set h x 'foo))
------------------------------


test: "for*/fold building hash can't be refactored when referring to hash"
------------------------------
#lang racket/base
(for*/fold ([h (hash)]) ([x (in-range 0 10)])
  (displayln
   (hash-has-key? h x))
  (hash-set h x 'foo))
------------------------------