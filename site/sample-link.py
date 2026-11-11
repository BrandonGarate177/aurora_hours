"""Print a sample Hours share link for N days of made-up focus time.

    python3 -I site/sample-link.py 365
    python3 -I site/sample-link.py 800 --color all --hours --end 20261111
    python3 -I site/sample-link.py 90 --base "file://$PWD/site/index.html"

The data is random but repeatable: the same arguments print the same link.
--ramp gives day i exactly i % 64 quarter-hours instead, so every position
can be checked by hand. The format is in README.md next to this file.
"""

import argparse
import datetime
import random
import re

B64URL = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"


def step(quarters):
    """Shade step 0-4 for a day's quarter-hours: none, <1 h, 1-2 h, 2-4 h, 4 h+."""
    if quarters == 0:
        return 0
    if quarters < 4:
        return 1
    if quarters < 8:
        return 2
    if quarters < 16:
        return 3
    return 4


def link(base, color, last_day, with_hours, quarters):
    chars = "".join(B64URL[q if with_hours else step(q)] for q in quarters)
    return f"{base}#1.{color}.{last_day:%Y%m%d}.{int(with_hours)}.{chars}"


def main():
    parser = argparse.ArgumentParser(description="Print a sample Hours share link.")
    parser.add_argument("days", type=int, help="how many days the map covers")
    parser.add_argument("--color", default="2da44e", help="6-digit hex without #, or all (default 2da44e)")
    parser.add_argument("--hours", action="store_true", help="carry quarter-hours instead of shade steps")
    parser.add_argument("--end", default=f"{datetime.date.today():%Y%m%d}", help="last day, YYYYMMDD (default today)")
    parser.add_argument("--base", default="http://localhost:8000/", help="page URL before the # (default http://localhost:8000/)")
    parser.add_argument("--seed", type=int, default=1, help="random seed (default 1)")
    parser.add_argument("--ramp", action="store_true", help="day i gets i %% 64 quarter-hours")
    args = parser.parse_args()

    if args.days < 1:
        parser.error("days must be at least 1")
    if not re.fullmatch(r"[0-9a-fA-F]{6}|all", args.color):
        parser.error("--color must be 6 hex digits or all")
    try:
        last_day = datetime.datetime.strptime(args.end, "%Y%m%d").date()
    except ValueError:
        parser.error("--end must be a date as YYYYMMDD")

    if args.ramp:
        quarters = [i % 64 for i in range(args.days)]
    else:
        rng = random.Random(args.seed)
        quarters = [
            0 if rng.random() < 0.35 else min(63, 1 + int(rng.expovariate(1 / 9)))
            for _ in range(args.days)
        ]
    print(link(args.base, args.color.lower(), last_day, args.hours, quarters))


if __name__ == "__main__":
    main()
