import { afterEach, describe, expect, test } from "bun:test";
import {
  mkdir,
  mkdtemp,
  readFile,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, sep } from "node:path";

import {
  assertCleanOutputDirectory,
  assertValidMetadata,
  codePointLength,
  defaultOutputDirectory,
  fieldLimits,
  findNumericCapClaims,
  findUnsupportedClaims,
  generateListingFiles,
  generatedFileNames,
  isValidLocaleSet,
  metadataFieldNames,
  playStoreListings,
  planListingFiles,
  resolveListingPath,
  runMetadataCheck,
  runMetadataCli,
  supportedLocales,
  unsupportedClaimRules,
  validateMetadata,
  type PlayStoreListing,
} from "../src/index";
import { parseCliArgs, resolveOutputDirectory } from "../src/cli";

const temporaryDirectories: string[] = [];

async function makeTemporaryDirectory(): Promise<string> {
  const directory = await mkdtemp(join(tmpdir(), "play-store-metadata-"));
  temporaryDirectories.push(directory);
  return directory;
}

afterEach(async () => {
  while (temporaryDirectories.length > 0) {
    const directory = temporaryDirectories.pop();
    if (directory !== undefined) {
      await rm(directory, { recursive: true, force: true });
    }
  }
});

function withInjectedClaim(
  text: string,
  locale: SupportedLocale = "en-IN",
): PlayStoreListing[] {
  const base = playStoreListings.find((listing) => listing.locale === locale);
  if (base === undefined) {
    throw new Error(`missing fixture for ${locale}`);
  }
  return playStoreListings.map((listing) =>
    listing.locale === locale ? { ...listing, fullDescription: text } : listing,
  );
}

type SupportedLocale = (typeof supportedLocales)[number];

describe("locale coverage", () => {
  test("publishes exactly the five supported locales", () => {
    expect([...supportedLocales]).toEqual([
      "en-IN",
      "hi-IN",
      "mr-IN",
      "bn-IN",
      "ta-IN",
    ]);
    expect(playStoreListings.map((listing) => listing.locale)).toEqual([
      ...supportedLocales,
    ]);
    expect(isValidLocaleSet(playStoreListings)).toBe(true);
  });

  test("rejects a missing locale, a duplicate locale, and an unknown locale", () => {
    const [en, hi] = playStoreListings;
    expect(en).toBeDefined();
    expect(hi).toBeDefined();
    if (en === undefined || hi === undefined) {
      return;
    }

    expect(validateMetadata(playStoreListings.slice(0, 4)).ok).toBe(false);
    expect(isValidLocaleSet(playStoreListings.slice(0, 4))).toBe(false);

    const duplicated = validateMetadata([...playStoreListings, en]);
    expect(duplicated.ok).toBe(false);
    expect(
      duplicated.issues.some((issue) => issue.message.includes("duplicate")),
    ).toBe(true);

    const unknown = { ...en, locale: "te-IN" as PlayStoreListing["locale"] };
    const unknownResult = validateMetadata([
      unknown,
      ...playStoreListings.slice(1),
    ]);
    expect(unknownResult.ok).toBe(false);
    expect(
      unknownResult.issues.some(
        (issue) =>
          issue.field === "locale" && issue.message.includes("unsupported"),
      ),
    ).toBe(true);
  });

  test("fails clearly on empty metadata", () => {
    const result = validateMetadata([]);
    expect(result.ok).toBe(false);
    expect(result.issues).toHaveLength(1);
    expect(result.issues[0]?.message).toBe("no listings were provided");
    expect(() => assertValidMetadata([])).toThrow(
      "Invalid Play Store metadata",
    );
  });
});

