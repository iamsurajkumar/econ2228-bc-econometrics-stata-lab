# ECON2228 Econometrics: Stata Lab (Boston College, Fall 2026)

**Student page:** https://iamsurajkumar.github.io/econ2228-bc-econometrics-stata-lab/

Lab materials for Suraj Kumar's ECON2228 Stata lab sections. Every lab answers one policy
question with real data from a published study, using a Stata do-file and an interactive
marimo notebook that runs in the browser.

| Week | Question | Paper |
|---|---|---|
| 1 | Introduction to Stata | |
| 2 | Do-files, descriptive statistics and joins (WASDE mini-project) | |
| 3 | Merging and reshaping data | |
| 4 | Compare a school with itself (pooled OLS vs fixed effects) | Papke (2005) |
| 5 | Does school spending raise test scores? | Papke (2005), *J. Public Econ.* |
| 6 | Do smaller classes help kids learn? | Krueger (1999), *QJE* |

## Layout

```
lectures/week-XX/   slides (PDF), do-files, small data files, marimo notebooks (.py)
site/index.html     the student course page
scripts/            publish_list.txt, sync_from_dropbox.sh, build_site.sh
.github/workflows/  builds the site and the browser notebooks on every push
```

## Instructor workflow

The working copy of all teaching files lives in Dropbox (`PhD/teaching/econometrics/lectures`),
which syncs to both the Mac and omabox. This repo holds **only** the student-facing files
listed in `scripts/publish_list.txt`.

```bash
# On either machine (Mac: ~/code/..., omabox: ~/code/...):
git pull
scripts/sync_from_dropbox.sh          # copy the listed files from Dropbox into lectures/
git add -A && git commit -m "Week N" && git push
```

GitHub Actions then rebuilds the page and exports every notebook to run in the browser
(about 2 minutes). To preview locally: `scripts/build_site.sh && python3 -m http.server --directory _site 8000`.

To publish a new file, add its path (relative to `lectures/`) to `scripts/publish_list.txt`.
Never publish copyrighted papers, licensed data (e.g. Bloomberg), solutions, or anything about students.

## Data sources

- Project STAR: Achilles et al. (2008), Harvard Dataverse, doi:10.7910/DVN/SIWH9F.
- Michigan schools (Papke 2005): Wooldridge `school93_98`, via `bcuse`.
- Week 3 family examples: adapted from UCLA OARC Stata modules.
- WASDE revisions: USDA World Agricultural Supply and Demand Estimates.
