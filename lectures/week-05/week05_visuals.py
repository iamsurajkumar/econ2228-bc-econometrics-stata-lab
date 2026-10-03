# Week 5 -- three interactive pictures (marimo notebook)
#
# Run with:   marimo run week05_visuals.py     (app view, code hidden)
#   or with:  marimo edit week05_visuals.py    (see and change the code)
#
# All data are SIMULATED: we choose the true effect ourselves, so we can
# check whether our methods find it.
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

    return alt, mo, np, pd


@app.cell
def _(mo):
    mo.md(r"""
    # Week 5: three pictures about standard errors

    1. **What does "95% confidence" mean?**
    2. **Why do we cluster standard errors by school?**
    3. **Why does free lunch stop being significant with fixed effects?**

    Move the sliders and press the buttons. Every number is computed from
    simulated data, where *we* know the true effect.
    """)
    return


@app.cell
def _(np):
    # Slope from y = a + b*x, for many samples at once.
    # x and y have shape (samples, observations).
    def ols_slope(x, y):
        xd = x - x.mean(axis=-1, keepdims=True)
        yd = y - y.mean(axis=-1, keepdims=True)
        b = (xd * yd).sum(axis=-1) / (xd**2).sum(axis=-1)
        e = yd - b[..., None] * xd
        return b, xd, e

    # Plain (non-clustered) standard error of the slope.
    def plain_se(xd, e):
        n = xd.shape[-1]
        s2 = (e**2).sum(axis=-1) / (n - 2)
        return np.sqrt(s2 / (xd**2).sum(axis=-1))

    # Clustered standard error. xd and e have shape (samples, schools, years):
    # add up x*e inside each school first, then square.
    def cluster_se(xd, e, k=2):
        g, t = xd.shape[-2], xd.shape[-1]
        n = g * t
        meat = ((xd * e).sum(axis=-1) ** 2).sum(axis=-1)
        sxx = (xd**2).sum(axis=(-2, -1))
        adj = g / (g - 1) * (n - 1) / (n - k)
        return np.sqrt(adj * meat) / sxx

    # 97.5% point of the t distribution with (schools - 1) degrees of
    # freedom, as Stata uses for clustered intervals.
    T975 = {2: 4.303, 4: 2.776, 9: 2.262, 19: 2.093, 49: 2.010, 99: 1.984,
            199: 1.972, 299: 1.968}
    return T975, cluster_se, ols_slope, plain_se


@app.cell
def _(mo):
    mo.md(r"""
    ---
    ## 1. What does "95% confidence" mean?

    We know the truth: **each extra unit of spending raises the pass rate by
    2 points**. We draw 100 separate samples, run the regression in each and
    draw each sample's 95% confidence interval as a bar.

    *The 95% is a promise about the method, not about one bar:* about 95 of
    the 100 bars should cross the true value. Misses are in **red**.
    """)
    return


@app.cell
def _(mo):
    n_obs = mo.ui.slider(10, 500, value=50, step=10, label="Observations in each sample")
    level = mo.ui.dropdown({"90%": 1.645, "95%": 1.960, "99%": 2.576},
                           value="95%", label="Confidence level")
    redraw1 = mo.ui.button(value=0, on_click=lambda v: v + 1,
                           label="Draw 100 new samples")
    mo.hstack([n_obs, level, redraw1], justify="start", gap=2)
    return level, n_obs, redraw1


@app.cell
def _(level, n_obs, np, ols_slope, pd, plain_se, redraw1):
    # Simulate 100 samples of y = 1 + 2*x + noise and build each interval.
    TRUE_B1 = 2.0
    rng1 = np.random.default_rng(100 + redraw1.value)
    x1 = rng1.normal(0, 1, size=(100, n_obs.value))
    y1 = 1 + TRUE_B1 * x1 + rng1.normal(0, 5, size=x1.shape)
    b1, xd1, e1 = ols_slope(x1, y1)
    se1 = plain_se(xd1, e1)
    ci1 = pd.DataFrame({
        "sample": np.arange(1, 101),
        "estimate": b1,
        "low": b1 - level.value * se1,
        "high": b1 + level.value * se1,
    })
    ci1["covers truth"] = np.where(
        (ci1["low"] <= TRUE_B1) & (ci1["high"] >= TRUE_B1), "yes", "no (miss)")
    return TRUE_B1, ci1


