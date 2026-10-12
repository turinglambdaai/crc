#lang racket/base

;; Catalogue of ready-made CRC parameters, weighted towards automotive and
;; embedded use: CAN and CAN FD frame CRCs, AUTOSAR E2E profiles, SAE J1850,
;; plus the usual general-purpose ones.  Names, parameters and check values
;; follow the public CRC catalogue (RevEng); every check value is the CRC of
;; the 9-byte ASCII string "123456789" and is asserted by the test suite.

(require racket/contract
         "engine.rkt")

(provide (contract-out
          [all-crcs (-> (listof crc-params?))]
          [crc-by-name (-> symbol? (or/c crc-params? #f))]
          (crc-8/smbus crc-params?)
          (crc-8/autosar crc-params?)
          (crc-8/sae-j1850 crc-params?)
          (crc-8/maxim crc-params?)
          (crc-8/dvb-s2 crc-params?)
          (crc-8/rohc crc-params?)
          (crc-8/itu crc-params?)
          (crc-15/can crc-params?)
          (crc-16/ccitt-false crc-params?)
          (crc-16/xmodem crc-params?)
          (crc-16/kermit crc-params?)
          (crc-16/modbus crc-params?)
          (crc-16/usb crc-params?)
          (crc-16/x-25 crc-params?)
          (crc-16/genibus crc-params?)
          (crc-17/can-fd crc-params?)
          (crc-21/can-fd crc-params?)
          (crc-32 crc-params?)
          (crc-32/bzip2 crc-params?)
          (crc-32c crc-params?)
          (crc-32/autosar crc-params?)))

(define crc-8/smbus      (make-crc-params 'crc-8/smbus       8 #x07       #x00       #f #f #x00       #xF4))
(define crc-8/autosar    (make-crc-params 'crc-8/autosar     8 #x2F       #xFF       #f #f #xFF       #xDF))
(define crc-8/sae-j1850  (make-crc-params 'crc-8/sae-j1850   8 #x1D       #xFF       #f #f #xFF       #x4B))
(define crc-8/maxim      (make-crc-params 'crc-8/maxim       8 #x31       #x00       #t #t #x00       #xA1))
(define crc-8/dvb-s2     (make-crc-params 'crc-8/dvb-s2      8 #xD5       #x00       #f #f #x00       #xBC))
(define crc-8/rohc       (make-crc-params 'crc-8/rohc        8 #x07       #xFF       #t #t #x00       #xD0))
(define crc-8/itu        (make-crc-params 'crc-8/itu         8 #x07       #x00       #f #f #x55       #xA1))

(define crc-15/can       (make-crc-params 'crc-15/can       15 #x4599     #x0000     #f #f #x0000     #x059E))

(define crc-16/ccitt-false (make-crc-params 'crc-16/ccitt-false 16 #x1021 #xFFFF #f #f #x0000 #x29B1))
(define crc-16/xmodem    (make-crc-params 'crc-16/xmodem    16 #x1021     #x0000     #f #f #x0000     #x31C3))
(define crc-16/kermit    (make-crc-params 'crc-16/kermit    16 #x1021     #x0000     #t #t #x0000     #x2189))
(define crc-16/modbus    (make-crc-params 'crc-16/modbus    16 #x8005     #xFFFF     #t #t #x0000     #x4B37))
(define crc-16/usb       (make-crc-params 'crc-16/usb       16 #x8005     #xFFFF     #t #t #xFFFF     #xB4C8))
(define crc-16/x-25      (make-crc-params 'crc-16/x-25      16 #x1021     #xFFFF     #t #t #xFFFF     #x906E))
(define crc-16/genibus   (make-crc-params 'crc-16/genibus   16 #x1021     #xFFFF     #f #f #xFFFF     #xD64E))

(define crc-17/can-fd    (make-crc-params 'crc-17/can-fd    17 #x1685B    #x00000    #f #f #x00000    #x04F03))
(define crc-21/can-fd    (make-crc-params 'crc-21/can-fd    21 #x102899   #x000000   #f #f #x000000   #x0ED841))

(define crc-32           (make-crc-params 'crc-32           32 #x04C11DB7 #xFFFFFFFF #t #t #xFFFFFFFF #xCBF43926))
(define crc-32/bzip2     (make-crc-params 'crc-32/bzip2     32 #x04C11DB7 #xFFFFFFFF #f #f #xFFFFFFFF #xFC891918))
(define crc-32c          (make-crc-params 'crc-32c          32 #x1EDC6F41 #xFFFFFFFF #t #t #xFFFFFFFF #xE3069283))
(define crc-32/autosar   (make-crc-params 'crc-32/autosar   32 #xF4ACFB13 #xFFFFFFFF #t #t #xFFFFFFFF #x1697D06A))

(define +catalog+
  (list crc-8/smbus crc-8/autosar crc-8/sae-j1850 crc-8/maxim crc-8/dvb-s2
        crc-8/rohc crc-8/itu
        crc-15/can
        crc-16/ccitt-false crc-16/xmodem crc-16/kermit crc-16/modbus
        crc-16/usb crc-16/x-25 crc-16/genibus
        crc-17/can-fd crc-21/can-fd
        crc-32 crc-32/bzip2 crc-32c crc-32/autosar))

(define (all-crcs) +catalog+)

(define (crc-by-name name)
  (for/first ([p (in-list +catalog+)]
              #:when (eq? (crc-params-name p) name))
    p))
