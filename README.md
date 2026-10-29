# crc — CRC catalogue and engine for automotive and embedded use, in pure Racket

**English** · [中文](README.zh-CN.md)

[![CI](https://github.com/turlamai/crc/actions/workflows/ci.yml/badge.svg)](https://github.com/turlamai/crc/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`crc` is a generic CRC engine (any width from 1 to 64 bits, with or without
input/output reflection and final XOR) plus a catalogue of **21 ready-made
parameter sets** weighted towards automotive and embedded use:

- classic CAN (`CRC-15/CAN`) and CAN FD frame CRCs (`CRC-17/CAN-FD`,
  `CRC-21/CAN-FD`)
- AUTOSAR E2E profiles (`CRC-8/AUTOSAR`, `CRC-32/AUTOSAR`) and SAE J1850
- the usual general-purpose ones: `CRC-32`, `CRC-32C`, `CRC-16/MODBUS`,
  `CRC-16/X-25`, `CRC-16/CCITT-FALSE`, …

Names, parameters and check values follow the public
[RevEng CRC catalogue](https://reveng.sourceforge.io/crc-catalogue/all.htm);
every preset's check value — the CRC of `"123456789"` — is asserted by the
test suite, and the table-driven engine is cross-checked against a
table-free bitwise reference on every preset.

There is no FFI and no system dependency.

## Installation

```
raco pkg install crc
```

## Usage

```racket
(require crc)

(crc-compute crc-32 #"123456789")      ; => #xcbf43926
(crc-compute crc-15/can #"123456789")  ; => #x59e
(crc-digest crc-16/modbus #"payload")  ; => big-endian bytes

;; incremental computation (raw register; store/resume freely)
(define reg (crc-extend crc-32 (crc-begin crc-32) #"first chunk"))
(set! reg (crc-extend crc-32 reg #"second chunk"))
(crc-result crc-32 reg)                ; => same as one-shot over both

;; streaming from a port (64 KiB chunks)
(crc-input-port crc-32 (open-input-bytes #"123456789")) ; => #xcbf43926

;; custom algorithms
(define p (make-crc-params 'crc-16/genibus 16 #x1021 #xFFFF #f #f #xFFFF #xD64E))
(crc-compute p #"123456789")            ; => #xd64e
```

`crc-by-name` looks presets up by symbol, and `all-crcs` lists the whole
catalogue.

## Performance

Reflected 32-bit algorithms (`crc-32`, `crc-32c`) run a slicing-by-8
fixnum kernel; other byte-aligned widths use a per-byte lookup table. Throughput depends on Racket version, input size and hardware; benchmark your actual workload.

## Notes

- Byte-aligned widths (8+) use a 256-entry lookup table per algorithm;
  narrower widths (and the exported `crc-compute/bitwise`) use the bitwise
  reference loop.
- `poly`/`init` are always given in normal (unreflected) form, exactly as the
  catalogue writes them; `refin`/`refout` control the reflection.
- Non-catalogued widths are supported: `make-crc-params` accepts any width
  from 1 to 64 and a bit-by-bit path handles the sub-byte ones.


## API documentation and development

The [Scribble API reference](crc/scribblings/crc.scrbl) defines all presets,
contracts, parameter meanings, error behavior, incremental registers and
streaming. A checked, standalone [quickstart](examples/quickstart.rkt) covers
CRC-32, chunked input, streams and a custom CRC-16/GENIBUS configuration.
There is no hardware or network access in the example.

From a local checkout (Racket and its `raco` tools installed):

```sh
raco pkg install --auto --link "$(pwd)"
raco test -p crc
racket examples/quickstart.rkt
raco setup --check-pkg-deps -l crc
```

The package's `info.rkt` declares a multi-collection layout; the public
`crc` collection registers its Scribble manual in `crc/info.rkt`.
CI runs these checks on Linux, macOS and Windows. Report problems in
[GitHub Issues](https://github.com/turlamai/crc/issues), with a small
reproducer and the Racket version.

## License

[MIT](LICENSE)
