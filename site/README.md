# The share page

`index.html` draws one shared Hours map from its link. The whole map rides in the link's fragment (the part after `#`), which browsers never send to the server. No server, no account, no database, no build step, no dependencies, no analytics. Keep the file under 4 KB; the deploy fails if it isn't.

## Link format, version 1

```
https://<base>/#1.<color>.<last day>.<hours flag>.<days>
```

Five fields, separated by `.`:

| Field | Value |
|---|---|
| version | `1` |
| color | the area color as 6 hex digits without `#` (`2da44e`), or `all` for the combined map, drawn in the page's foreground color |
| last day | the newest day on the map, `YYYYMMDD`, in the sharer's local calendar |
| hours flag | `0` shading only, `1` with hours |
| days | one base64url character per day, oldest first, ending on the last day; at least one |

The base64url alphabet, value 0 to 63:

```
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_
```

### What a day's character holds

- **Hours flag `1`:** the day's focus time in quarter-hours, 0 to 63. The encoder rounds minutes to the nearest quarter-hour and caps at 63, so a day tops out at 15:45. The page shows `value / 4` hours.
- **Hours flag `0`:** only the shade step, 0 to 4, so exact hours never leave the Mac. The page treats anything above 4 as 4.

### Shade steps

The step comes from the quarter-hour count `q`. An encoder sharing without hours computes `q` the same way first and sends the step, so a map looks the same with or without hours.

| Step | Quarter-hours | Hours | Opacity of the color |
|---|---|---|---|
| 0 | 0 | none | empty square |
| 1 | 1 to 3 | under 1 h | 0.3 |
| 2 | 4 to 7 | 1 h to under 2 h | 0.55 |
| 3 | 8 to 15 | 2 h to under 4 h | 0.8 |
| 4 | 16 to 63 | 4 h and up | 1.0 |

### Placing days

With `n` characters, the character at position `i` (0-based) is the day `last day - (n - 1 - i)`. Rows are weekdays, Sunday at the top, like GitHub. The first column starts on the first day's weekday, so the cells above it are left out; each later column is one Sunday-to-Saturday week.

Up to 53 columns draw as one strip, at its own width. Past 53, the map wraps into strips of exactly 53 weeks each, oldest at the top, all the same width. The newest strip ends on the last day's week, and the oldest strip holds what's left, pushed to the right so each strip continues where the one above it ends.

### Example

```
https://<base>/#1.2da44e.20261111.1.ABCD
```

Four days with hours, Nov 8 to Nov 11 2026: 0, 0.25, 0.5 and 0.75 h. Nov 8 2026 is a Sunday, so it sits in the top row.

## What the page shows

The word `Hours` and the map. With hours, also the total under the map (the sum of quarter-hours / 4, rounded) and `Nov 12 2025  1.5 h` when a day is hovered, tapped or long-pressed. Any link that doesn't match the format above shows only `Hours`.

## Checking it by hand

`sample-link.py` prints a repeatable sample link:

```sh
python3 -I site/sample-link.py 365                       # one year, shading only
python3 -I site/sample-link.py 800 --color all --hours   # three strips, with hours
python3 -I site/sample-link.py 90 --ramp --hours         # day i holds i % 64 quarter-hours
```

Open the link with `python3 -m http.server` running in `site/` (the default base is `http://localhost:8000/`), or pass `--base "file://$PWD/site/index.html"` and open the file directly. `--end YYYYMMDD` sets the last day, `--seed` changes the random data.

## Publishing

`.github/workflows/pages.yml` deploys `index.html` to GitHub Pages on every push to `main` that touches `site/`, and can be run by hand from the Actions tab. Once per repo, set Settings > Pages > Source to **GitHub Actions**. The page lands at `https://brandongarate177.github.io/aurora_hours/`. Nothing in the page depends on that address. The app's base URL, `ShareLink.base` in `Hours/Model/ShareLink.swift`, is the only place it's set.
