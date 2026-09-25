# @collection-book/play-store-metadata

Canonical Google Play Store listing text for the Collection Book Android app,
plus a dependency-light Bun CLI that validates the text and emits Play-ready
files.

## Source of truth

`src/metadata.ts` holds every localized listing. Each entry declares a `title`
(maximum 30 Unicode code points), a `shortDescription` (maximum 80), and a
`fullDescription` (maximum 4000) for the five supported locales: `en-IN`,
`hi-IN`, `mr-IN`, `bn-IN`, and `ta-IN`.

Only implemented features may be claimed. `src/validate.ts` is the single gate:
it enforces the exact locale set, non-empty fields, the code-point limits, and
the claim policy in `src/claims.ts`. `assertValidMetadata` runs all of them, so
`planListingFiles`, `generateListingFiles`, and `--check` all reject a bad claim
or an over-long field before anything is written. `src/claims.ts` lists the
promises this app does not make (subscriber caps, free-forever plans, licensing
or paywalls, GST or legal invoices, automatic payment collection, cloud sync,
and uptime guarantees) plus a numeric cap guard that catches "up to N
subscribers"-style limits written with Latin, Devanagari, Bengali, or Tamil
digits.

The vernacular copy carries automated policy and terminology checks, including
regression assertions for known malformed tokens and for the required
`assets/i18n` vocabulary per locale. That is not a native-language editorial
review, and no native speaker or professional translator has approved the copy.

## API

| Module | Responsibility |
| --- | --- |
| `src/metadata.ts` | Locale list, field limits, field names, and the canonical listings |
| `src/validate.ts` | Pure locale, emptiness, code-point length, and claim validation |
| `src/claims.ts` | Pure unsupported-claim detection, including the numeric cap guard |
| `src/generate.ts` | Pure file planning plus the filesystem write, path-guarded to the requested root and inventoried fail-closed |
| `src/cli.ts` | Argument parsing, `--out` resolution, and the `--check` mode |

`src/index.ts` re-exports the public API so validation and generation can be
used without executing the CLI.

## Commands

From the repository root:

```sh
bun run aso:generate
bun run aso:generate --out build/play-store
bun run aso:check
```

`bun run aso:generate` writes `dist/<locale>/title.txt`,
`dist/<locale>/short-description.txt`, and `dist/<locale>/full-description.txt`
inside this package; `dist/` is git-ignored. Pass `--out <dir>` to write
elsewhere; a relative `--out` resolves against the directory the CLI was invoked
from.

Safety behaviour:

- The requested root is caller-selected, so a symlinked root is honoured, but a
  pre-existing symlinked locale directory or target file is refused. Files are
  opened with `O_NOFOLLOW` where the platform provides it.
- The destination is inventoried fail-closed. Only the current locale
  directories and the current generated file names are allowed. Anything else
  (stale locale directory, stale or unknown file, symlinked entry, stray entry)
  makes the run fail with the offending paths listed, and **nothing is deleted
  or overwritten**. Remove such entries by hand, or point `--out` at an empty
  directory. When a locale is removed from `supportedLocales`, its old directory
  must be deleted once before the next run succeeds.
- All listings are validated and all paths resolved and inventoried before the
  first canonical file is created.

`bun run aso:check` regenerates into a throwaway temporary directory so it
is deterministic and leaves no tracked change behind; it runs as part of
`bun run verify:bun`, which CI executes as the independent Bun gate.

Package-local equivalents:

```sh
bun run --cwd packages/play-store-metadata generate
bun run --cwd packages/play-store-metadata test
bun run --cwd packages/play-store-metadata typecheck
```

Generating files does not upload anything to Play Console.
