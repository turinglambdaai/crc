#lang racket/base

;; Test suite for the crc package: every catalogue entry is checked against
;; its published check value (CRC of "123456789"), the table-driven engine
;; is cross-checked against the bitwise reference implementation, and the
;; reflection helper and digest format are exercised directly.

(require rackunit
         racket/list
         racket/match
         crc/engine
         crc/catalog)

(define check-string #"123456789")

(test-case "check values from the public CRC catalogue"
  (for ([p (in-list (all-crcs))])
    (with-check-info (['algorithm (crc-params-name p)])
      (check-equal? (crc-compute p check-string) (crc-params-check p)))))

(test-case "table-driven engine agrees with the bitwise reference"
  (define data #"The quick brown fox jumps over the lazy dog, twice: the quick brown fox jumps over the lazy dog.")
  (for ([p (in-list (all-crcs))])
    (with-check-info (['algorithm (crc-params-name p)])
      (check-equal? (crc-compute p data) (crc-compute/bitwise p data)))))

(test-case "well-known CRC-32 vectors"
  (check-equal? (crc-compute crc-32 #"") 0)
  (check-equal? (crc-compute crc-32 #"a") #xE8B7BE43)
  (check-equal? (crc-compute crc-32 #"abc") #x352441C2)
  (check-equal? (crc-digest crc-32 check-string) (bytes #xCB #xF4 #x39 #x26)))

(test-case "reflection helper"
  (check-equal? (crc-reflect #b11101 5) #b10111)
  (check-equal? (crc-reflect #x01 8) #x80)
  (check-equal? (crc-reflect #xA0 8) #x05)
  (check-equal? (crc-reflect 0 7) 0)
  (check-equal? (crc-reflect #x1FFFFFFF 29) #x1FFFFFFF))

(test-case "bit-by-bit path (widths below 8) matches the reference definition"
  ;; CRC-4/ITU: poly 0x3, init 0, refin/refout true, xorout 0; check 0x7.
  (define crc-4/itu (make-crc-params 'crc-4/itu 4 #x3 #x0 #t #t #x0 #x7))
  (check-equal? (crc-compute crc-4/itu check-string) #x7)
  ;; CRC-7/MMC (poly 0x09, init 0, no reflection); check 0x75.
  (define crc-7/mmc (make-crc-params 'crc-7/mmc 7 #x09 #x00 #f #f #x00 #x75))
  (check-equal? (crc-compute crc-7/mmc check-string) #x75))

(test-case "narrow-width digests pad to whole bytes"
  (define crc-4/itu (make-crc-params 'crc-4/itu 4 #x3 #x0 #t #t #x0 #x7))
  (check-equal? (bytes-length (crc-digest crc-4/itu check-string)) 1)
  (check-equal? (crc-digest crc-4/itu check-string) (bytes #x07)))

(test-case "incremental API agrees with one-shot across all presets"
  (define data (list->bytes (build-list 500 (lambda (i) (modulo (* i 13) 256)))))
  (for ([p (in-list (all-crcs))])
    (with-check-info (['algorithm (crc-params-name p)])
      ;; 37-byte chunks: odd boundaries that cross no aligned edge
      (define reg
        (for/fold ([reg (crc-begin p)])
                  ([i (in-range 0 (bytes-length data) 37)])
          (crc-extend p reg data i (min (+ i 37) (bytes-length data)))))
      (check-equal? (crc-result p reg) (crc-compute p data)))))

(test-case "crc-32 raw register semantics (pins from the crc32 package suite)"
  (check-equal? (crc-extend crc-32 (crc-begin crc-32) #"A") #x2C266174)
  (check-equal? (crc-extend crc-32 (crc-extend crc-32 (crc-begin crc-32) #"A") #"B")
                #xCF96B3F8)
  (check-equal? (crc-result crc-32 (crc-extend crc-32 (crc-begin crc-32) #"ABC"))
                #xA3830348))

(test-case "standard CRC-32 vectors"
  (check-equal? (crc-compute crc-32 #"message digest") #x20159D7F)
  (check-equal? (crc-compute crc-32 #"abcdefghijklmnopqrstuvwxyz") #x4C2750BD)
  (check-equal? (crc-compute crc-32 #"The quick brown fox jumps over the lazy dog")
                #x414FA339))

(test-case "crc-input-port streams across the 64KB buffer boundary"
  (define big (list->bytes (build-list 200000 (lambda (i) (modulo i 251)))))
  (check-equal? (crc-input-port crc-32 (open-input-bytes big))
                (crc-compute crc-32 big))
  (check-equal? (crc-input-port crc-16/modbus (open-input-bytes big))
                (crc-compute crc-16/modbus big)))

(test-case "catalogue lookup"
  (check-equal? (crc-by-name 'crc-32) crc-32)
  (check-equal? (crc-by-name 'nope) #f)
  (check-equal? (length (all-crcs)) 21)
  ;; Names are unique.
  (check-equal? (length (remove-duplicates (map crc-params-name (all-crcs)))) 21))

(test-case "engine rejects nothing but computes integers within width"
  (for ([p (in-list (all-crcs))])
    (define v (crc-compute p #"payload"))
    (check-true (and (integer? v) (>= v 0) (< v (arithmetic-shift 1 (crc-params-width p))))
                (format "~a out of range" (crc-params-name p)))))