@app.cell
def _(TRUE_B1, alt, ci1, level, mo):
    colors1 = alt.Scale(domain=["yes", "no (miss)"], range=["#4c78a8", "#d62728"])
    bars1 = alt.Chart(ci1).mark_rule(strokeWidth=2).encode(
        y=alt.Y("sample:O", axis=None),
        x=alt.X("low:Q", title="Estimated effect of spending, with its interval"),
        x2="high:Q",
        color=alt.Color("covers truth:N", scale=colors1),
        tooltip=["sample", alt.Tooltip("estimate:Q", format=".2f"),
                 alt.Tooltip("low:Q", format=".2f"), alt.Tooltip("high:Q", format=".2f")],
    )
    dots1 = alt.Chart(ci1).mark_point(filled=True, size=12, color="black").encode(
        y="sample:O", x="estimate:Q")
    truth1 = alt.Chart().mark_rule(color="black", strokeDash=[6, 4]).encode(
        x=alt.datum(TRUE_B1))
    chart1 = (bars1 + dots1 + truth1).properties(width=600, height=420)

    hits1 = int((ci1["covers truth"] == "yes").sum())
    mo.vstack([
        chart1,
        mo.md(f"**{hits1} of 100** intervals cross the true value 2 "
              f"(the method promises about {level.selected_key[:-1]}). "
              f"Try more observations: the bars get **shorter**, "
              f"but the share of hits stays about the same."),
    ])
    return


@app.cell
def _(mo):
    mo.md(r"""
    ---
    ## 2. Why do we cluster standard errors by school?

    Now the data are **schools observed for 6 years**. A school's years are
    linked: a school that spends a lot this year spent a lot last year, and
    a school that does unusually well this year probably did last year too.
    So 6 years of one school are *not* 6 independent pieces of evidence.

    We repeat the whole study **1,000 times** with a true effect of 2. The
    *true* spread of the 1,000 estimates tells us how uncertain one
    estimate really is. Which standard error matches it?
    """)
    return


@app.cell
def _(mo):
    link = mo.ui.slider(0.0, 0.9, value=0.6, step=0.1,
                        label="How strongly a school's years are linked")
    n_schools = mo.ui.dropdown(["3", "5", "10", "20", "50", "100", "200"],
                               value="50", label="Number of schools")
    mo.hstack([link, n_schools], justify="start", gap=2)
    return link, n_schools


@app.cell
def _(T975, cluster_se, link, n_schools, np, ols_slope, plain_se):
    # 1,000 studies, each with G schools x 6 years. A share `rho` of both the
    # spending variation and the unexplained part is fixed within a school.
    REPS, YEARS, TRUE_B2 = 1000, 6, 2.0
    G2 = int(n_schools.value)
    rho = link.value
    rng2 = np.random.default_rng(2)
    shape2 = (REPS, G2, YEARS)

    def school_linked(r, size):
        school_part = r.normal(size=size[:2] + (1,))
        year_part = r.normal(size=size)
        return np.sqrt(rho) * school_part + np.sqrt(1 - rho) * year_part

    x2 = school_linked(rng2, shape2)
    y2 = 1 + TRUE_B2 * x2 + 3 * school_linked(rng2, shape2)

    b2, xd2, e2 = ols_slope(x2.reshape(REPS, -1), y2.reshape(REPS, -1))
    se_plain2 = plain_se(xd2, e2)
    se_clus2 = cluster_se(xd2.reshape(shape2), e2.reshape(shape2))

    tcrit2 = T975[G2 - 1]
    cover_plain2 = np.mean(np.abs(b2 - TRUE_B2) <= 1.96 * se_plain2)
    cover_clus2 = np.mean(np.abs(b2 - TRUE_B2) <= tcrit2 * se_clus2)
    return (
        G2,
        TRUE_B2,
        b2,
        cover_clus2,
        cover_plain2,
        se_clus2,
        se_plain2,
        tcrit2,
    )


@app.cell
def _(G2, TRUE_B2, alt, b2, pd):
    # Histogram of the 1,000 estimates: this is the TRUE uncertainty.
    hist2 = alt.Chart(pd.DataFrame({"estimate": b2})).mark_bar(color="#9ecae1").encode(
        x=alt.X("estimate:Q", bin=alt.Bin(maxbins=40),
                title="Estimated effect in each of the 1,000 studies"),
        y=alt.Y("count()", title="Number of studies"),
    )
    truth2 = alt.Chart().mark_rule(color="black", strokeDash=[6, 4]).encode(
        x=alt.datum(TRUE_B2))
    chart2a = (hist2 + truth2).properties(
        width=330, height=260, title=f"1,000 studies with {G2} schools each")
    return (chart2a,)


