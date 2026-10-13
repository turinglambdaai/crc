2344
((3) 0 () 2 ((q lib "crc/main.rkt") (q 128 . 19)) () (h ! (equal) ((c def c (c (? . 0) q crc-32/bzip2)) q (2979 . 2)) ((c def c (c (? . 0) q crc-32/autosar)) q (3044 . 2)) ((c def c (c (? . 0) q crc-8/autosar)) q (2384 . 2)) ((c def c (c (? . 0) q crc-8/sae-j1850)) q (2420 . 2)) ((c def c (c (? . 0) q crc-15/can)) q (2592 . 2)) ((c def c (c (? . 0) q crc-params-init)) c (? . 1)) ((c def c (c (? . 0) q crc-32)) q (2950 . 2)) ((c def c (c (? . 0) q crc-extend)) q (1482 . 7)) ((c def c (c (? . 0) q crc-params-xorout)) c (? . 1)) ((c def c (c (? . 0) q crc-8/maxim)) q (2458 . 2)) ((c def c (c (? . 0) q make-crc-params)) q (734 . 17)) ((c def c (c (? . 0) q crc-params-width)) c (? . 1)) ((c def c (c (? . 0) q crc-params-refout)) c (? . 1)) ((c def c (c (? . 0) q crc-begin)) q (1403 . 3)) ((c def c (c (? . 0) q crc-params-poly)) c (? . 1)) ((c def c (c (? . 0) q crc-params)) c (? . 1)) ((c def c (c (? . 0) q crc-16/kermit)) q (2702 . 2)) ((c def c (c (? . 0) q crc-params-check)) c (? . 1)) ((c def c (c (? . 0) q crc-17/can-fd)) q (2878 . 2)) ((c def c (c (? . 0) q crc-compute)) q (1296 . 4)) ((c def c (c (? . 0) q crc-params-table)) c (? . 1)) ((c def c (c (? . 0) q crc-16/x-25)) q (2807 . 2)) ((c def c (c (? . 0) q crc-compute/bitwise)) q (2235 . 4)) ((c def c (c (? . 0) q crc-params?)) c (? . 1)) ((c def c (c (? . 0) q crc-16/usb)) q (2774 . 2)) ((c def c (c (? . 0) q crc-input-port)) q (1881 . 4)) ((c def c (c (? . 0) q crc-8/rohc)) q (2527 . 2)) ((c def c (c (? . 0) q struct:crc-params)) c (? . 1)) ((c def c (c (? . 0) q crc-16/ccitt-false)) q (2625 . 2)) ((c def c (c (? . 0) q crc-16/xmodem)) q (2666 . 2)) ((c def c (c (? . 0) q crc-params-refin)) c (? . 1)) ((c def c (c (? . 0) q crc-8/itu)) q (2560 . 2)) ((c def c (c (? . 0) q crc-8/smbus)) q (2350 . 2)) ((c def c (c (? . 0) q crc-by-name)) q (48 . 3)) ((c def c (c (? . 0) q crc-result)) q (1757 . 4)) ((c def c (c (? . 0) q crc-16/genibus)) q (2841 . 2)) ((c def c (c (? . 0) q crc-reflect)) q (2090 . 4)) ((c def c (c (? . 0) q crc-params-name)) c (? . 1)) ((c def c (c (? . 0) q crc-16/modbus)) q (2738 . 2)) ((c def c (c (? . 0) q crc-32c)) q (3014 . 2)) ((c def c (c (? . 0) q crc-digest)) q (2004 . 4)) ((c def c (c (? . 0) q all-crcs)) q (0 . 2)) ((c def c (c (? . 0) q crc-21/can-fd)) q (2914 . 2)) ((c def c (c (? . 0) q crc-8/dvb-s2)) q (2492 . 2))))
procedure
(all-crcs) -> (listof crc-params?)
procedure
(crc-by-name name) -> (or/c crc-params? #f)
  name : symbol?
struct
(struct crc-params (name
                    width
                    poly
                    init
                    refin
                    refout
                    xorout
                    check
                    table))
  name : symbol?
  width : (integer-in 1 64)
  poly : exact-nonnegative-integer?
  init : exact-nonnegative-integer?
  refin : boolean?
  refout : boolean?
  xorout : exact-nonnegative-integer?
  check : exact-nonnegative-integer?
  table : (or/c #f (vectorof exact-nonnegative-integer?))
procedure
(make-crc-params name       
                 width      
                 poly       
                 init       
                 refin      
                 refout     
                 xorout     
                 check) -> crc-params?
  name : symbol?
  width : (integer-in 1 64)
  poly : exact-nonnegative-integer?
  init : exact-nonnegative-integer?
  refin : boolean?
  refout : boolean?
  xorout : exact-nonnegative-integer?
  check : exact-nonnegative-integer?
procedure
(crc-compute p data) -> exact-nonnegative-integer?
  p : crc-params?
  data : bytes?
procedure
(crc-begin p) -> exact-nonnegative-integer?
  p : crc-params?
procedure
(crc-extend p reg data [start end]) -> exact-nonnegative-integer?
  p : crc-params?
  reg : exact-nonnegative-integer?
  data : bytes?
  start : exact-nonnegative-integer? = 0
  end : exact-nonnegative-integer? = (bytes-length data)
procedure
(crc-result p reg) -> exact-nonnegative-integer?
  p : crc-params?
  reg : exact-nonnegative-integer?
procedure
(crc-input-port p in) -> exact-nonnegative-integer?
  p : crc-params?
  in : (or/c input-port? #f)
procedure
(crc-digest p data) -> bytes?
  p : crc-params?
  data : bytes?
procedure
(crc-reflect value width) -> exact-nonnegative-integer?
  value : exact-nonnegative-integer?
  width : (integer-in 1 64)
procedure
(crc-compute/bitwise p data) -> exact-nonnegative-integer?
  p : crc-params?
  data : bytes?
value
crc-8/smbus : crc-params?
value
crc-8/autosar : crc-params?
value
crc-8/sae-j1850 : crc-params?
value
crc-8/maxim : crc-params?
value
crc-8/dvb-s2 : crc-params?
value
crc-8/rohc : crc-params?
value
crc-8/itu : crc-params?
value
crc-15/can : crc-params?
value
crc-16/ccitt-false : crc-params?
value
crc-16/xmodem : crc-params?
value
crc-16/kermit : crc-params?
value
crc-16/modbus : crc-params?
value
crc-16/usb : crc-params?
value
crc-16/x-25 : crc-params?
value
crc-16/genibus : crc-params?
value
crc-17/can-fd : crc-params?
value
crc-21/can-fd : crc-params?
value
crc-32 : crc-params?
value
crc-32/bzip2 : crc-params?
value
crc-32c : crc-params?
value
crc-32/autosar : crc-params?
