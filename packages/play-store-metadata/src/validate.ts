/**
 * Deterministic validation of the canonical Play Store listing metadata.
 *
 * Structural checks (locale set, emptiness, code-point limits) and claim checks
 * both run here, so the single `assertValidMetadata` used by planning,
 * generation, and `--check` rejects an unsupported promise before anything is
 * written. Kept free of filesystem and process concerns so it stays testable.
 */

import { findListingClaimIssues } from "./claims";
import {
  listingLimits,
  metadataFieldNames,
  playStoreListings,
  supportedLocales,
  type MetadataFieldName,
  type PlayStoreListing,
  type SupportedLocale,
} from "./metadata";

export const fieldLimits: Record<MetadataFieldName, number> = {
  title: listingLimits.title,
  shortDescription: listingLimits.shortDescription,
  fullDescription: listingLimits.fullDescription,
};

export interface MetadataIssue {
  readonly locale: string;
  readonly field: MetadataFieldName | "locale";
  readonly message: string;
}

export interface MetadataValidationResult {
  readonly ok: boolean;
  readonly issues: readonly MetadataIssue[];
}

function isSupportedLocale(value: string): value is SupportedLocale {
  return (supportedLocales as readonly string[]).includes(value);
}

export function codePointLength(value: string): number {
  return [...value].length;
}

export function isValidLocaleSet(
  listings: readonly PlayStoreListing[],
): boolean {
  const locales = listings.map((listing) => listing.locale);
  if (locales.length !== supportedLocales.length) {
    return false;
  }
  const unique = new Set(locales);
  if (unique.size !== locales.length) {
    return false;
  }
  return supportedLocales.every((locale) => unique.has(locale));
}

function structuralIssues(
  listings: readonly PlayStoreListing[],
): MetadataIssue[] {
  const issues: MetadataIssue[] = [];

  if (listings.length === 0) {
    return [
      {
        locale: "<none>",
        field: "locale",
        message: "no listings were provided",
      },
    ];
  }

  const seen = new Set<string>();
  for (const listing of listings) {
    const locale = String(listing.locale);

    if (!isSupportedLocale(locale)) {
      issues.push({
        locale,
        field: "locale",
        message: `unsupported locale; expected one of ${supportedLocales.join(", ")}`,
      });
      continue;
    }

    if (seen.has(locale)) {
      issues.push({
        locale,
        field: "locale",
        message: "duplicate listing for this locale",
      });
      continue;
    }
    seen.add(locale);

    for (const field of metadataFieldNames) {
      const value = listing[field];
      if (typeof value !== "string" || value.trim().length === 0) {
        issues.push({
          locale,
          field,
          message: `${field} must not be empty`,
        });
        continue;
      }
      const length = codePointLength(value);
      if (length > fieldLimits[field]) {
        issues.push({
          locale,
          field,
          message: `${field} is ${length} code points but the limit is ${fieldLimits[field]}`,
        });
      }
    }
  }

  for (const locale of supportedLocales) {
    if (!seen.has(locale)) {
      issues.push({
        locale,
        field: "locale",
        message: "missing listing for this locale",
      });
    }
  }

  return issues;
}

function claimIssues(listings: readonly PlayStoreListing[]): MetadataIssue[] {
  return findListingClaimIssues(listings).map((issue) => ({
    locale: issue.locale,
    field: issue.field as MetadataFieldName,
    message: `unsupported claim [${issue.hits.map((hit) => hit.id).join(", ")}]: ${issue.hits
      .map((hit) => `"${hit.match}" (${hit.reason})`)
      .join("; ")}`,
  }));
}

export function validateMetadata(
  listings: readonly PlayStoreListing[],
): MetadataValidationResult {
  const issues = [...structuralIssues(listings), ...claimIssues(listings)];
  return { ok: issues.length === 0, issues };
}

/**
 * The single gate used by `planListingFiles`, `generateListingFiles`, and
 * `--check`. Throws with every structural and claim problem listed at once.
 */
export function assertValidMetadata(
  listings: readonly PlayStoreListing[] = playStoreListings,
): void {
  const result = validateMetadata(listings);
  if (result.ok) {
    return;
  }
  const details = result.issues
    .map((issue) => `  - ${issue.locale}/${issue.field}: ${issue.message}`)
    .join("\n");
  throw new Error(`Invalid Play Store metadata:\n${details}`);
}
