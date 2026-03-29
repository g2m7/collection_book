#!/usr/bin/env python3
"""
import_subscribers.py — Import subscriber & payment data into the Ledger SQLite DB.

Sources (all optional, use whichever you have):
  --book1   Book1 Edit.xlsx          manual 2025 ledger (subscribers + monthly payments)
  --active  active-packages.xls      active subscriptions with START_DATE
  --total   total-subscriber-list.xls all subscribers with STB_ISSUE_DATE

Usage:
  python3 import_subscribers.py --db rent_ledger.db --book1 "Book1 Edit.xlsx" \
      --active "...SUBSCRIBER LIST WITH ACTIVE PACKAGE REPORT....xls" \
      --total  "...TOTAL SUBSCRIBER LIST REPORT....xls"

How to get the DB from an Android device:
  adb pull /data/data/com.example.ledger/databases/rent_ledger.db .
  python3 import_subscribers.py --db rent_ledger.db ...
  adb push rent_ledger.db /data/data/com.example.ledger/databases/rent_ledger.db

Dry-run (shows what would be imported, does not write):
  python3 import_subscribers.py --db rent_ledger.db --book1 "Book1 Edit.xlsx" --dry-run
"""

import argparse
import sqlite3
import sys
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    sys.exit("pandas is required: pip install pandas openpyxl lxml")

# ---------------------------------------------------------------------------
# Book1 column mapping (2025 data, 58 columns total, 0-indexed)
# Row 0: month headers  Row 2: field labels  Row 3+: data
# Each entry: paid column index, optional adj column index
# ---------------------------------------------------------------------------
BOOK1_YEAR = 2025

