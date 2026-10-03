# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "marimo",
#     "numpy",
#     "pandas",
#     "altair",
# ]
# ///
# Week 6 -- Tennessee STAR: confidence intervals and p-values with REAL kids
#
# Run with:   marimo run week06_star_notebook.py     (app view, code hidden)
#   or with:  marimo edit week06_star_notebook.py    (see and change the code)
#
# Data: public/star_k.csv, built from the Project STAR student file
# (Harvard Dataverse, doi:10.7910/DVN/SIWH9F) by week06_prepare_notebook_data.do.
# Every dot and every sample below is a real Tennessee kindergartener.
#
# Prepared with the help of Claude (Anthropic), checked by the instructor.

import marimo

__generated_with = "0.24.0"
app = marimo.App(width="medium")


@app.cell
def _():
    import marimo as mo
    import numpy as np
    import pandas as pd
    import altair as alt
    from math import erfc, sqrt

    return alt, erfc, mo, np, pd, sqrt


@app.cell
def _(mo):
    mo.md(r"""
    # Do smaller classes help kids learn?

    In 1985 Tennessee put kindergarteners into **small** (13–17 kids) or
    **regular** (22–25 kids) classes **by lottery**. Below are the real
    reading + math scores of **3,743** of those children.

    In Stata we found that small classes scored **13.9 points higher**
    (SE 2.45, 95% CI from 9.1 to 18.7).

    This notebook answers three questions about that table:

    1. **Why is the regression slope just the gap between two averages?**
    2. **What does the standard error measure?** (What if we reran Tennessee?)
    3. **What do a 95% interval and a p-value actually promise?**
    """)
    return


@app.cell
def _(mo, pd):
    # Load the real data. On your laptop and in the browser version the file sits
    # next to the notebook. On molab only the notebook is copied, so we read the
    # same file from the course's GitHub repository instead.
    GITHUB_CSV = ("https://raw.githubusercontent.com/iamsurajkumar/"
                  "econ2228-bc-econometrics-stata-lab/main/lectures/week-06/public/star_k.csv")
    try:
        star = pd.read_csv(str(mo.notebook_location() / "public" / "star_k.csv"))
    except OSError:  # file not found next to the notebook (e.g. on molab)
        star = pd.read_csv(GITHUB_CSV)
    # Keep small (1) and regular (0) classes only, as in the Stata file.
    kids = star.dropna(subset=["small"]).reset_index(drop=True)
    kids["small"] = kids["small"].astype(int)
    kids["class"] = kids["small"].map({0: "regular", 1: "small"})
    return (kids,)


@app.cell
def _(kids, np):
    # The full-data answer. Below we treat these 3,743 kids as "everyone"
    # and pretend we can only afford to test a smaller sample.
    score_all = kids["score"].to_numpy(dtype=float)
    small_all = kids["small"].to_numpy()
    GAP_ALL = score_all[small_all == 1].mean() - score_all[small_all == 0].mean()
    N_ALL = len(score_all)

    # The regression of score on a 0/1 dummy, for many samples at once.
    # Rows = samples, columns = kids. Returns the gap and its standard error.
    def gap_and_se(y, d):
        n1 = d.sum(axis=1)
        n0 = d.shape[1] - n1
        mean1 = (y * d).sum(axis=1) / n1
        mean0 = (y * (1 - d)).sum(axis=1) / n0
        fitted = np.where(d == 1, mean1[:, None], mean0[:, None])
        ssr = ((y - fitted) ** 2).sum(axis=1)
        s2 = ssr / (d.shape[1] - 2)
        se = np.sqrt(s2 * (1 / n1 + 1 / n0))
        return mean1 - mean0, se

    # Draw `reps` random samples of `n` kids each. Like pulling names from
    # a hat and putting each name back, so the 3,743 kids act like the
    # whole population of Tennessee kindergarteners.
    def draw_samples(rng, n, reps):
        idx = rng.integers(0, N_ALL, size=(reps, n))
        return score_all[idx], small_all[idx]

    return GAP_ALL, draw_samples, gap_and_se, score_all, small_all