describe("field limits", () => {
  test("every listing stays inside the Google Play limits", () => {
    expect(fieldLimits).toEqual({
      title: 30,
      shortDescription: 80,
      fullDescription: 4000,
    });
    for (const listing of playStoreListings) {
      for (const field of metadataFieldNames) {
        expect(listing[field].trim().length).toBeGreaterThan(0);
        expect(codePointLength(listing[field])).toBeLessThanOrEqual(
          fieldLimits[field],
        );
      }
    }
  });

  test("counts Unicode code points rather than UTF-16 units", () => {
    expect(codePointLength("नमस्ते")).toBe(6);
    expect(codePointLength("📺")).toBe(1);
    expect("📺".length).toBe(2);
  });

  test("reports the offending field and length when a limit is exceeded", () => {
    const [en, ...rest] = playStoreListings;
    expect(en).toBeDefined();
    if (en === undefined) {
      return;
    }
    const tooLong: PlayStoreListing = {
      ...en,
      title: "a".repeat(fieldLimits.title + 1),
    };
    const result = validateMetadata([tooLong, ...rest]);
    expect(result.ok).toBe(false);
    expect(
      result.issues.find((entry) => entry.field === "title")?.message,
    ).toBe("title is 31 code points but the limit is 30");
  });

  test("reports empty field content", () => {
    const [en, ...rest] = playStoreListings;
    expect(en).toBeDefined();
    if (en === undefined) {
      return;
    }
    const blank: PlayStoreListing = { ...en, shortDescription: "   " };
    const result = validateMetadata([blank, ...rest]);
    expect(result.ok).toBe(false);
    expect(
      result.issues.some(
        (issue) =>
          issue.field === "shortDescription" && issue.message.includes("empty"),
      ),
    ).toBe(true);
  });
});

describe("implemented-feature accuracy", () => {
  const requiredTerms: Record<SupportedLocale, string[]> = {
    "en-IN": [
      "VC / STB number",
      "account or card number",
      "wa.me",
      ".xlsx, .xls and .csv",
    ],
    "hi-IN": [
      "वीसी / एसटीबी नंबर",
      "खाता या कार्ड नंबर",
      "wa.me",
      ".xlsx, .xls और .csv",
    ],
    "mr-IN": [
      "व्हीसी / एसटीबी क्रमांक",
      "खाते किंवा कार्ड क्रमांक",
      "wa.me",
      ".xlsx, .xls आणि .csv",
    ],
    "bn-IN": [
      "ভিসি / এসটিবি নম্বর",
      "অ্যাকাউন্ট বা কার্ড নম্বর",
      "wa.me",
      ".xlsx, .xls এবং .csv",
    ],
    "ta-IN": [
      "விசி / எஸ்டிபி எண்",
      "கணக்கு அல்லது அட்டை எண்",
      "wa.me",
      ".xlsx, .xls மற்றும் .csv",
    ],
  };

  test("describes the real service identifiers and import extensions", () => {
    for (const locale of supportedLocales) {
      const listing = playStoreListings.find(
        (entry) => entry.locale === locale,
      );
      expect(listing).toBeDefined();
      if (listing === undefined) {
        continue;
      }
      for (const term of requiredTerms[locale]) {
        expect(listing.fullDescription).toContain(term);
      }
    }
  });

  test("drops the nonexistent subscriber package field and overclaiming", () => {
    // "active-package reports" is a real operator export name, so the guard
    // targets the removed subscriber field phrasing instead of the word.
    const banned = [
      /monthly rent and package/iu,
      /पैकेज और मासिक किराया/u,
      /पॅकेज आणि मासिक भाडे/u,
      /প্যাকেজ ও মাসিক ভাড়া/u,
      /தொகுதி மற்றும் மாத வாடகை/u,
      /in-?app\s+edit/iu,
      /any\s+other\s+app/iu,
      /100\s+subscribers/iu,
    ];
    for (const listing of playStoreListings) {
      for (const pattern of banned) {
        expect(`${listing.title}\n${listing.fullDescription}`).not.toMatch(
          pattern,
        );
      }
    }
  });
});

