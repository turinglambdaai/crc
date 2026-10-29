#lang info

(define version "0.2")
;; Multi-collection package shape: the collection is the `crc/` subdirectory.
;; `collection 'multi` is the standard declaration for this layout.
(define collection 'multi)
;; rackunit-lib is a run-time dependency (not merely a build-time one)
;; because the package ships its test suite, and the catalog's dependency
;; check scans shipped modules in run mode.
(define deps '("base" "rackunit-lib"))
(define build-deps '("base" "scribble-lib" "racket-doc" "rackunit-lib"))
(define pkg-desc "CRC catalogue and generic engine (widths 1-64) weighted towards automotive and embedded use: CAN, CAN FD, AUTOSAR E2E, SAE J1850")
(define pkg-authors '("turlamai"))
(define license 'MIT)
;; Loading the scribblings as a "test" produces no tests and noise; skip it.
(define test-omit-paths '("crc/scribblings"))