@app.cell
def _(mo):
    mo.md(r"""
    ---
    ## 1. A regression on a yes/no variable = two averages

    Each dot is one child. The two orange bars are the **averages** of each
    group. The regression line goes through both averages, so its slope
    (moving from regular = 0 to small = 1) **is the gap**.

    Pick a child to see their **fitted value** (the guess = their group's
    average) and their **residual** (how far they are from that guess).
    """)
    return


@app.cell
def _(kids, mo):
    child = mo.ui.slider(0, len(kids) - 1, value=4, label="Pick a child (row number)")
    child
    return (child,)


@app.cell
def _(alt, child, kids, mo, np, pd):
    rng0 = np.random.default_rng(1)
    dots = kids.assign(x=kids["small"] + rng0.uniform(-0.25, 0.25, len(kids)))
    means = kids.groupby("small", as_index=False)["score"].mean()
    me = dots.iloc[[child.value]].copy()
    me["fitted"] = means.set_index("small").loc[me["small"], "score"].to_numpy()

    xscale = alt.Scale(domain=[-0.6, 1.6])
    base_x = alt.X("x:Q", scale=xscale,
                   axis=alt.Axis(values=[0, 1], labelExpr="datum.value == 0 ? 'regular (0)' : 'small (1)'"),
                   title=None)
    cloud = alt.Chart(dots).mark_circle(size=8, opacity=0.25, color="#7f7f7f").encode(
        x=base_x, y=alt.Y("score:Q", title="Reading + math score", scale=alt.Scale(zero=False)))
    bars = alt.Chart(means).mark_tick(orient="horizontal", thickness=5, size=140, color="#ff7f0e").encode(
        x=alt.X("small:Q", scale=xscale), y="score:Q")
    line = alt.Chart(means).mark_line(color="#d62728", strokeWidth=3).encode(
        x=alt.X("small:Q", scale=xscale), y="score:Q")
    seg = alt.Chart(me).mark_rule(color="#1f77b4", strokeWidth=3).encode(
        x="x:Q", y="score:Q", y2="fitted:Q")
    pt = alt.Chart(me).mark_circle(size=140, color="#1f77b4").encode(x="x:Q", y="score:Q")
    chart_two = (cloud + bars + line + seg + pt).properties(width=520, height=380)

    m0, m1 = means["score"].tolist()
    row = me.iloc[0]
    mo.hstack([chart_two, mo.md(f"""
    **Regular average:** {m0:.1f}<br>
    **Small average:** {m1:.1f}<br>
    **Gap = slope:** {m1 - m0:.1f}

    ---
    **This child** ({row['class']} class)<br>
    Actual score: {row['score']:.0f}<br>
    Fitted value (group average): {row['fitted']:.1f}<br>
    **Residual:** {row['score'] - row['fitted']:+.1f}
    """)], align="center")
    return


@app.cell
def _(mo):
    mo.md(r"""
    Notice how much the dots overlap. Children differ **a lot** for
    reasons that have nothing to do with class size, which is why
    **R² is only 0.009**. Yet the gap between the averages is real, as the
    next sections show.

    ---
    ## 2. What if we reran Tennessee?

    Pretend we could only afford to test **n** children. We pick n kids at
    random from the 3,743 (names out of a hat, each name put back) and
    compute the small–regular gap. Then we do it
    again, and again: **500 reruns**.

    The reruns don't agree. **How spread out they are is exactly what the
    standard error measures.**
    """)
    return


@app.cell
def _(mo):
    n_rerun = mo.ui.slider(50, 2000, value=200, step=50, label="Children tested in each rerun (n)")
    redraw2 = mo.ui.button(value=0, on_click=lambda v: v + 1, label="Rerun 500 more times")
    mo.hstack([n_rerun, redraw2], justify="start", gap=2)
    return n_rerun, redraw2


