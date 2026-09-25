/**
 * Deterministic Play-ready text file generation.
 *
 * The pure planning step is kept separate from the filesystem work so both can
 * be tested independently. Every path is validated and the whole destination is
 * inventoried before the first canonical file is written.
 */

import { constants } from "node:fs";
import { lstat, mkdir, open, readdir } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";

import {
  metadataFieldNames,
  supportedLocales,
  type PlayStoreListing,
} from "./metadata";
import { assertValidMetadata } from "./validate";

export const generatedFileNames: Record<
  (typeof metadataFieldNames)[number],
  string
> = {
  title: "title.txt",
  shortDescription: "short-description.txt",
  fullDescription: "full-description.txt",
};

export const defaultOutputDirectory = resolve(import.meta.dir, "..", "dist");

/** `O_NOFOLLOW` is present on the macOS and Linux targets this CLI supports. */
const noFollow = constants.O_NOFOLLOW ?? 0;

export interface PlannedFile {
  readonly locale: string;
  readonly fileName: string;
  /** Text file content, newline-terminated for POSIX friendliness. */
  readonly content: string;
}

export function planListingFiles(
  listings: readonly PlayStoreListing[],
): PlannedFile[] {
  assertValidMetadata(listings);
  const ordered = [...listings].sort(
    (a, b) =>
      supportedLocales.indexOf(a.locale) - supportedLocales.indexOf(b.locale),
  );
  const planned: PlannedFile[] = [];
  for (const listing of ordered) {
    for (const field of metadataFieldNames) {
      planned.push({
        locale: listing.locale,
        fileName: generatedFileNames[field],
        content: `${listing[field]}\n`,
      });
    }
  }
  return planned;
}

export interface GenerationResult {
  readonly outputDirectory: string;
  readonly writtenPaths: readonly string[];
}

/**
 * Resolves one output path and proves it stays inside `root`. The requested
 * root itself is caller-selected, but no descendant may escape it.
 */
export function resolveListingPath(
  root: string,
  locale: string,
  fileName: string,
): string {
  const localeDirectory = resolve(root, locale);
  const relativeLocale = relative(root, localeDirectory);
  const escapesRoot =
    relativeLocale === "" ||
    relativeLocale === ".." ||
    relativeLocale.startsWith(`..${sep}`) ||
    isAbsolute(relativeLocale);

  if (escapesRoot) {
    throw new Error(
      `Refusing to write outside ${root}: locale "${locale}" escapes the output directory.`,
    );
  }

  const target = resolve(localeDirectory, fileName);
  if (dirname(target) !== localeDirectory) {
    throw new Error(
      `Refusing to write outside ${localeDirectory}: file "${fileName}" escapes the locale directory.`,
    );
  }
  return target;
}

async function pathKind(
  path: string,
): Promise<"missing" | "file" | "dir" | "link"> {
  try {
    const stats = await lstat(path);
    if (stats.isSymbolicLink()) {
      return "link";
    }
    return stats.isDirectory() ? "dir" : "file";
  } catch (error) {
    if (
      typeof error === "object" &&
      error !== null &&
      (error as NodeJS.ErrnoException).code === "ENOENT"
    ) {
      return "missing";
    }
    throw error;
  }
}

export interface InventoryEntry {
  readonly locale: string;
  readonly fileName: string;
}

export function expectedInventory(
  listings: readonly PlayStoreListing[],
): InventoryEntry[] {
  return planListingFiles(listings).map((file) => ({
    locale: file.locale,
    fileName: file.fileName,
  }));
}

/**
 * Fail-closed inventory of the destination. Every entry under the root must be
 * a current locale directory holding only the current generated file names.
 * Anything else (a stale locale, a stale file, a symlink) is reported and
 * nothing is written, so old output is never silently kept or deleted.
 */
export async function assertCleanOutputDirectory(
  root: string,
  listings: readonly PlayStoreListing[],
): Promise<void> {
  const expectedLocales = new Set<string>(
    listings.map((listing) => listing.locale),
  );
  const expectedFileNames = new Set<string>(
    metadataFieldNames.map((field) => generatedFileNames[field]),
  );

  const problems: string[] = [];
  const rootKind = await pathKind(root);
  if (rootKind === "missing") {
    return;
  }
  if (rootKind !== "dir" && rootKind !== "link") {
    throw new Error(
      `Output path ${root} exists but is not a directory. Choose an empty directory.`,
    );
  }

  // The root itself is caller-selected, so a symlinked root is honoured, but
  // nothing below it may be a symlink.
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const entryPath = resolve(root, entry.name);

    if (entry.isSymbolicLink()) {
      problems.push(`symlinked entry ${relative(root, entryPath)}`);
      continue;
    }
    if (!expectedLocales.has(entry.name)) {
      problems.push(`unknown locale directory ${relative(root, entryPath)}`);
      continue;
    }
    if (!entry.isDirectory()) {
      problems.push(
        `locale entry is not a directory ${relative(root, entryPath)}`,
      );
      continue;
    }

    for (const child of await readdir(entryPath, { withFileTypes: true })) {
      const childPath = resolve(entryPath, child.name);
      if (child.isSymbolicLink()) {
        problems.push(`symlinked entry ${relative(root, childPath)}`);
        continue;
      }
      if (!child.isFile()) {
        problems.push(`unexpected non-file entry ${relative(root, childPath)}`);
        continue;
      }
      if (!expectedFileNames.has(child.name)) {
        problems.push(`unknown or stale file ${relative(root, childPath)}`);
      }
    }
  }

  if (problems.length > 0) {
    throw new Error(
      `Output directory ${root} contains entries that are not current Play Store metadata output:\n${problems
        .sort()
        .map((problem) => `  - ${problem}`)
        .join(
          "\n",
        )}\nRemove them, or run with --out pointing at an empty directory. Nothing was deleted or overwritten.`,
    );
  }
}

/**
 * Writes the planned files under `outputDirectory`. All listings are validated
 * and all paths resolved and inventoried before the first file is created, so a
 * bad claim, a traversal, a symlink, or stale output leaves the directory
 * untouched.
 */
export async function generateListingFiles(
  listings: readonly PlayStoreListing[],
  outputDirectory: string,
): Promise<GenerationResult> {
  const planned = planListingFiles(listings);
  const root = resolve(outputDirectory);
  const targets = planned.map((file) => ({
    file,
    target: resolveListingPath(root, file.locale, file.fileName),
  }));

  await assertCleanOutputDirectory(root, listings);

  for (const { file, target } of targets) {
    const localeDirectory = dirname(target);
    if ((await pathKind(localeDirectory)) === "link") {
      throw new Error(
        `Refusing to write through the symlinked directory ${localeDirectory}.`,
      );
    }
    await mkdir(localeDirectory, { recursive: true });

    const handle = await open(
      target,
      constants.O_WRONLY | constants.O_CREAT | constants.O_TRUNC | noFollow,
    );
    try {
      await handle.writeFile(file.content, "utf8");
    } finally {
      await handle.close();
    }
  }

  return {
    outputDirectory: root,
    writtenPaths: targets.map((entry) => entry.target),
  };
}
