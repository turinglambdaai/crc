# crc — CRC catalogue and engine for automotive and embedded use, in pure Racket

[English](README.md) · **中文**

[![CI](https://github.com/turinglambdaai/crc/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/crc/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`crc` 是一个通用 CRC 引擎（宽度 1 到 64 位任意，支持或不支持输入/输出反射与最终 XOR），并附带一份收录 **21 组现成参数集** 的目录，偏重汽车与嵌入式应用：

- 经典 CAN（`CRC-15/CAN`）与 CAN FD 帧 CRC（`CRC-17/CAN-FD`、`CRC-21/CAN-FD`）
- AUTOSAR E2E profile（`CRC-8/AUTOSAR`、`CRC-32/AUTOSAR`）与 SAE J1850
- 常见通用算法：`CRC-32`、`CRC-32C`、`CRC-16/MODBUS`、`CRC-16/X-25`、`CRC-16/CCITT-FALSE`……

名称、参数与校验值遵循公开的 [RevEng CRC 目录](https://reveng.sourceforge.io/crc-catalogue/all.htm)；每个预设的校验值——即 `"123456789"` 的 CRC——都由测试套件断言，且表驱动引擎会在每个预设上对照无表逐位参考实现进行交叉验证。

没有 FFI，也没有系统依赖。

## 安装

```
raco pkg install crc
```

## 用法

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

`crc-by-name` 按符号查找预设，`all-crcs` 列出整个目录。

## 性能

反射型 32 位算法（`crc-32`、`crc-32c`）运行 slicing-by-8 的 fixnum 内核；其他字节对齐宽度使用逐字节查找表。吞吐量取决于 Racket 版本、输入规模与硬件；性能应以目标环境的实际基准测试为准。

## 说明

- 字节对齐宽度（8 及以上）为每个算法使用一张 256 项查找表；更窄的宽度（以及导出的 `crc-compute/bitwise`）使用逐位参考循环。
- `poly`/`init` 始终以正常（未反射）形式给出，与目录中的写法完全一致；`refin`/`refout` 控制反射。
- 支持目录之外的宽度：`make-crc-params` 接受 1 到 64 的任意宽度，子字节宽度由逐位路径处理。


## API 文档与开发

完整的参数、契约、错误语义、增量寄存器和流式处理请查阅
[Scribble API 文档](crc/scribblings/crc.scrbl)。独立的
[可执行入门示例](examples/quickstart.rkt)验证 CRC-32、分块计算、
输入端口和自定义 CRC-16/GENIBUS 参数；示例不访问网络或硬件。

在本地检出的仓库根目录（先安装 Racket 及 `raco`）运行：

```sh
raco pkg install --auto --link "$(pwd)"
raco test -p crc
racket examples/quickstart.rkt
raco setup --check-pkg-deps -l crc
```

本项目是 multi-collection package；`crc/info.rkt` 注册
`crc` collection 的 Scribble 文档。CI 在 Linux、macOS、Windows
执行这些检查。反馈请在 [GitHub Issues](https://github.com/turinglambdaai/crc/issues)
附最小复现、Racket 版本及实际输出。

## 许可证

[MIT](LICENSE)