@app.cell
def _(GAP_ALL, alt, draw_samples, gap_and_se, mo, n_rerun, np, pd, redraw2):
    rng2 = np.random.default_rng(200 + redraw2.value)
    y2, d2 = draw_samples(rng2, n_rerun.value, 500)
    gaps2, ses2 = gap_and_se(y2, d2)
    reruns = pd.DataFrame({"gap": gaps2})

    hist2 = alt.Chart(reruns).mark_bar(color="#4c78a8", opacity=0.8).encode(
        x=alt.X("gap:Q", bin=alt.Bin(step=2), title="Gap found in one rerun (points)",
                scale=alt.Scale(domain=[-40, 70])),
        y=alt.Y("count()", title="Number of reruns"))
    truth2 = alt.Chart(pd.DataFrame({"g": [GAP_ALL]})).mark_rule(
        color="black", strokeDash=[6, 4], strokeWidth=2).encode(x="g:Q")
    zero2 = alt.Chart(pd.DataFrame({"g": [0]})).mark_rule(color="#d62728").encode(x="g:Q")

    mo.hstack([(hist2 + truth2 + zero2).properties(width=520, height=300), mo.md(f"""
    **Spread of the 500 gaps** (their SD):
    ## {gaps2.std():.1f} points

    **Average SE that Stata would print** in one rerun:
    ## {ses2.mean():.1f} points

    The two match: one sample's SE predicts how much the answer
    would move if we reran the study.

    Dashed line = the full-data gap (13.9). Red line = zero.<br>
    Share of reruns with a gap below zero: **{(gaps2 < 0).mean():.0%}**
    """)], align="center")
    return


@app.cell
def _(mo):
    mo.md(r"""
    **Try:** move n from 50 to 2,000. The histogram gets **narrower**
    (the SE shrinks roughly like 1/√n). With 50 kids a rerun often finds a
    *negative* gap; with 2,000 it almost never does.

    ---
    ## 3. What does "95% confidence" promise?

    Each bar is **one** rerun's 95% interval: gap ± 1.96 × SE.
    We know the full-data gap (13.9, dashed line), so we can check each one.
    Bars that **miss** it are **red**.

    *The 95% is a promise about the method, not about one bar:* about 95 of
    100 bars should cross the dashed line.
    """)
    return


@app.cell
def _(mo):
    n_ci = mo.ui.slider(50, 2000, value=200, step=50, label="Children in each sample (n)")
    level = mo.ui.dropdown({"90%": 1.645, "95%": 1.960, "99%": 2.576},
                           value="95%", label="Confidence level")
    redraw3 = mo.ui.button(value=0, on_click=lambda v: v + 1, label="Draw 100 new samples")
    mo.hstack([n_ci, level, redraw3], justify="start", gap=2)
    return level, n_ci, redraw3


@app.cell
def _(GAP_ALL, alt, draw_samples, gap_and_se, level, mo, n_ci, np, pd, redraw3):
    rng3 = np.random.default_rng(305 + redraw3.value)
    y3, d3 = draw_samples(rng3, n_ci.value, 100)
    gaps3, ses3 = gap_and_se(y3, d3)
    ci = pd.DataFrame({
        "sample": np.arange(1, 101),
        "gap": gaps3,
        "low": gaps3 - level.value * ses3,
        "high": gaps3 + level.value * ses3,
    })
    ci["covers"] = np.where((ci["low"] <= GAP_ALL) & (ci["high"] >= GAP_ALL), "yes", "no (miss)")
    ci["above zero"] = ci["low"] > 0

    colors3 = alt.Scale(domain=["yes", "no (miss)"], range=["#4c78a8", "#d62728"])
    bars3 = alt.Chart(ci).mark_rule(strokeWidth=2).encode(
        y=alt.Y("sample:O", axis=None),
        x=alt.X("low:Q", title="Gap (small − regular), with its interval"),
        x2="high:Q", color=alt.Color("covers:N", scale=colors3, title="Covers 13.9?"),
        tooltip=[alt.Tooltip("gap:Q", format=".1f"), alt.Tooltip("low:Q", format=".1f"),
                 alt.Tooltip("high:Q", format=".1f")])
    dots3 = alt.Chart(ci).mark_point(filled=True, size=12, color="black").encode(
        y="sample:O", x="gap:Q")
    truth3 = alt.Chart(pd.DataFrame({"g": [GAP_ALL]})).mark_rule(
        color="black", strokeDash=[6, 4]).encode(x="g:Q")
    zero3 = alt.Chart(pd.DataFrame({"g": [0]})).mark_rule(color="#d62728").encode(x="g:Q")

    hits3 = int((ci["covers"] == "yes").sum())
    mo.hstack([(bars3 + dots3 + truth3 + zero3).properties(width=520, height=420), mo.md(f"""
    **{hits3} of 100** intervals cover the full-data gap.

    **{int(ci['above zero'].sum())} of 100** lie entirely above zero
    (in these samples, the gap is "significantly above zero").

    Press the button a few times: the count of hits stays near
    {level.selected_key.rstrip('%')}.
    """)], align="center")
    return


