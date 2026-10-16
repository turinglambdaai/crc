# AGENTS.md

纯 Racket 的 CRC 目录与引擎，面向汽车与嵌入式场景（MIT，已上架 Racket catalog）。

## 结构

Multi-collection 包：collection 即 `crc/` 子目录，scribblings 声明在 `crc/info.rkt`（collection 级）——改包结构勿破坏这条，否则 catalog 会标 needs-documentation。测试随包内 `rackunit`。

## 常用命令

```bash
raco pkg install --auto --link "$(pwd)"
raco test -p crc
```

## 验证与发版

- CI（`ci.yml`）：即上面两条命令，三平台跑。
- 发版 = tag `v<版本>` + CHANGELOG 同步；catalog 侧为手动提交（pkgd）。