@app.cell
def _(alt, b2, pd, se_clus2, se_plain2):
    # Compare the true spread with what each standard error claims.
    spread2 = pd.DataFrame({
        "measure": ["True spread", "Plain SE", "Clustered SE"],
        "size": [b2.std(), se_plain2.mean(), se_clus2.mean()],
    })
    chart2b = alt.Chart(spread2).mark_bar().encode(
        x=alt.X("measure:N", sort=None, title=None, axis=alt.Axis(labelAngle=0)),
        y=alt.Y("size:Q", title="Size of the uncertainty"),
        color=alt.Color("measure:N", legend=None, scale=alt.Scale(
            domain=["True spread", "Plain SE", "Clustered SE"],
            range=["#636363", "#d62728", "#2ca02c"])),
        tooltip=[alt.Tooltip("size:Q", format=".3f")],
    ).properties(width=260, height=260, title="Which standard error is honest?")
    return (chart2b,)


@app.cell
def _(G2, chart2a, chart2b, cover_clus2, cover_plain2, mo, tcrit2):
    mo.vstack([
        mo.hstack([chart2a, chart2b], justify="start"),
        mo.hstack([
            mo.stat(f"{cover_plain2:.0%}", label="Plain 95% intervals that cover the truth"),
            mo.stat(f"{cover_clus2:.0%}", label="Clustered 95% intervals that cover the truth"),
        ], justify="start", gap=2),
        mo.md(
            f"""
            **What to see.**
            Set the link to 0: the years are independent, and both standard errors agree.
            Raise it: the plain SE stays small, the true spread grows, and plain
            intervals miss far more than 5% of the time. The plain SE is **overconfident**.
            The clustered SE tracks the true spread.

            **Few schools.** With {G2} schools, Stata builds the clustered interval
            with a multiplier of {tcrit2:.2f} instead of 1.96. Try 3 schools with a
            strong link: even the clustered SE is now smaller than the true spread,
            and only the big multiplier (4.30) rescues it, so the intervals are very wide.
            Clustering needs many schools; three schools (Maple, Oak, Pine) are far too few.
            """
        ),
    ])
    return


@app.cell
def _(mo):
    mo.md(r"""
    ---
    ## 3. Why does free lunch stop being significant with fixed effects?

    In Papke's data, the free-lunch coefficient is **−0.58** (pooled, clearly
    significant) but **−0.16** with fixed effects, with an interval that
    crosses zero. Here we build fake schools that behave the same way:

    - schools differ a lot in free lunch (**between** schools, spread about 25 points);
    - a school's free-lunch share barely moves from year to year (**within**, about 5 points);
    - poorer schools also have *other* disadvantages we do not observe.

    The **true** effect of free lunch (inside a school) is **−0.15**.
    """)
    return


@app.cell
def _(mo):
    within_sd = mo.ui.slider(1, 20, value=5, step=1,
                             label="How much free lunch moves inside a school (points)")
    hidden = mo.ui.slider(0.0, 0.8, value=0.45, step=0.05,
                          label="Hidden disadvantage of poorer schools")
    redraw3 = mo.ui.button(value=0, on_click=lambda v: v + 1,
                           label="Draw new schools")
    mo.vstack([within_sd, hidden, redraw3])
    return hidden, redraw3, within_sd


@app.cell
def _(hidden, np, pd, redraw3, within_sd):
    # 200 schools x 6 years. school_lunch = the school's usual level;
    # quality = what we do not observe (worse in poorer schools).
    G3, YEARS3, TRUE_B3 = 200, 6, -0.15
    rng3 = np.random.default_rng(300 + redraw3.value)
    school_lunch = np.clip(rng3.normal(37, 25, size=G3), 2, 95)
    quality = -hidden.value * (school_lunch - 37) + rng3.normal(0, 8, size=G3)
    lunch3 = school_lunch[:, None] + rng3.normal(0, within_sd.value, size=(G3, YEARS3))
    lunch3 = np.clip(lunch3, 0, 100)
    math3 = 60 + quality[:, None] + TRUE_B3 * lunch3 + rng3.normal(0, 18, size=(G3, YEARS3))

    panel3 = pd.DataFrame({
        "school": np.repeat(np.arange(1, G3 + 1), YEARS3),
        "year": np.tile(np.arange(1994, 1994 + YEARS3), G3),
        "lunch": lunch3.ravel(),
        "math4": math3.ravel(),
    })
    return G3, TRUE_B3, lunch3, math3, panel3