@app.cell
def _(mo):
    mo.md(r"""
    ---
    ## 4. What is a p-value? Find out by shuffling

    Take **one** sample of n kids. Now **pretend class size does nothing**:
    shuffle the "small/regular" labels at random, as if the lottery had
    been held *after* the tests. Any gap we now see is **pure luck**.

    Do that 2,000 times. The **p-value** is the share of shuffles where luck
    alone produced a gap **at least as big** as the one we really found.
    """)
    return


@app.cell
def _(mo):
    n_p = mo.ui.slider(50, 1000, value=200, step=50, label="Children in our one sample (n)")
    redraw4 = mo.ui.button(value=0, on_click=lambda v: v + 1, label="Take a new sample")
    mo.hstack([n_p, redraw4], justify="start", gap=2)
    return n_p, redraw4


@app.cell
def _(alt, draw_samples, erfc, gap_and_se, mo, n_p, np, pd, redraw4, sqrt):
    rng4 = np.random.default_rng(400 + redraw4.value)
    y4, d4 = draw_samples(rng4, n_p.value, 1)
    gap4, se4 = gap_and_se(y4, d4)
    gap4, se4 = float(gap4[0]), float(se4[0])

    # 2,000 shuffles of the labels: same scores, labels in random order.
    shuffled = rng4.random((2000, n_p.value)).argsort(axis=1)
    fake_gaps, _ = gap_and_se(np.repeat(y4, 2000, axis=0), d4[0][shuffled])
    p_shuffle = float((np.abs(fake_gaps) >= abs(gap4)).mean())
    t4 = gap4 / se4
    p_formula = erfc(abs(t4) / sqrt(2))  # two-sided p from the t-statistic

    fakes = pd.DataFrame({"gap": fake_gaps,
                          "as big as ours?": np.where(np.abs(fake_gaps) >= abs(gap4), "yes", "no")})
    hist4 = alt.Chart(fakes).mark_bar().encode(
        x=alt.X("gap:Q", bin=alt.Bin(maxbins=50), title="Gap produced by luck alone (points)"),
        y=alt.Y("count()", title="Number of shuffles"),
        color=alt.Color("as big as ours?:N",
                        scale=alt.Scale(domain=["no", "yes"], range=["#bbbbbb", "#d62728"])))
    ours = alt.Chart(pd.DataFrame({"g": [gap4, -gap4]})).mark_rule(
        color="black", strokeWidth=2).encode(x="g:Q")

    mo.hstack([(hist4 + ours).properties(width=520, height=300), mo.md(f"""
    **Our sample's real gap:** {gap4:.1f} points<br>
    (SE {se4:.1f}, t = {t4:.2f})

    **Shuffles at least that far from zero:**
    ## p ≈ {p_shuffle:.3f}

    **p-value from the t formula** (what Stata prints):
    ## p ≈ {p_formula:.3f}

    The two agree. A small p means luck alone rarely does this.
    """)], align="center")
    return


@app.cell
def _(mo):
    mo.md(r"""
    **Try:** with n = 50, many samples give p > 0.05 even though small
    classes really help: the sample is too small to tell. With all
    3,743 kids, Stata's p is about 0.00000001, and no shuffle ever comes close.

    ---
    ## Back to Stata

    | In the table | In plain words | Where you saw it here |
    |---|---|---|
    | Coefficient on `small` | gap between the two averages | Section 1 |
    | Std. err. | how much the gap moves if we rerun the study | Section 2 |
    | 95% conf. interval | a range built by a method that catches the truth 95% of the time | Section 3 |
    | P>\|t\| | how often luck alone gives a gap this big | Section 4 |
    | R-squared | how much of the differences between kids we explain (tiny here) | Section 1 |
    """)
    return


if __name__ == "__main__":
    app.run()
