export const publicOrigin = "https://cbk.sarbaa.com";
export const androidPackageName = "com.sarbaa.cbk";
export const referralCodeLength = 6;
export const referralCodePattern = /^[A-Z0-9]{6}$/u;
export const referralCookieName = "cbk_referral";
export const defaultPlayStoreUrl =
  "https://play.google.com/store/apps/details?id=com.sarbaa.cbk";

export function isValidReferralCode(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length === referralCodeLength &&
    referralCodePattern.test(value)
  );
}

export function parseReferralCode(value: unknown): string | null {
  return isValidReferralCode(value) ? value : null;
}

export function buildReferralUrl(value: unknown): string | null {
  const code = parseReferralCode(value);
  return code === null ? null : `${publicOrigin}/r/${code}`;
}