describe("terminology regressions", () => {
  // These tokens were malformed in the first draft of the listings. The check
  // is mechanical, not a native-speaker review.
  const malformed: Record<SupportedLocale, string[]> = {
    "en-IN": [],
    "hi-IN": ["प्रीव्य", "अपनी रजिस्टर", "पुरानी रजिस्टर"],
    "mr-IN": ["स्वतंतपणे", "म्हणूजे", "आवडील्या", "स्प्रेडशिट"],
    "bn-IN": [],
    "ta-IN": [
      "சந்தோபஷ",
      "பாத்திருக்கிறது",
      "ச்ப்ரெட்ஷீட்கள்",
      "மரா஠்டி",
      "மரா஠ி",
      "பயனர்கள் பெயர்",
      "நிரல்களையும்",
    ],
  };

  const requiredTerms: Record<SupportedLocale, string[]> = {
    "en-IN": [],
    "hi-IN": ["पूर्वावलोकन", "अपनी बही"],
    "mr-IN": ["पूर्वदृश्य", "स्प्रेडशीट", "स्वतंत्रपणे", "आवडीच्या"],
    "bn-IN": ["অপেক্ষমাণ"],
    "ta-IN": [
      "வாடிக்கையாளர்",
      "நிலுவையில்",
      "அட்டவணை",
      "நெடுவரிசைகளையும்",
      "மராத்தி",
    ],
  };

  test("no known malformed token survives in any locale", () => {
    for (const locale of supportedLocales) {
      const listing = playStoreListings.find(
        (entry) => entry.locale === locale,
      );
      expect(listing).toBeDefined();
      if (listing === undefined) {
        continue;
      }
      const text = `${listing.title}\n${listing.shortDescription}\n${listing.fullDescription}`;
      for (const token of malformed[locale]) {
        expect(text).not.toContain(token);
      }
      for (const token of requiredTerms[locale]) {
        expect(text).toContain(token);
      }
    }
  });

  test("the Bengali listing never mixes in Arabic script", () => {
    const bengali = playStoreListings.find(
      (listing) => listing.locale === "bn-IN",
    );
    expect(bengali).toBeDefined();
    if (bengali === undefined) {
      return;
    }
    for (const field of metadataFieldNames) {
      expect(bengali[field]).not.toMatch(/[؀-ۿ]/u);
    }
  });
});

