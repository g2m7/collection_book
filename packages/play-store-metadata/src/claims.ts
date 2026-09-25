/**
 * Play Store listing claim enforcement.
 *
 * The shared, reusable claim rules live in `@collection-book/contracts` so the
 * `cbk.sarbaa.com` landing and privacy pages scan their copy with the exact
 * same rules. This module only adds the listing-specific pass.
 */

import {
  findUnsupportedClaims,
  type UnsupportedClaimHit,
} from "@collection-book/contracts";

import { metadataFieldNames, type PlayStoreListing } from "./metadata";

export {
  findNumericCapClaims,
  findUnsupportedClaims,
  unsupportedClaimRules,
  type UnsupportedClaimHit,
  type UnsupportedClaimRule,
} from "@collection-book/contracts";

export interface ClaimIssue {
  readonly locale: string;
  readonly field: string;
  // `ReadonlyArray<T>` rather than `readonly T[]`: Bun 1.3.4 fails to parse an
  // array of an imported type when the array itself is marked readonly.
  readonly hits: ReadonlyArray<UnsupportedClaimHit>;
}

export function findListingClaimIssues(
  listings: readonly PlayStoreListing[],
): ClaimIssue[] {
  const issues: ClaimIssue[] = [];
  for (const listing of listings) {
    for (const field of metadataFieldNames) {
      const hits = findUnsupportedClaims(listing[field]);
      if (hits.length > 0) {
        issues.push({ locale: listing.locale, field, hits });
      }
    }
  }
  return issues;
}
