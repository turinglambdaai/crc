#lang scribble/doc

@(require scribble/manual
          (for-label crc
                     racket/base
                     racket/contract)
          scribble/example)

@(define crc-eval (make-base-eval #:lang 'racket/base '(require crc)))

@title{crc: CRC catalogue and engine for automotive and embedded use}
@author{@(author+email "turinglambdaai" "turinglambdaai@users.noreply.github.com")}

@defmodule[crc]

This package provides a generic CRC engine (any width from 1 to 64 bits,
with or without input/output reflection and final XOR) plus a catalogue of
@emph{21 ready-made parameter sets} weighted towards automotive and embedded
use: the CAN and CAN FD frame CRCs, AUTOSAR E2E profiles, SAE J1850, and the
usual general-purpose algorithms.

Parameters, names and check values follow the public
@hyperlink["https://reveng.sourceforge.io/crc-catalogue/all.htm"]{RevEng CRC
catalogue}; every catalogue entry's @tt{check} value — the CRC of the
9-byte ASCII string @litchar{123456789} — is asserted by the test suite, so
the engine and the presets cannot silently drift apart.

@section{Catalogue}

@defproc[(all-crcs) (listof crc-params?)]{

Every preset in the catalogue.
}

@defproc[(crc-by-name [name symbol?]) (or/c crc-params? #f)]{

Looks up a preset by name, e.g. @racket[(crc-by-name 'crc-15/can)].
}

The catalogue currently contains:

@tabular[
 (list (list @bold{Name} @bold{Width} @bold{Poly} @bold{Init} @bold{Refin} @bold{Refout} @bold{Xorout} @bold{Check})
       (list @tt{crc-8/smbus} "8" "0x07" "0x00" "no" "no" "0x00" "0xF4")
       (list @tt{crc-8/autosar} "8" "0x2F" "0xFF" "no" "no" "0xFF" "0xDF")
       (list @tt{crc-8/sae-j1850} "8" "0x1D" "0xFF" "no" "no" "0xFF" "0x4B")
       (list @tt{crc-8/maxim} "8" "0x31" "0x00" "yes" "yes" "0x00" "0xA1")
       (list @tt{crc-8/dvb-s2} "8" "0xD5" "0x00" "no" "no" "0x00" "0xBC")
       (list @tt{crc-8/rohc} "8" "0x07" "0xFF" "yes" "yes" "0x00" "0xD0")
       (list @tt{crc-8/itu} "8" "0x07" "0x00" "no" "no" "0x55" "0xA1")
       (list @tt{crc-15/can} "15" "0x4599" "0x0000" "no" "no" "0x0000" "0x059E")
       (list @tt{crc-16/ccitt-false} "16" "0x1021" "0xFFFF" "no" "no" "0x0000" "0x29B1")
       (list @tt{crc-16/xmodem} "16" "0x1021" "0x0000" "no" "no" "0x0000" "0x31C3")
       (list @tt{crc-16/kermit} "16" "0x1021" "0x0000" "yes" "yes" "0x0000" "0x2189")
       (list @tt{crc-16/modbus} "16" "0x8005" "0xFFFF" "yes" "yes" "0x0000" "0x4B37")
       (list @tt{crc-16/usb} "16" "0x8005" "0xFFFF" "yes" "yes" "0xFFFF" "0xB4C8")
       (list @tt{crc-16/x-25} "16" "0x1021" "0xFFFF" "yes" "yes" "0xFFFF" "0x906E")
       (list @tt{crc-16/genibus} "16" "0x1021" "0xFFFF" "no" "no" "0xFFFF" "0xD64E")
       (list @tt{crc-17/can-fd} "17" "0x1685B" "0x00000" "no" "no" "0x00000" "0x04F03")
       (list @tt{crc-21/can-fd} "21" "0x102899" "0x000000" "no" "no" "0x000000" "0x0ED841")
       (list @tt{crc-32} "32" "0x04C11DB7" "0xFFFFFFFF" "yes" "yes" "0xFFFFFFFF" "0xCBF43926")
       (list @tt{crc-32/bzip2} "32" "0x04C11DB7" "0xFFFFFFFF" "no" "no" "0xFFFFFFFF" "0xFC891918")
       (list @tt{crc-32c} "32" "0x1EDC6F41" "0xFFFFFFFF" "yes" "yes" "0xFFFFFFFF" "0xE3069283")
       (list @tt{crc-32/autosar} "32" "0xF4ACFB13" "0xFFFFFFFF" "yes" "yes" "0xFFFFFFFF" "0x1697D06A"))
]

Each preset is also exported as a binding of the same name
(@racket[crc-15/can], @racket[crc-32], …).

@section{Engine}

@defstruct*[crc-params ([name symbol?]
                        [width (integer-in 1 64)]
                        [poly exact-nonnegative-integer?]
                        [init exact-nonnegative-integer?]
                        [refin boolean?]
                        [refout boolean?]
                        [xorout exact-nonnegative-integer?]
                        [check exact-nonnegative-integer?]
                        [table (or/c #f (vectorof exact-nonnegative-integer?))])]{

One CRC algorithm definition.  @racket[poly] and @racket[init] are in normal
(unreflected) form, exactly as the catalogue writes them.  @racket[table] is
an internal lookup cache for byte-aligned widths; leave it alone.
}

@defproc[(make-crc-params [name symbol?]
                          [width (integer-in 1 64)]
                          [poly exact-nonnegative-integer?]
                          [init exact-nonnegative-integer?]
                          [refin boolean?]
                          [refout boolean?]
                          [xorout exact-nonnegative-integer?]
                          [check exact-nonnegative-integer?])
         crc-params?]{

Defines a custom algorithm.  @racket[check] should be the CRC of
@litchar{123456789}; the test suite treats catalogue check values as golden
vectors, and your own values can be asserted the same way.
}

@defproc[(crc-compute [p crc-params?] [data bytes?]) exact-nonnegative-integer?]{

Computes the CRC of @racket[data] as an integer no larger than
@racket[(sub1 (expt 2 (crc-params-width p)))].
}

@defproc[(crc-begin [p crc-params?]) exact-nonnegative-integer?]{

Starts an incremental computation: returns the raw CRC register (init in
working order, before any output transformation).
}

@defproc[(crc-extend [p crc-params?]
                     [reg exact-nonnegative-integer?]
                     [data bytes?]
                     [start exact-nonnegative-integer? 0]
                     [end exact-nonnegative-integer? (bytes-length data)])
         exact-nonnegative-integer?]{

Folds @tt{data[start,end)} into the raw register @racket[reg] and
returns the new register.  Registers are plain integers, so partial
computations can be stored and resumed freely.
}

@defproc[(crc-result [p crc-params?]
                     [reg exact-nonnegative-integer?])
         exact-nonnegative-integer?]{

Finishes an incremental computation: applies @racket[refout]/@racket[xorout]
and returns the final CRC value.
}

@defproc[(crc-input-port [p crc-params?]
                         [in (or/c input-port? #f)])
         exact-nonnegative-integer?]{

Computes the CRC of everything read from @racket[in] (default
@racket[(current-input-port)]), reading in 64 KiB chunks.
}

@defproc[(crc-digest [p crc-params?] [data bytes?]) bytes?]{

Computes the CRC and returns it as a big-endian byte string of the minimal
whole number of bytes needed for the width.
}

@defproc[(crc-reflect [value exact-nonnegative-integer?] [width (integer-in 1 64)])
         exact-nonnegative-integer?]{

Reverses the low @racket[width] bits of @racket[value].
}

@defproc[(crc-compute/bitwise [p crc-params?] [data bytes?])
         exact-nonnegative-integer?]{

The table-free reference implementation; byte-aligned widths normally take
the table path, so this serves as an independent cross-check in tests.
}

@section{Example}

The following examples are @emph{evaluated when Scribble builds the manual}, so
syntax and expected values cannot drift silently:

@examples[
#:eval crc-eval
(crc-compute crc-32 #"123456789")
(crc-compute crc-15/can #"123456789")
(define p (make-crc-params 'crc-16/genibus 16 #x1021 #xFFFF #f #f #xFFFF #xD64E))
(crc-compute p #"123456789")
]

Incremental and stream computation (also checked by the package's executable
quickstart and tests):

@examples[
#:eval crc-eval
(define reg (crc-extend crc-32 (crc-begin crc-32) #"1234"))
(crc-result crc-32 (crc-extend crc-32 reg #"56789"))
(crc-input-port crc-32 (open-input-bytes #"123456789"))
]

@section{Preset reference}

Every preset is a @racket[crc-params?] value, usable directly by the
engine or through @racket[crc-by-name].  The @tt{check} column of the
catalogue table above is each preset's self-test against
@racket[#"123456789"].

@defthing[crc-8/smbus crc-params?]{SMBus packet error detection.}
@defthing[crc-8/autosar crc-params?]{AUTOSAR E2E protection (profile 1).}
@defthing[crc-8/sae-j1850 crc-params?]{SAE J1850 automotive bus.}
@defthing[crc-8/maxim crc-params?]{Maxim 1-Wire devices (a reflected CRC-8).}
@defthing[crc-8/dvb-s2 crc-params?]{DVB-S2 baseband frames.}
@defthing[crc-8/rohc crc-params?]{Robust Header Compression (ROHC) FCS.}
@defthing[crc-8/itu crc-params?]{ITU-T I.363 ATM HEC.}
@defthing[crc-15/can crc-params?]{CAN frame CRC.}
@defthing[crc-16/ccitt-false crc-params?]{The classic CCITT-False variant.}
@defthing[crc-16/xmodem crc-params?]{XModem blocks (aka ZMODEM/V.41 CRC-16/AUG-CCITT family).}
@defthing[crc-16/kermit crc-params?]{Kermit file transfer (reflected CCITT).}
@defthing[crc-16/modbus crc-params?]{Modbus RTU frame check.}
@defthing[crc-16/usb crc-params?]{USB data packets.}
@defthing[crc-16/x-25 crc-params?]{X.25 HDLC FCS (aka PPP/Bluetooth).}
@defthing[crc-16/genibus crc-params?]{GENIbus (a GENI/automotive diagnostic variant).}
@defthing[crc-17/can-fd crc-params?]{CAN FD frame CRC (17-bit).}
@defthing[crc-21/can-fd crc-params?]{CAN FD frame CRC (21-bit).}
@defthing[crc-32 crc-params?]{The ubiquitous CRC-32 (Ethernet, zip, PNG).}
@defthing[crc-32/bzip2 crc-params?]{bzip2's non-reflected CRC-32.}
@defthing[crc-32c crc-params?]{Castagnoli CRC-32C (iSCSI, ext4, SSE 4.2).}
@defthing[crc-32/autosar crc-params?]{AUTOSAR E2E protection (profile 4/5).}

@section{Performance}

Reflected 32-bit algorithms (@racket[crc-32], @racket[crc-32c]) run a
slicing-by-8 kernel; other byte-aligned widths use a per-byte lookup table.
Throughput depends on Racket version, input size and hardware. Measure on the target workload before making performance commitments.