describe("unsupported claims", () => {
  test("the canonical metadata contains no unsupported promise", () => {
    for (const listing of playStoreListings) {
      for (const field of metadataFieldNames) {
        expect(findUnsupportedClaims(listing[field])).toEqual([]);
      }
    }
  });

  test("every fixed claim rule rejects a known unsupported phrase", () => {
    const samples: Record<string, string> = {
      "free-forever": "100 subscribers free forever",
      "licensing-or-paywall": "License required for unlimited operators",
      "tax-or-legal-invoice": "Generates a GST invoice for every payment",
      "automatic-payment": "Automatic payment collection is supported",
      "cloud-sync": "Everything is kept in cloud sync across your devices",
      "production-uptime-guarantee":
        "Guaranteed uptime of 99.9% for every operator",
    };
    for (const rule of unsupportedClaimRules) {
      const sample = samples[rule.id];
      expect(sample).toBeDefined();
      if (sample === undefined) {
        continue;
      }
      expect(findUnsupportedClaims(sample).map((hit) => hit.id)).toContain(
        rule.id,
      );
    }
  });

  test("the numeric cap guard covers Latin and Indic digits in every script", () => {
    const capped = [
      "Free for 100 subscribers.",
      "Up to 250 customers on every plan.",
      "Only 50 connections are supported.",
      "No more than 75 subscribers.",
      "पहले 200 ग्राहक मुफ्त।",
      "केवल 30 कनेक्शन समर्थित।",
      "৫০ জন গ্রাহক পর্যন্ত বিনামূল্যে।",
      "শুধু ১০ জন গ্রাহক।",
      "முதல் 40 வாடிக்கையாளர்கள் இலவசம்.",
      "வரை 60 வாடிக்கையாளர்கள் மட்டும்.",
    ];
    for (const phrase of capped) {
      expect(findNumericCapClaims(phrase).map((hit) => hit.id)).toContain(
        "numeric-cap",
      );
    }
  });

  test("the numeric cap guard does not false-positive on implemented prose", () => {
    const allowed = [
      "Add subscribers with full name, alias name, area, monthly rent and previous due.",
      "Book1 collection books and operator active-package or total-subscriber reports are detected automatically.",
      "The file picker accepts .xlsx, .xls and .csv.",
      "Every import shows a preview first, so you can check the detected columns and records.",
      "Store the VC / STB number for Cable TV and the account or card number for Internet.",
      "हर ग्राहक का भुगतान दर्ज करें।",
      "প্রতিটি গ্রাহকের পেমেন্ট লিখে রাখুন।",
      "ஒவ்வொரு வாடிக்கையாளரின் கட்டணத்தையும் பதிவு செய்து.",
      "100% offline",
      "Version 1.0 collection book",
    ];
    for (const phrase of allowed) {
      expect(findNumericCapClaims(phrase)).toEqual([]);
    }
  });

  test("claim scanning is part of the shared metadata assertion", () => {
    const bad = withInjectedClaim("Cloud sync keeps every subscriber safe.");
    const result = validateMetadata(bad);
    expect(result.ok).toBe(false);
    const issue = result.issues.find((entry) =>
      entry.message.includes("unsupported claim"),
    );
    expect(issue?.locale).toBe("en-IN");
    expect(issue?.message).toContain("cloud-sync");
    expect(() => assertValidMetadata(bad)).toThrow("unsupported claim");
  });

  test("planListingFiles rejects an injected unsupported claim", () => {
    const bad = withInjectedClaim("Up to 500 customers, free forever.");
    expect(() => planListingFiles(bad)).toThrow("numeric-cap");
  });

  test("generation rejects an injected claim and writes nothing", async () => {
    const root = await makeTemporaryDirectory();
    const outputDirectory = join(root, "out");
    const bad = withInjectedClaim("Sends a GST invoice for every payment.");

    await expect(generateListingFiles(bad, outputDirectory)).rejects.toThrow(
      "tax-or-legal-invoice",
    );
    await expect(
      readFile(join(outputDirectory, "en-IN", "title.txt")),
    ).rejects.toThrow();
  });

  test("--check rejects an injected unsupported claim", async () => {
    const bad = withInjectedClaim("Automatic payment collection is supported.");
    await expect(runMetadataCheck(bad)).rejects.toThrow("automatic-payment");
  });
});

