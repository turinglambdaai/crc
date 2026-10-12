#lang racket/base

;; Generic CRC engine: any width 1-64, with or without input/output
;; reflection and final XOR.  Reflected 32-bit CRCs (CRC-32, CRC-32C) run a
;; slicing-by-8 kernel; other byte-aligned widths use a 256-entry lookup
;; table; narrower widths fall back to a bit-by-bit loop.  Algorithm and
;; terminology follow the public CRC catalogue
;; (https://reveng.sourceforge.io/crc-catalogue/).
;;
;; Incremental use: (crc-begin p) starts a raw register, (crc-extend p reg
;; data) folds data in, (crc-result p reg) applies refout/xorout.  The
;; registers are plain integers, so state can be stored, compared and
;; resumed at will.

(require racket/contract
         racket/require
         (only-in racket/fixnum fxvector make-fxvector for/fxvector)
         racket/performance-hint
         (for-syntax racket/base)
         (filtered-in (lambda (name)
                        (regexp-replace #rx"unsafe-" name ""))
                      racket/unsafe/ops))

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
          [crc-begin (-> crc-params? exact-nonnegative-integer?)]
          [crc-extend (->* (crc-params? exact-nonnegative-integer? bytes?)
                           (exact-nonnegative-integer? exact-nonnegative-integer?)
                           exact-nonnegative-integer?)]
          [crc-result (-> crc-params? exact-nonnegative-integer?
                          exact-nonnegative-integer?)]
          [crc-input-port (->* (crc-params?) ((or/c input-port? #f))
                               exact-nonnegative-integer?)]
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

;; ---------------------------------------------------------------------------
;; Slicing-by-8 kernel for reflected 32-bit CRCs (CRC-32, CRC-32C, ...).
;;
;; T_k[i] applies the base-table shift k more times, so eight input bytes
;; are folded with eight table lookups instead of eight sequential
;; single-byte updates.  Tables are derived parametrically from the base
;; table, so any reflected 32-bit polynomial gets the fast path.

(define slicing-tables-cache (make-weak-hash))

(define (make-slicing-table base prev)
  (define t (make-fxvector 256 0))
  (for ([n (in-range 256)])
    (define c (fxvector-ref prev n))
    (fxvector-set! t n
                   (fxxor (fxvector-ref base (fxand c #xFF))
                          (fxrshift c 8))))
  t)

;; Returns (vector base t1 ... t7) as fixvectors.
(define (slicing-tables p)
  (hash-ref! slicing-tables-cache p
             (lambda ()
               (define base
                 (for/fxvector #:length 256 ([v (in-vector (crc-params-table p))])
                   v))
               (let loop ([prev base] [acc (list base)] [n 1])
                 (if (= n 8)
                     (list->vector (reverse acc))
                     (let ([t (make-slicing-table base prev)])
                       (loop t (cons t acc) (add1 n))))))))

(define-inline (crc32-update-byte base acc byte)
  (fxxor (fxrshift acc 8)
         (fxvector-ref base (fxand (fxxor acc byte) #xFF))))

;; Fold bs[start, end) into the raw register: slicing-by-8 blocks plus a
;; byte tail.
(define (fold-slicing tables bs start end reg)
  (define base (vector-ref tables 0))
  (let loop ([i start] [acc (fxand reg #xFFFFFFFF)])
    (cond
      [(fx<= (fx+ i 8) end)
       (let* ([b0 (bytes-ref bs i)]
              [b1 (bytes-ref bs (fx+ i 1))]
              [b2 (bytes-ref bs (fx+ i 2))]
              [b3 (bytes-ref bs (fx+ i 3))]
              [b4 (bytes-ref bs (fx+ i 4))]
              [b5 (bytes-ref bs (fx+ i 5))]
              [b6 (bytes-ref bs (fx+ i 6))]
              [b7 (bytes-ref bs (fx+ i 7))]
              [one (fxxor acc b0
                          (fxlshift b1 8)
                          (fxlshift b2 16)
                          (fxlshift b3 24))]
              [two (fxxor b4
                          (fxlshift b5 8)
                          (fxlshift b6 16)
                          (fxlshift b7 24))])
         (loop (fx+ i 8)
               (fxxor
                (fxvector-ref (vector-ref tables 7) (fxand one #xFF))
                (fxvector-ref (vector-ref tables 6) (fxand (fxrshift one 8) #xFF))
                (fxvector-ref (vector-ref tables 5) (fxand (fxrshift one 16) #xFF))
                (fxvector-ref (vector-ref tables 4) (fxrshift one 24))
                (fxvector-ref (vector-ref tables 3) (fxand two #xFF))
                (fxvector-ref (vector-ref tables 2) (fxand (fxrshift two 8) #xFF))
                (fxvector-ref (vector-ref tables 1) (fxand (fxrshift two 16) #xFF))
                (fxvector-ref (vector-ref tables 0) (fxrshift two 24)))))]
      [(fx< i end)
       (loop (fx+ i 1) (crc32-update-byte base acc (bytes-ref bs i)))]
      [else acc])))

;; ---------------------------------------------------------------------------
;; Register-level incremental core (no refout/xorout applied)

(define (crc-begin p)
  (define width (crc-params-width p))
  (define mask (crc-mask width))
  (if (crc-params-refin p)
      (crc-reflect (bitwise-and (crc-params-init p) mask) width)
      (bitwise-and (crc-params-init p) mask)))

(define (extend-table p reg bs start end)
  (define width (crc-params-width p))
  (define mask (crc-mask width))
  (define table (crc-params-table p))
  (if (crc-params-refin p)
      (let loop ([i start] [crc reg])
        (if (= i end)
            crc
            (loop (add1 i)
                  (bitwise-xor (arithmetic-shift crc (- 8))
                               (vector-ref table
                                           (bitwise-and (bitwise-xor crc
                                                                      (bytes-ref bs i))
                                                        #xFF))))))
      (let loop ([i start] [crc reg])
        (if (= i end)
            crc
            (loop (add1 i)
                  (bitwise-xor (bitwise-and (arithmetic-shift crc 8) mask)
                               (vector-ref table
                                           (bitwise-xor (bitwise-and (arithmetic-shift crc (- (- width 8))) #xFF)
                                                        (bytes-ref bs i)))))))))

(define (extend-bits p reg bs start end)
  (define width (crc-params-width p))
  (define mask (crc-mask width))
  (define poly (crc-params-poly p))
  (define rpoly (crc-reflect poly width))
  (for/fold ([crc reg])
            ([byte (in-bytes bs start end)])
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

;; Fold `data[start,end)` into the raw register `reg`.
(define (crc-extend p reg data [start 0] [end (bytes-length data)])
  (cond
    [(and (= (crc-params-width p) 32) (crc-params-refin p))
     (define acc (fold-slicing (slicing-tables p) data start end reg))
     (bitwise-and acc #xFFFFFFFF)]
    [(crc-params-table p)
     (extend-table p reg data start end)]
    [else
     (extend-bits p reg data start end)]))

(define (crc-result p reg) (crc-finish p reg))

;; ---------------------------------------------------------------------------
;; One-shot conveniences

(define (crc-compute p data)
  (crc-result p (crc-extend p (crc-begin p) data)))

(define (crc-input-port p [in (current-input-port)])
  (define port (or in (current-input-port)))
  (define buf (make-bytes 65536))
  (let loop ([reg (crc-begin p)])
    (define n (read-bytes-avail! buf port))
    (if (and (exact-integer? n) (> n 0))
        (loop (crc-extend p reg buf 0 n))
        (crc-result p reg))))

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

;; ---------------------------------------------------------------------------
;; Table-free reference implementation (width >= 8); kept as the
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

;; ---------------------------------------------------------------------------
;; Table build

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
