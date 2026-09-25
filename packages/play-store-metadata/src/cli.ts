/**
 * Thin CLI wrapper around the pure API. Argument parsing and the check mode
 * are exported so both can be tested without executing a process.
 */

import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { isAbsolute, join, resolve } from "node:path";

import { playStoreListings } from "./metadata";
import {
  defaultOutputDirectory,
  generateListingFiles,
  type GenerationResult,
} from "./generate";

export interface CliOptions {
  readonly outputDirectory: string;
  readonly check: boolean;
}

export function parseCliArgs(argv: readonly string[]): CliOptions {
  let outputDirectory = defaultOutputDirectory;
  let check = false;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === undefined) {
      continue;
    }
    if (arg === "--check") {
      check = true;
      continue;
    }
    if (arg === "--out" || arg === "-o") {
      const value = argv[index + 1];
      if (value === undefined || value.startsWith("-")) {
        throw new Error(`Missing value for ${arg}.`);
      }
      outputDirectory = value;
      index += 1;
      continue;
    }
    if (arg.startsWith("--out=")) {
      outputDirectory = arg.slice("--out=".length);
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (outputDirectory.trim().length === 0) {
    throw new Error("Output directory must not be empty.");
  }
  return { outputDirectory, check };
}

/**
 * Resolves a relative `--out` against the directory the CLI was invoked from,
 * so a root-level `bun run aso:generate --out build/play-store` writes where
 * the caller expects.
 */
export function resolveOutputDirectory(
  outputDirectory: string,
  workingDirectory: string = process.cwd(),
): string {
  return isAbsolute(outputDirectory)
    ? outputDirectory
    : resolve(workingDirectory, outputDirectory);
}

export async function runMetadataCli(
  argv: readonly string[],
): Promise<GenerationResult> {
  const { outputDirectory } = parseCliArgs(argv);
  return generateListingFiles(
    playStoreListings,
    resolveOutputDirectory(outputDirectory),
  );
}

/**
 * Regenerates the metadata into a throwaway temporary directory so the check
 * is deterministic and never leaves a tracked file behind.
 */
export async function runMetadataCheck(
  listings: readonly (typeof playStoreListings)[number][] = playStoreListings,
): Promise<number> {
  const scratch = await mkdtemp(join(tmpdir(), "play-store-metadata-check-"));
  try {
    const result = await generateListingFiles(listings, scratch);
    return result.writtenPaths.length;
  } finally {
    await rm(scratch, { recursive: true, force: true });
  }
}

if (import.meta.main) {
  try {
    const { check } = parseCliArgs(process.argv.slice(2));
    if (check) {
      const count = await runMetadataCheck();
      console.log(`Play Store metadata check passed (${count} files planned).`);
    } else {
      const result = await runMetadataCli(process.argv.slice(2));
      console.log(
        `Wrote ${result.writtenPaths.length} Play Store metadata files to ${result.outputDirectory}`,
      );
    }
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}