describe("output paths and filesystem safety", () => {
  test("plans one deterministic file per field and locale", () => {
    const planned = planListingFiles(playStoreListings);
    expect(planned).toHaveLength(
      supportedLocales.length * metadataFieldNames.length,
    );
    expect(planned[0]).toEqual({
      locale: "en-IN",
      fileName: "title.txt",
      content: `${playStoreListings[0]?.title ?? ""}\n`,
    });
    for (const fileName of Object.values(generatedFileNames)) {
      expect(planned.filter((file) => file.fileName === fileName)).toHaveLength(
        supportedLocales.length,
      );
    }
  });

  test("writes the expected paths and content under the requested root", async () => {
    const root = await makeTemporaryDirectory();
    const outputDirectory = join(root, "play");
    const result = await generateListingFiles(
      playStoreListings,
      outputDirectory,
    );

    expect(result.writtenPaths).toHaveLength(15);
    for (const path of result.writtenPaths) {
      expect(path.startsWith(result.outputDirectory)).toBe(true);
    }
    expect(
      await readFile(
        join(result.outputDirectory, "en-IN", "title.txt"),
        "utf8",
      ),
    ).toBe(`${playStoreListings[0]?.title ?? ""}\n`);
    expect(
      await readFile(
        join(result.outputDirectory, "ta-IN", "short-description.txt"),
        "utf8",
      ),
    ).toBe(`${playStoreListings[4]?.shortDescription ?? ""}\n`);
  });

  test("regenerating over a clean directory is repeatable", async () => {
    const root = await makeTemporaryDirectory();
    const outputDirectory = join(root, "repeat");

    const first = await generateListingFiles(
      playStoreListings,
      outputDirectory,
    );
    const firstContents = await Promise.all(
      first.writtenPaths.map(async (path) => readFile(path, "utf8")),
    );

    const second = await generateListingFiles(
      playStoreListings,
      outputDirectory,
    );
    const secondContents = await Promise.all(
      second.writtenPaths.map(async (path) => readFile(path, "utf8")),
    );

    expect(second.writtenPaths).toEqual(first.writtenPaths);
    expect(secondContents).toEqual(firstContents);
  });

  test("refuses a locale or file name that escapes the requested root", () => {
    const outputDirectory = join(tmpdir(), "play-store-root");
    expect(resolveListingPath(outputDirectory, "en-IN", "title.txt")).toBe(
      join(outputDirectory, "en-IN", "title.txt"),
    );
    for (const locale of ["../escaped", "..", "/etc", "a/../../b"]) {
      expect(() =>
        resolveListingPath(outputDirectory, locale, "title.txt"),
      ).toThrow("escapes the");
    }
    expect(() =>
      resolveListingPath(outputDirectory, "en-IN", "../escape.txt"),
    ).toThrow("escapes the locale directory");
  });

  test("refuses a pre-existing symlinked locale directory", async () => {
    const root = await makeTemporaryDirectory();
    const outside = join(root, "outside");
    const outputDirectory = join(root, "out");
    await mkdir(outside, { recursive: true });
    await mkdir(outputDirectory, { recursive: true });
    await writeFile(join(outside, "secret.txt"), "do not touch", "utf8");
    await symlink(outside, join(outputDirectory, "en-IN"), "dir");

    await expect(
      generateListingFiles(playStoreListings, outputDirectory),
    ).rejects.toThrow("symlinked entry");
    expect(await readFile(join(outside, "secret.txt"), "utf8")).toBe(
      "do not touch",
    );
  });

  test("refuses a pre-existing symlinked target file", async () => {
    const root = await makeTemporaryDirectory();
    const outside = join(root, "outside");
    const outputDirectory = join(root, "out");
    await mkdir(outside, { recursive: true });
    await mkdir(join(outputDirectory, "en-IN"), { recursive: true });
    await writeFile(join(outside, "secret.txt"), "do not touch", "utf8");
    await symlink(
      join(outside, "secret.txt"),
      join(outputDirectory, "en-IN", "title.txt"),
    );

    await expect(
      generateListingFiles(playStoreListings, outputDirectory),
    ).rejects.toThrow("symlinked entry");
    expect(await readFile(join(outside, "secret.txt"), "utf8")).toBe(
      "do not touch",
    );
  });

  test("honours a caller-selected symlinked output root", async () => {
    const root = await makeTemporaryDirectory();
    const realRoot = join(root, "real");
    const linkedRoot = join(root, "linked");
    await mkdir(realRoot, { recursive: true });
    await symlink(realRoot, linkedRoot, "dir");

    const result = await generateListingFiles(playStoreListings, linkedRoot);
    expect(result.outputDirectory).toBe(linkedRoot);
    expect(await readFile(join(realRoot, "en-IN", "title.txt"), "utf8")).toBe(
      `${playStoreListings[0]?.title ?? ""}\n`,
    );
  });
});

