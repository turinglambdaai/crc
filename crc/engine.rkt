#lang racket/base

;; Generic CRC engine: any width 1-64, with or without input/output
;; reflection and final XOR.  Byte-aligned widths (>= 8) use a 256-entry
;; lookup table; narrower widths fall back to a bit-by-bit loop.
;; Algorithm and terminology follow the public CRC catalogue
;; (https://reveng.sourceforge.io/crc-catalogue/).

(require racket/contract)

(provide (contract-out
          (struct crc-params
            ((name    symbol?)
             (width   (integer-in 1 64))
             (poly    exact-nonnegative-integer?)   ; normal (unreflected) form
             (init    exact-nonnegative-integer?)
             (refin   boolean?)
             (refout  boolean?)
             (xorout  exact-nonnegative-integer?)
             (check   exact-nonnegative-integer?)   ; crc of "123456789"
             (table   (or/c #f (vectorof exact-nonnegative-integer?))))) ; internal cache
          [make-crc-params
           (-> symbol? (integer-in 1 64)
               exact-nonnegative-integer? exact-nonnegative-integer?
               boolean? boolean? exact-nonnegative-integer?
               exact-nonnegative-integer?
               crc-params?)]
          [crc-compute (-> crc-params? bytes? exact-nonnegative-integer?)]
          [crc-digest (-> crc-params? bytes? bytes?)]
          [crc-reflect (-> exact-nonnegative-integer? (integer-in 1 64)
                           exact-nonnegative-integer?)]
          [crc-compute/bitwise (-> crc-params? bytes? exact-nonnegative-integer?)]))

(struct crc-params (name width poly init refin refout xorout check table)
  #:transparent)

;; Reverse the low `width` bits of `value`.
(define (crc-reflect value width)
  (let loop ([v value] [bits width] [out 0])
    (if (zero? bits)
        out
        (loop (arithmetic-shift v -1)
              (sub1 bits)
              (bitwise-ior (arithmetic-shift out 1)
                           (bitwise-and v 1))))))

(define (crc-mask width) (sub1 (arithmetic-shift 1 width)))

;; Finish: put the register into output order and apply xorout.  With
;; refout the register is already in transmission order; without refout the
;; output must be in normal (unreflected) order, so a reflected register
;; (refin) is converted first.
(define (crc-finish p crc)
  (define width (crc-params-width p))
  (define mask (crc-mask width))
  (define out
    (cond [(crc-params-refout p) crc]
          [(crc-params-refin p) (crc-reflect crc width)]
          [else crc]))
  (bitwise-and (bitwise-xor out (crc-params-xorout p)) mask))

;; Bit-by-bit reference implementation; used for widths below 8 where the
;; byte-wise formulations do not apply.  Works for any width.
(define (crc-compute/bits p data)
  (define width (crc-params-width p))
  (define mask (crc-mask width))
  (define top (arithmetic-shift 1 (sub1 width)))
  (define poly (crc-params-poly p))
  (define rpoly (crc-reflect poly width))
  (define crc
    (if (crc-params-refin p)
        (crc-reflect (bitwise-and (crc-params-init p) mask) width)
        (bitwise-and (crc-params-init p) mask)))
  (define final
    (for/fold ([crc crc])
              ([byte (in-bytes data)])
      (for/fold ([crc crc])
                ([k (in-range 8)])
        (define bit
          (if (crc-params-refin p)
              (bitwise-and (arithmetic-shift byte (- k)) 1)
              (bitwise-and (arithmetic-shift byte (- k 7)) 1)))
            (if (crc-params-refin p)
                (if (= 1 (bitwise-xor (bitwise-and crc 1) bit))
                    (bitwise-xor (arithmetic-shift crc -1) rpoly)
                    (arithmetic-shift crc -1))
                (if (= 1 (bitwise-xor (bitwise-and (arithmetic-shift crc (- (sub1 width))) 1) bit))
                    (bitwise-and (bitwise-xor (arithmetic-shift crc 1) poly) mask)
                    (bitwise-and (arithmetic-shift crc 1) mask))))))
  (crc-finish p final))

;; Byte-wise reference implementation (width >= 8); kept as the
;; table-independent cross-check for tests.
(define (crc-compute/bitwise p data)
  (define width (crc-params-width p))
  (define mask (crc-mask width))
  (define poly (crc-params-poly p))
  (define len (bytes-length data))
  (cond
    [(crc-params-refin p)
     (define rpoly (crc-reflect poly width))
     (let loop ([i 0]
                [crc (crc-reflect (bitwise-and (crc-params-init p) mask) width)])
       (if (= i len)
           (crc-finish p crc)
           (let inner ([j 0] [crc (bitwise-xor crc (bytes-ref data i))])
             (if (= j 8)
                 (loop (add1 i) crc)
                 (inner (add1 j)
                        (if (= 1 (bitwise-and crc 1))
                            (bitwise-xor (arithmetic-shift crc -1) rpoly)
                            (arithmetic-shift crc -1)))))))]
    [else
     (let loop ([i 0] [crc (bitwise-and (crc-params-init p) mask)])
       (if (= i len)
           (crc-finish p crc)
           (let inner ([j 0]
                       [crc (bitwise-xor crc
                                         (arithmetic-shift (bytes-ref data i)
                                                           (- width 8)))])
             (if (= j 8)
                 (loop (add1 i) (bitwise-and crc mask))
                 (inner (add1 j)
                        (if (>= crc (arithmetic-shift 1 (sub1 width)))
                            (bitwise-and (bitwise-xor (arithmetic-shift crc 1) poly)
                                         mask)
                            (bitwise-and (arithmetic-shift crc 1) mask)))))))]))

;; 256-entry table for byte-aligned widths (>= 8).
(define (build-table p)
  (define width (crc-params-width p))
  (let ([mask (crc-mask width)]
        [top (arithmetic-shift 1 (sub1 width))]
        [shift (- width 8)])
    (build-vector 256
      (lambda (c)
        (if (crc-params-refin p)
            (let ([rpoly (crc-reflect (crc-params-poly p) width)])
              (let inner ([j 0] [crc c])
                (if (= j 8)
                    crc
                    (inner (add1 j)
                           (if (= 1 (bitwise-and crc 1))
                               (bitwise-xor (arithmetic-shift crc -1) rpoly)
                               (arithmetic-shift crc -1))))))
            (let inner ([j 0] [crc (arithmetic-shift c shift)])
              (if (= j 8)
                  crc
                  (inner (add1 j)
                         (if (>= crc top)
                             (bitwise-and (bitwise-xor (arithmetic-shift crc 1)
                                                       (crc-params-poly p))
                                          mask)
                             (bitwise-and (arithmetic-shift crc 1) mask))))))))))

(define (make-crc-params name width poly init refin refout xorout check)
  (define p (crc-params name width poly init refin refout xorout check #f))
  (if (< width 8)
      p
      (struct-copy crc-params p [table (build-table p)])))

;; Table-driven computation (width >= 8, table present).
(define (crc-compute/table p data)
  (define width (crc-params-width p))
  (define mask (crc-mask width))
  (define table (crc-params-table p))
  (define len (bytes-length data))
  (cond
    [(crc-params-refin p)
     (let loop ([i 0]
                [crc (crc-reflect (bitwise-and (crc-params-init p) mask) width)])
       (if (= i len)
           (crc-finish p crc)
           (loop (add1 i)
                 (bitwise-xor (arithmetic-shift crc (- 8))
                              (vector-ref table
                                          (bitwise-and (bitwise-xor crc
                                                                    (bytes-ref data i))
                                                       #xFF))))))]
    [else
     (define shift (- width 8))
     (let loop ([i 0] [crc (bitwise-and (crc-params-init p) mask)])
       (if (= i len)
           (crc-finish p crc)
           (loop (add1 i)
                 (bitwise-xor (bitwise-and (arithmetic-shift crc 8) mask)
                              (vector-ref table
                                          (bitwise-xor (bitwise-and (arithmetic-shift crc (- shift)) #xFF)
                                                       (bytes-ref data i)))))))]))

(define (crc-compute p data)
  (if (crc-params-table p)
      (crc-compute/table p data)
      (crc-compute/bits p data)))

;; Big-endian digest of the minimal whole bytes needed for the width.
(define (crc-digest p data)
  (define value (crc-compute p data))
  (define nbytes (ceiling (/ (crc-params-width p) 8)))
  (let loop ([n nbytes] [v value] [acc '()])
    (if (zero? n)
        (list->bytes acc)
        (loop (sub1 n)
              (arithmetic-shift v -8)
              (cons (bitwise-and v #xFF) acc)))))
