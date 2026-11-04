#!/usr/bin/env python3
"""COIL Project A, task 2: summarise the delay tests to our fixed AWS Region.
Our AWS Free plan account cannot change Region, so there is only one Region
(ap-southeast-2, Sydney) and no Region comparison.
Run from the repository folder: python3 scripts/region-summary.py
Reads  delay-tests/region-measurement.csv (one row per run of 100 pings)
Writes delay-tests/region-delay.csv (region,country,median_ms; the dashboard reads it)
       docs/region-summary.md (tables to paste into docs/region-report.md)
"""
import csv
import statistics
from pathlib import Path

IN_FILE = Path("delay-tests/region-measurement.csv")
OUT_CSV = Path("delay-tests/region-delay.csv")
OUT_MD = Path("docs/region-summary.md")
FIXED_REGION = "ap-southeast-2"
MAX_LOSS = 5.0
SPREAD_FLAG = 30.0


def slot(hhmm):
    hour = int(hhmm.split(":")[0])
    return "morning" if hour < 12 else ("afternoon" if hour < 18 else "evening")


def main():
    if not IN_FILE.exists():
        raise SystemExit(f"{IN_FILE} not found. Run this from the repository folder.")
    groups, skipped = {}, []
    with IN_FILE.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            try:
                med, loss = float(row["median_ms"]), float(row["loss_pct"])
            except (KeyError, TypeError, ValueError):
                skipped.append((row.get("date"), row.get("time"), row.get("city"), row.get("region"), "no replies"))
                continue
            if loss > MAX_LOSS:
                skipped.append((row["date"], row["time"], row["city"], row["region"], f"loss {loss:.0f}%"))
                continue
            key = (row["region"].strip(), row["country"].strip())
            groups.setdefault(key, []).append((med, loss, row["date"], slot(row["time"])))

    lines = ["# Region delay summary", "",
             f"Generated from {IN_FILE}. Runs with more than {MAX_LOSS:.0f}% loss are left out.", "",
             "| Region | Country | Median of runs (ms) | Runs | Days | Times of day | Worst loss | Fastest to slowest run |",
             "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    final = {}
    for (region, country), runs in sorted(groups.items()):
        meds = [r[0] for r in runs]
        final[(region, country)] = statistics.median(meds)
        spread = (max(meds) - min(meds)) / min(meds) * 100 if min(meds) > 0 else 0
        flag = " **check: over 30%**" if spread > SPREAD_FLAG else ""
        slots = ", ".join(sorted({r[3] for r in runs}))
        lines.append(f"| {region} | {country} | {final[(region, country)]:.1f} | {len(runs)} | "
                     f"{len({r[2] for r in runs})} | {slots} | {max(r[1] for r in runs):.0f}% | "
                     f"{min(meds):.1f} to {max(meds):.1f} ({spread:.0f}%){flag} |")

    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["region", "country", "median_ms"])
        for (region, country), med in sorted(final.items()):
            w.writerow([region, country, f"{med:.1f}"])

    lines += ["", "## Result for the fixed Region", "",
              "| Region | Median from Szczecin (ms) | Median from Mati (ms) | Larger of the two medians (ms) |",
              "| --- | --- | --- | --- |"]
    pl, ph = final.get((FIXED_REGION, "Poland")), final.get((FIXED_REGION, "Philippines"))
    if pl is None or ph is None:
        lines.append(f"| {FIXED_REGION} | {f'{pl:.1f}' if pl is not None else 'missing'} | "
                     f"{f'{ph:.1f}' if ph is not None else 'missing'} | not both countries have results yet |")
        lines += ["", "Not both countries have results yet."]
    else:
        lines.append(f"| {FIXED_REGION} | {pl:.1f} | {ph:.1f} | {max(pl, ph):.1f} |")
    others = sorted({r for r, _ in final} - {FIXED_REGION})
    if others:
        lines += ["", "Rows for other Regions were found (" + ", ".join(others) + "). "
                  f"Our Region is fixed to {FIXED_REGION}; check region-targets.csv and the CSV rows."]
    if skipped:
        lines += ["", "## Runs left out (repeat them)", "", "| Date | Time | City | Region | Reason |",
                  "| --- | --- | --- | --- | --- |"]
        lines += [f"| {d} | {t} | {c} | {r} | {why} |" for d, t, c, r, why in skipped]
    OUT_MD.parent.mkdir(parents=True, exist_ok=True)
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    print(f"\nWrote {OUT_CSV} and {OUT_MD}")


if __name__ == "__main__":
    main()