describe("fail-closed output inventory", () => {
  test("a seeded obsolete file in a current locale fails closed", async () => {
    const root = await makeTemporaryDirectory();
    const outputDirectory = join(root, "out");
    await mkdir(join(outputDirectory, "en-IN"), { recursive: true });
    await writeFile(
      join(outputDirectory, "en-IN", "promotional.txt"),
      "old",
      "utf8",
    );

    await expect(
      generateListingFiles(playStoreListings, outputDirectory),
    ).rejects.toThrow("unknown or stale file");
    expect(
      await readFile(join(outputDirectory, "en-IN", "promotional.txt"), "utf8"),
    ).toBe("old");
    await expect(
      readFile(join(outputDirectory, "en-IN", "title.txt")),
    ).rejects.toThrow();
  });

  test("a seeded obsolete locale directory fails closed", async () => {
    const root = await makeTemporaryDirectory();
    const outputDirectory = join(root, "out");
    await mkdir(join(outputDirectory, "gu-IN"), { recursive: true });
    await writeFile(join(outputDirectory, "gu-IN", "title.txt"), "old", "utf8");

    await expect(
      generateListingFiles(playStoreListings, outputDirectory),
    ).rejects.toThrow("unknown locale directory");
    expect(
      await readFile(join(outputDirectory, "gu-IN", "title.txt"), "utf8"),
    ).toBe("old");
  });

  test("a stray file at the root fails closed", async () => {
    const root = await makeTemporaryDirectory();
    const outputDirectory = join(root, "out");
    await mkdir(outputDirectory, { recursive: true });
    await writeFile(join(outputDirectory, "notes.md"), "keep me", "utf8");

    await expect(
      generateListingFiles(playStoreListings, outputDirectory),
    ).rejects.toThrow("unknown locale directory");
    expect(await readFile(join(outputDirectory, "notes.md"), "utf8")).toBe(
      "keep me",
    );
  });

  test("a previously generated clean directory passes the inventory", async () => {
    const root = await makeTemporaryDirectory();
    const outputDirectory = join(root, "out");
    await generateListingFiles(playStoreListings, outputDirectory);
    await expect(
      assertCleanOutputDirectory(outputDirectory, playStoreListings),
    ).resolves.toBeUndefined();
    await expect(
      generateListingFiles(playStoreListings, outputDirectory),
    ).resolves.toBeDefined();
  });

  test("nothing is written when the inventory fails", async () => {
    const root = await makeTemporaryDirectory();
    const outputDirectory = join(root, "out");
    await mkdir(join(outputDirectory, "en-IN"), { recursive: true });
    await writeFile(join(outputDirectory, "en-IN", "stale.txt"), "old", "utf8");

    await expect(
      generateListingFiles(playStoreListings, outputDirectory),
    ).rejects.toThrow();
    const { readdir } = await import("node:fs/promises");
    expect(await readdir(join(outputDirectory, "en-IN"))).toEqual([
      "stale.txt",
    ]);
  });
});

describe("cli", () => {
  test("defaults to the package dist directory", () => {
    expect(parseCliArgs([])).toEqual({
      outputDirectory: defaultOutputDirectory,
      check: false,
    });
    expect(defaultOutputDirectory.endsWith(`${sep}dist`)).toBe(true);
  });

  test("resolves a relative --out against the invocation directory", () => {
    expect(resolveOutputDirectory("build/play", "/repo")).toBe(
      "/repo/build/play",
    );
    expect(resolveOutputDirectory("/tmp/abs", "/repo")).toBe("/tmp/abs");
  });

  test("accepts both output flag spellings and rejects bad arguments", () => {
    expect(parseCliArgs(["--out", "build/play"])).toEqual({
      outputDirectory: "build/play",
      check: false,
    });
    expect(parseCliArgs(["-o", "build/play"])).toEqual({
      outputDirectory: "build/play",
      check: false,
    });
    expect(parseCliArgs(["--out=build/play"])).toEqual({
      outputDirectory: "build/play",
      check: false,
    });
    expect(parseCliArgs(["--check"])).toEqual({
      outputDirectory: defaultOutputDirectory,
      check: true,
    });
    expect(() => parseCliArgs(["--out"])).toThrow("Missing value for --out.");
    expect(() => parseCliArgs(["--unknown"])).toThrow(
      "Unknown argument: --unknown",
    );
    expect(() => parseCliArgs(["--out", "  "])).toThrow(
      "Output directory must not be empty.",
    );
  });

  test("runs against the canonical metadata and honours --out", async () => {
    const root = await makeTemporaryDirectory();
    const result = await runMetadataCli(["--out", root]);
    expect(result.writtenPaths).toHaveLength(15);
    expect(result.outputDirectory).toBe(root);
  });

  test("check mode plans the same files without touching the repository", async () => {
    const planned = planListingFiles(playStoreListings);
    expect(await runMetadataCheck()).toBe(planned.length);
  });
});