MONTH_COLS = {
    1:  {'paid': 7,  'adj': 9},    # JAN  (header @ col 7)
    2:  {'paid': 10, 'adj': None}, # FEB  (header @ col 10)
    3:  {'paid': 14, 'adj': None}, # MAR  (header @ col 14)
    4:  {'paid': 18, 'adj': 17},   # APR  (header @ col 18)
    5:  {'paid': 22, 'adj': 21},   # MAY  (header @ col 22)
    6:  {'paid': 25, 'adj': 24},   # JUN  (header @ col 25)
    7:  {'paid': 29, 'adj': 28},   # JUL  (header @ col 29)
    8:  {'paid': 35, 'adj': 34},   # AUG  (header @ col 35)
    9:  {'paid': 40, 'adj': 39},   # SEP  (header @ col 39)
    10: {'paid': 48, 'adj': 47},   # OCT  (header @ col 47)
    11: {'paid': 51, 'adj': 50},   # NOV  (header @ col 50)
    12: {'paid': 56, 'adj': 55},   # DEC  (header @ col 55)
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _clean_name(val):
    if pd.isna(val):
        return None
    s = str(val).strip().lstrip("'").strip()
    return s or None


def _clean_vc(val):
    if pd.isna(val):
        return None
    s = str(val).strip().strip("'").strip()
    # Remove scientific notation artefacts (e.g. "1.39e+10")
    if 'e' in s.lower() and '.' in s:
        try:
            s = str(int(float(s)))
        except ValueError:
            pass
    return s or None


def _num(val):
    if pd.isna(val):
        return 0.0
    try:
        return float(val)
    except (TypeError, ValueError):
        return 0.0


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_book1(path: str) -> list[dict]:
    """Parse Book1 Edit.xlsx → list of subscriber dicts with payment history."""
    df = pd.read_excel(path, sheet_name='Sheet1', header=None)

    # Forward-fill the AREA column (col 0) across merged cells.
    # Blank out the header label ("AREA") so it doesn't propagate into data rows.
    df.loc[df[0].astype(str).str.upper() == 'AREA', 0] = None
    df[0] = df[0].ffill()

    records = []
    for i, row in df.iterrows():
        if i < 3:  # skip the two header rows
            continue

        name = _clean_name(row[3])
        vc   = _clean_vc(row[4])

        if not name and not vc:
            continue

        # Skip rows that look like section separators (no VC, name is an area keyword)
        if not vc and name and name.isupper() and len(name.split()) <= 3:
            continue

        area     = _clean_name(row[0])
        alias    = _clean_name(row[2])
        rent     = _num(row[5])
        prev_due = _num(row[6])

        payments = {}
        for month, cols in MONTH_COLS.items():
            paid_raw = row[cols['paid']]
            adj_raw  = row[cols['adj']] if cols['adj'] is not None else None

            paid = _num(paid_raw) if not pd.isna(paid_raw) else None
            adj  = _num(adj_raw)  if adj_raw is not None and not pd.isna(adj_raw) else 0.0

            if paid is not None:  # any recorded paid value (even 0) is meaningful
                payments[month] = {'paid': paid, 'adj': adj}

        # Determine subscription start from first month with data in Book1
        # (only used as a fallback if no start date found in the XLS reports)
        first_payment_month = min(payments.keys()) if payments else None

        records.append({
            'name':       name,
            'alias':      alias,
            'vc':         vc,
            'area':       area,
            'rent':       rent,
            'prev_due':   prev_due,
            'book1_start_month': first_payment_month,
            'book1_start_year':  BOOK1_YEAR if first_payment_month else None,
            'payments':   payments,
        })

    return records


def parse_active_packages(path: str) -> dict[str, dict]:
    """Parse active-packages XLS → {vc: {start_year, start_month, area, is_active}}."""
    dfs = pd.read_html(path)
    df = dfs[0]

    df['START_DATE'] = pd.to_datetime(df['START_DATE'], format='%d/%m/%Y', errors='coerce')
    # Keep only BASE plans (not add-on ALC), deduplicate by earliest start date
    if 'PLAN_TYPE' in df.columns:
        df = df[df['PLAN_TYPE'] == 'BASE']
    df = df.sort_values('START_DATE').drop_duplicates(subset='STB_NUMBER', keep='first')

    result = {}
    for _, row in df.iterrows():
        # Active-packages file stores VC in STB_NUMBER; VC_CARD is often NaN
        vc = _clean_vc(row.get('STB_NUMBER')) or _clean_vc(row.get('VC_CARD'))
        if not vc:
            continue
        sd = row.get('START_DATE')
        result[vc] = {
            'start_year':  int(sd.year)  if pd.notna(sd) else None,
            'start_month': int(sd.month) if pd.notna(sd) else None,
            'area':        str(row.get('ADDRESS3', '') or '').strip() or None,
            'is_active':   str(row.get('STATUS', '')).upper() == 'ACTIVE',
        }
    return result


def parse_total_list(path: str) -> dict[str, dict]:
    """Parse total-subscriber-list XLS → {vc: {start_year, start_month, area, is_active}}."""
    dfs = pd.read_html(path)
    df = dfs[0]

    df['STB_ISSUE_DATE'] = pd.to_datetime(df['STB_ISSUE_DATE'], format='%d/%m/%Y', errors='coerce')
    df = df.drop_duplicates(subset='VC_CARD', keep='first')

    result = {}
    for _, row in df.iterrows():
        vc = _clean_vc(row.get('VC_CARD'))
        if not vc:
            continue
        sd = row.get('STB_ISSUE_DATE')
        result[vc] = {
            'start_year':  int(sd.year)  if pd.notna(sd) else None,
            'start_month': int(sd.month) if pd.notna(sd) else None,
            'area':        str(row.get('ADDRESS3', '') or '').strip() or None,
            'is_active':   str(row.get('STATUS', '')).upper() == 'ACTIVE',
        }
    return result


# ---------------------------------------------------------------------------
# DB helpers
# ---------------------------------------------------------------------------

def ensure_columns(conn: sqlite3.Connection):
    """Add start_year / start_month columns if the app hasn't migrated yet."""
    cur = conn.cursor()
    for col in ('start_year', 'start_month'):
        try:
            cur.execute(f'ALTER TABLE subscribers ADD COLUMN {col} INTEGER')
        except sqlite3.OperationalError:
            pass
    conn.commit()


def get_or_create_area(conn: sqlite3.Connection, name: str | None) -> int | None:
    if not name:
        return None
    cur = conn.cursor()
    cur.execute('SELECT id FROM areas WHERE name = ?', (name,))
    row = cur.fetchone()
    if row:
        return row[0]
    cur.execute('INSERT INTO areas (name) VALUES (?)', (name,))
    conn.commit()
    return cur.lastrowid


# ---------------------------------------------------------------------------
# Import
# ---------------------------------------------------------------------------

def import_data(
    conn: sqlite3.Connection,
    records: list[dict],
    active_map: dict,
    total_map: dict,
    dry_run: bool,
) -> dict:
    cur = conn.cursor()
    stats = {'inserted': 0, 'updated': 0, 'payments': 0, 'skipped': 0}

    for rec in records:
        name = rec['name']
        vc   = rec['vc']

        if not name:
            stats['skipped'] += 1
            continue

        # Enrich from XLS reports (prefer STB_ISSUE_DATE from total list)
        pkg  = active_map.get(vc, {})
        lst  = total_map.get(vc, {})

        area_name = lst.get('area') or pkg.get('area') or rec.get('area')
        area_id   = get_or_create_area(conn, area_name) if not dry_run else None

        # Start date priority: total-list STB date > active-package start > Book1 first payment
        start_year  = lst.get('start_year')  or pkg.get('start_year')  or rec.get('book1_start_year')
        start_month = lst.get('start_month') or pkg.get('start_month') or rec.get('book1_start_month')

        # If subscription began before the Book1 period, keep start as-is (don't clip to Jan 2025)
        is_active = lst.get('is_active', pkg.get('is_active', True))

        if dry_run:
            print(f"  [{('UPDATE' if _find_sub(conn, vc, name) else 'INSERT')}] "
                  f"{name!r:40s}  VC={vc}  area={area_name}  "
                  f"start={start_year}/{start_month}  "
                  f"payments={len(rec['payments'])}")
            stats['inserted'] += 1
            continue

        existing_id = _find_sub(conn, vc, name)

        if existing_id:
            cur.execute('''
                UPDATE subscribers SET
                    area_id     = COALESCE(?, area_id),
                    alias_name  = COALESCE(?, alias_name),
                    monthly_rent = ?,
                    previous_due = ?,
                    is_active   = ?,
                    start_year  = COALESCE(?, start_year),
                    start_month = COALESCE(?, start_month)
                WHERE id = ?
            ''', (area_id, rec['alias'], rec['rent'], rec['prev_due'],
                  1 if is_active else 0, start_year, start_month, existing_id))
            sub_id = existing_id
            stats['updated'] += 1
        else:
            cur.execute('''
                INSERT INTO subscribers
                    (area_id, name, alias_name, vc_number, monthly_rent,
                     previous_due, is_active, service_type, start_year, start_month)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'tv', ?, ?)
            ''', (area_id, name, rec['alias'], vc, rec['rent'], rec['prev_due'],
                  1 if is_active else 0, start_year, start_month))
            sub_id = cur.lastrowid
            stats['inserted'] += 1

        for month, pdata in rec['payments'].items():
            paid = pdata['paid']
            adj  = pdata['adj']
            if paid == 0 and adj == 0:
                continue
            cur.execute('''
                INSERT INTO payments
                    (subscriber_id, year, month, amount_paid, adjustment)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(subscriber_id, year, month) DO UPDATE SET
                    amount_paid = excluded.amount_paid,
                    adjustment  = excluded.adjustment
            ''', (sub_id, BOOK1_YEAR, month, paid, adj))
            stats['payments'] += 1

    if not dry_run:
        conn.commit()

    return stats


def _find_sub(conn: sqlite3.Connection, vc: str | None, name: str) -> int | None:
    cur = conn.cursor()
    if vc:
        cur.execute('SELECT id FROM subscribers WHERE vc_number = ?', (vc,))
        row = cur.fetchone()
        if row:
            return row[0]
    cur.execute('SELECT id FROM subscribers WHERE name = ?', (name,))
    row = cur.fetchone()
    return row[0] if row else None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description='Import subscriber data into Ledger SQLite DB')
    ap.add_argument('--db',     required=True, help='Path to rent_ledger.db')
    ap.add_argument('--book1',  help='Path to Book1 Edit.xlsx (manual 2025 ledger)')
    ap.add_argument('--active', help='Path to active packages XLS report')
    ap.add_argument('--total',  help='Path to total subscriber list XLS report')
    ap.add_argument('--dry-run', action='store_true', help='Print what would be imported without writing')
    args = ap.parse_args()

    if not args.book1 and not args.active and not args.total:
        ap.error('Provide at least one of --book1, --active, --total')

    db_path = Path(args.db)
    if not db_path.exists():
        sys.exit(f'DB not found: {db_path}')

    conn = sqlite3.connect(str(db_path))
    if not args.dry_run:
        ensure_columns(conn)

    records    = parse_book1(args.book1)   if args.book1  else []
    active_map = parse_active_packages(args.active) if args.active else {}
    total_map  = parse_total_list(args.total)       if args.total  else {}

    print(f'Book1 subscribers parsed : {len(records)}')
    print(f'Active-package entries   : {len(active_map)}')
    print(f'Total-list entries       : {len(total_map)}')

    if args.dry_run:
        print('\n--- DRY RUN (no changes written) ---')

    stats = import_data(conn, records, active_map, total_map, args.dry_run)
    conn.close()

    print(f'\nDone.')
    print(f"  Inserted : {stats['inserted']}")
    print(f"  Updated  : {stats['updated']}")
    print(f"  Payments : {stats['payments']}")
    print(f"  Skipped  : {stats['skipped']}")

    if args.dry_run:
        print('\nRe-run without --dry-run to apply changes.')


if __name__ == '__main__':
    main()