@app.cell
def _(G3, T975, cluster_se, lunch3, math3, np, pd):
    # Pooled OLS: one line through all school-years.
    xd_p = lunch3 - lunch3.mean()
    b_pool = (xd_p * (math3 - math3.mean())).sum() / (xd_p**2).sum()
    e_pool = (math3 - math3.mean()) - b_pool * xd_p
    se_pool = cluster_se(xd_p[None], e_pool[None])[0]

    # Fixed effects: subtract each school's own average first (demeaning).
    xd_fe = lunch3 - lunch3.mean(axis=1, keepdims=True)
    yd_fe = math3 - math3.mean(axis=1, keepdims=True)
    b_fe = (xd_fe * yd_fe).sum() / (xd_fe**2).sum()
    e_fe = yd_fe - b_fe * xd_fe
    se_fe = cluster_se(xd_fe[None], e_fe[None], k=1)[0]

    # Both with clustered standard errors, as in the Stata file.
    t3 = T975[G3 - 1]
    ci3 = pd.DataFrame({
        "model": ["Pooled OLS", "Fixed effects"],
        "estimate": [b_pool, b_fe],
        "low": [b_pool - t3 * se_pool, b_fe - t3 * se_fe],
        "high": [b_pool + t3 * se_pool, b_fe + t3 * se_fe],
    })
    ci3["significant"] = np.where((ci3["high"] < 0) | (ci3["low"] > 0), "yes", "no")
    within_share = xd_fe.std() / lunch3.std()
    return ci3, within_share


@app.cell
def _(alt, panel3):
    # Eight schools, spread from low to high poverty: one colour per school.
    picks3 = panel3.groupby("school")["lunch"].mean().sort_values()
    chosen3 = picks3.index[[5, 30, 60, 90, 115, 140, 170, 195]]
    few3 = panel3[panel3["school"].isin(chosen3)]
    chart3a = alt.Chart(few3).mark_line(point=True).encode(
        x=alt.X("lunch:Q", title="Students eligible for free lunch (%)",
                scale=alt.Scale(domain=[0, 100])),
        y=alt.Y("math4:Q", title="Math pass rate (%)", scale=alt.Scale(zero=False)),
        color=alt.Color("school:N", legend=None),
        order="year:O",
        tooltip=["school", "year", alt.Tooltip("lunch:Q", format=".1f"),
                 alt.Tooltip("math4:Q", format=".1f")],
    ).properties(width=330, height=280, title="Eight schools, 6 years each")
    return (chart3a,)


@app.cell
def _(TRUE_B3, alt, ci3):
    rules3 = alt.Chart(ci3).mark_rule(strokeWidth=5).encode(
        y=alt.Y("model:N", sort=None, title=None),
        x=alt.X("low:Q", title="Free-lunch coefficient, 95% interval",
                scale=alt.Scale(domain=[-1.0, 0.4])),
        x2="high:Q",
        color=alt.Color("model:N", legend=None,
                        scale=alt.Scale(range=["#1f4e9c", "#7f7f7f"])),
    )
    dots3 = alt.Chart(ci3).mark_point(filled=True, size=120, color="black").encode(
        y=alt.Y("model:N", sort=None), x="estimate:Q",
        tooltip=[alt.Tooltip("estimate:Q", format=".3f"),
                 alt.Tooltip("low:Q", format=".3f"), alt.Tooltip("high:Q", format=".3f")])
    zero3 = alt.Chart().mark_rule(color="red", strokeDash=[6, 4]).encode(x=alt.datum(0))
    truth3 = alt.Chart().mark_rule(color="black", strokeDash=[2, 2]).encode(
        x=alt.datum(TRUE_B3))
    chart3b = (rules3 + dots3 + zero3 + truth3).properties(
        width=330, height=280, title="Red dashes = no effect; black dots = truth (−0.15)")
    return (chart3b,)


@app.cell
def _(chart3a, chart3b, ci3, mo, within_share):
    pool3, fe3 = ci3.iloc[0], ci3.iloc[1]
    mo.vstack([
        mo.hstack([chart3a, chart3b], justify="start"),
        mo.hstack([
            mo.stat(f"{pool3.estimate:.2f}", label="Pooled estimate",
                    caption=f"[{pool3.low:.2f}, {pool3.high:.2f}], significant: {pool3.significant}"),
            mo.stat(f"{fe3.estimate:.2f}", label="Fixed-effects estimate",
                    caption=f"[{fe3.low:.2f}, {fe3.high:.2f}], significant: {fe3.significant}"),
            mo.stat(f"{within_share:.0%}", label="Share of lunch variation inside schools"),
        ], justify="start", gap=2),
        mo.md(
            r"""
            **What to see.**

            - **Pooled is wrong and too sure.** It compares poor schools with rich
              schools, so it also picks up their hidden disadvantages. Its interval is
              narrow and sits far from the truth. Set the hidden disadvantage to 0:
              pooled moves to the truth.
            - **Fixed effects is right but unsure.** It only uses each school's moves
              from year to year (the short left-right wiggles in the left picture).
              Those moves are small, so there is little evidence and the interval is wide;
              it often crosses zero.
            - **"Not significant" does not mean "no effect".** Increase how much free lunch
              moves inside a school: the fixed-effects interval shrinks and eventually
              excludes zero. The effect was there all along; we lacked the evidence.
            """
        ),
    ])
    return


if __name__ == "__main__":
    app.run()
