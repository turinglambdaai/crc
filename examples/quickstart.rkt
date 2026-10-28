#lang racket/base
;; Tested quickstart for the public crc collection; no files, network or hardware.
(require crc)

(define data #"123456789")
(define crc32 (crc-compute crc-32 data))
(unless (= crc32 #xCBF43926)
  (error 'crc-quickstart "CRC-32 check vector failed: ~x" crc32))

(define raw (crc-extend crc-32 (crc-begin crc-32) #"1234"))
(unless (= (crc-result crc-32 (crc-extend crc-32 raw #"56789")) crc32)
  (error 'crc-quickstart "incremental result differs from one-shot"))
(unless (= (crc-input-port crc-32 (open-input-bytes data)) crc32)
  (error 'crc-quickstart "input port result differs from one-shot"))

;; CRC-16/GENIBUS: poly, init, refin, refout, xorout, check.
(define genibus
  (make-crc-params 'crc-16/genibus 16 #x1021 #xFFFF #f #f #xFFFF #xD64E))
(unless (= (crc-compute genibus data) #xD64E)
  (error 'crc-quickstart "custom GENIBUS check vector failed"))

(displayln "CRC quickstart OK")
