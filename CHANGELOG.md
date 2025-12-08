# qbic-pipelines/vcftomaf: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.3.0dev

### `Added`

- [#36](https://github.com/qbic-pipelines/vcftomaf/pull/36) - Swap pipeline tests to nf-test (@famosab)

### `Fixed`

- [#34](https://github.com/qbic-pipelines/vcftomaf/pull/34) - Update vcf2maf configuration to adhere to hg38 as reference genome (@famosab)
- [#35](https://github.com/qbic-pipelines/vcftomaf/pull/35) - Template update to 3.2.0 (@famosab)
- [#37](https://github.com/qbic-pipelines/vcftomaf/pull/37) - Template update to 3.2.1 (@famosab)
- [#38](https://github.com/qbic-pipelines/vcftomaf/pull/38) - Template update to 3.5.1 (@famosab)

### `Dependencies`

| Dependency | Old version | New version |
| ---------- | ----------- | ----------- |
| MultiQC    | 1.25.1      | 1.32        |

### `Deprecated`

## v1.2.0 - 15-01-2024 - Burgundy Piglet

### `Added`

- [#24](https://github.com/qbic-pipelines/vcftomaf/pull/24) - Enable VEP annotation with vcf2maf module (@famosab)

### `Fixed`

- [#25](https://github.com/qbic-pipelines/vcftomaf/pull/25) - Template update to 3.1.1 (@famosab)

### `Dependencies`

### `Deprecated`

## v1.1.0 - 25-11-2024 - Amaranth Filly

### `Added`

- [#11](https://github.com/qbic-pipelines/vcftomaf/pull/11) - Add metromap (@FriederikeHanssen)
- [#18](https://github.com/qbic-pipelines/vcftomaf/pull/18) - Add options to enable filtering by `PASS` via `--filter`, filtering was default in previous version (@famosab)

### `Fixed`

- [#16](https://github.com/qbic-pipelines/vcftomaf/pull/16) - Template update to 3.0.2 (@famosab)
- [#17](https://github.com/qbic-pipelines/vcftomaf/pull/17) - Update all modules (@famosab)
- [#20](https://github.com/qbic-pipelines/vcftomaf/pull/20) - Update subworkflows (@famosab)

### `Dependencies`

### `Deprecated`

Thanks to @d4straub for reviews.

## v1.0.0 - 13-03-2024 - Plum Puppy

Initial release of qbic-pipelines/vcftomaf, created with the [nf-core](https://nf-co.re/) template, written by @SusiJo and @FriederikeHanssen.
