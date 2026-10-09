# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "marimo",
#     "numpy",
#     "pandas",
#     "altair",
#     "matplotlib",
#     "wigglystuff",
# ]
# ///
# Week 6 -- Looking under the hood of `regress wage educ`
#
# Run with:   marimo run week06_hood_notebook.py     (app view, code hidden)
#   or with:  marimo edit week06_hood_notebook.py    (see and change the code)
#
# Data: public/wage1.csv = Wooldridge's WAGE1 (526 US workers, 1976),
# written by week06_hood_prepare_data.do. Goes with
# week06-Looking-under-the-Hood-Stata.do and the lecture notes PDF.
#
# Prepared with the help of Claude (Anthropic), checked by the instructor.

import marimo

__generated_with = "0.25.0"
app = marimo.App(width="medium")


@app.cell
def _():
    import marimo as mo
    import numpy as np
    import pandas as pd
    import altair as alt
    from math import lgamma, sqrt
    import os
    import sys
    from concurrent.futures import ThreadPoolExecutor

    _ = alt.data_transformers.disable_max_rows()  # big charts are fine (we bin the slopes first)
    return ThreadPoolExecutor, alt, lgamma, mo, np, os, pd, sqrt, sys


@app.cell
def _(mo):
    mo.md(r"""
    # Looking under the hood of `regress wage educ`

    In 1976, 526 American workers told a survey their **hourly wage** and
    their **years of schooling**. One line of Stata, `regress wage educ`,
    gave us the table below. Today we earn the **yellow** numbers:

    1. **Nobody beats Stata.** Where do the two coefficients come from?
    2. **Rerun 1976.** What do the standard error, the t-statistic and the
       95% confidence interval actually mean?
    """)
    return


@app.cell
def _(mo, np, pd):
    # Load the real data. On your laptop and in the browser version the file sits
    # next to the notebook. On molab only the notebook is copied, so we read the
    # same file from the course's GitHub repository instead.
    GITHUB_CSV = ("https://raw.githubusercontent.com/iamsurajkumar/"
                  "econ2228-bc-econometrics-stata-lab/main/lectures/week-06/public/wage1.csv")
    try:
        workers = pd.read_csv(str(mo.notebook_location() / "public" / "wage1.csv"))
    except OSError:  # file not found next to the notebook (e.g. on molab)
        workers = pd.read_csv(GITHUB_CSV)

    x = workers["educ"].to_numpy(dtype=float)   # years of schooling
    y = workers["wage"].to_numpy(dtype=float)   # dollars per hour (1976)
    n = len(y)                                  # 526 workers

    # Each dot gets a small random sideways nudge (display only), because many
    # workers share the same years of schooling and would hide behind each other.
    workers["educ_jit"] = x + np.random.default_rng(7).uniform(-0.25, 0.25, n)
    return n, workers, x, y


@app.cell
def _(lgamma, np, sqrt):
    def t_pdf(v, df):
        # Height of the t curve with df degrees of freedom.
        const = np.exp(lgamma((df + 1) / 2) - lgamma(df / 2)) / sqrt(df * np.pi)
        return const * (1 + np.asarray(v) ** 2 / df) ** (-(df + 1) / 2)

    def t_tail(t, df):
        # Area to the RIGHT of t: Stata's ttail(df, t) (Simpson's rule from 0 to |t|).
        grid = np.linspace(0, abs(t), 2001)
        f = t_pdf(grid, df)
        middle = (grid[1] - grid[0]) / 3 * (f[0] + 4 * f[1:-1:2].sum() + 2 * f[2:-1:2].sum() + f[-1])
        return max(0.5 - middle, 0.0) if t >= 0 else 0.5 + middle

    def t_crit(area, df):
        # The t that leaves `area` in the right tail: Stata's invttail(df, area).
        lo, hi = 0.0, 100.0
        for _ in range(60):
            mid_t = (lo + hi) / 2
            lo, hi = (mid_t, hi) if t_tail(mid_t, df) > area else (lo, mid_t)
        return (lo + hi) / 2

    return t_crit, t_pdf, t_tail


@app.cell
def _(n, np, t_crit, t_tail, x, y):
    # Every number in the regress table, computed by hand (same formulas as the
    # do-file). `ols` is a dictionary: ols["b1"] is the slope, and so on.
    xbar, ybar = x.mean(), y.mean()
    sst_x = ((x - xbar) ** 2).sum()
    b1 = ((x - xbar) * (y - ybar)).sum() / sst_x
    b0 = ybar - b1 * xbar
    yhat = b0 + b1 * x
    uhat = y - yhat
    ssr = (uhat ** 2).sum()
    sst = ((y - ybar) ** 2).sum()
    sse = ((yhat - ybar) ** 2).sum()
    df_r = n - 2
    sigma = np.sqrt(ssr / df_r)
    se1 = sigma / np.sqrt(sst_x)
    se0 = sigma * np.sqrt(1 / n + xbar ** 2 / sst_x)
    tc = t_crit(0.025, df_r)
    ols = dict(
        xbar=xbar, ybar=ybar, sst_x=sst_x, b1=b1, b0=b0, uhat=uhat,
        ssr=ssr, sst=sst, sse=sse, df_r=df_r, df_t=n - 1,
        ms_m=sse, ms_r=ssr / df_r, ms_t=sst / (n - 1),
        r2=sse / sst, adj_r2=1 - (ssr / df_r) / (sst / (n - 1)), rmse=sigma,
        se1=se1, se0=se0, t1=b1 / se1, t0=b0 / se0, tc=tc,
        p1=2 * t_tail(abs(b1 / se1), df_r), p0=2 * t_tail(abs(b0 / se0), df_r),
        lo1=b1 - tc * se1, hi1=b1 + tc * se1, lo0=b0 - tc * se0, hi0=b0 + tc * se0,
        F=sse / (ssr / df_r),
    )
    ols["pF"] = 2 * t_tail(np.sqrt(ols["F"]), df_r)  # with one x, F = t² so Prob > F = P>|t|
    return (ols,)


@app.cell
def _(mo, n, ols):
    def g(v, digits=7):
        # Stata-style number: 7 significant digits, no leading zero (.5413593).
        s = f"{v:.{digits}g}"
        return s.replace("0.", ".", 1) if s.startswith(("0.", "-0.")) else s

    def stata_table(yellow):
        # Draw Stata's regress table, highlighting the numbers whose key is in `yellow`.
        def c(key, text, width):
            pad = " " * max(width - len(text), 0)
            if key in yellow:
                text = f'<mark style="background:#ffe066">{text}</mark>'
            return pad + text

        o = ols
        rows = [
            "      Source |       SS           df       MS      Number of obs   = " + f"{n:>9}",
            "-------------+----------------------------------   F(1, 524)       = " + f"{o['F']:>9.2f}",
            "       Model |" + f"{g(o['sse'], 9):>12}{1:>10}{g(o['ms_m'], 9):>12}"
            + "   Prob > F        = " + f"{o['pF']:>9.4f}",
            "    Residual |" + f"{g(o['ssr'], 9):>12}{o['df_r']:>10}{g(o['ms_r'], 9):>12}"
            + "   R-squared       = " + f"{o['r2']:>9.4f}",
            "-------------+----------------------------------   Adj R-squared   = " + f"{o['adj_r2']:>9.4f}",
            "       Total |" + f"{g(o['sst'], 9):>12}{o['df_t']:>10}{g(o['ms_t'], 9):>12}"
            + "   Root MSE        = " + f"{o['rmse']:>9.4f}",
            "",
            "-" * 78,
            "        wage | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]",
            "-------------+----------------------------------------------------------------",
            "        educ | " + c("b", g(o["b1"]), 10) + c("se", g(o["se1"], 6), 11) + c("t", f"{o['t1']:.2f}", 9)
            + f"{o['p1']:>8.3f}" + c("ci", g(o["lo1"]), 13) + c("ci", g(o["hi1"]), 12),
            "       _cons | " + c("b", g(o["b0"]), 10) + f"{g(o['se0']):>11}{o['t0']:>9.2f}"
            + f"{o['p0']:>8.3f}{g(o['lo0']):>13}{g(o['hi0']):>12}",
            "-" * 78,
        ]
        return mo.Html('<pre style="font-size:13px; line-height:1.35; background:#f6f6f6; '
                       'padding:10px; border-radius:6px; overflow-x:auto">'
                       + "\n".join(rows) + "</pre>")

    stata_table({"b", "se", "t", "ci"})
    return (stata_table,)


@app.cell
def _(mo):
    mo.md(r"""
    ---
    ## 1. Nobody beats Stata

    A straight line needs two numbers: an **intercept** (where it starts)
    and a **slope** (how steeply it climbs). So every possible line is one
    **point** on the map below: slope across, intercept up.

    For every worker, a line makes a guess. The **miss** (the *residual*) is
    the real wage minus the guess. A line's **score** is: square every miss,
    then add them all up. Lower is better. The map is coloured by score:
    **yellow = low, purple = high**.

    **Drag the red puck** to try a line; the box on the right compares your
    line with Stata's (the gold star). Can you find a spot with a lower score?
    """)
    return


@app.cell
def _(np, ols, x, y):
    # Score of every line on a 61 x 61 grid of (slope, intercept) pairs.
    # score[i, j] = sum of squared misses for intercept i and slope j.
    slope_range = (ols["b1"] - 0.4, ols["b1"] + 0.4)
    icept_range = (ols["b0"] - 4.0, ols["b0"] + 4.0)
    grid_slopes = np.linspace(*slope_range, 61)
    grid_iceps = np.linspace(*icept_range, 61)
    _B1, _B0 = np.meshgrid(grid_slopes, grid_iceps)
    _fits = _B0[..., None] + _B1[..., None] * x            # every line's guess for every worker
    grid_score = ((y - _fits) ** 2).sum(axis=-1)
    return grid_iceps, grid_score, grid_slopes, icept_range, slope_range


@app.cell
def _(
    grid_iceps,
    grid_score,
    grid_slopes,
    icept_range,
    mo,
    np,
    ols,
    slope_range,
    x,
    y,
):
    from wigglystuff import ChartPuck

    def draw_map(ax, widget):
        # Redrawn every time the puck moves. Left: the map, coloured by
        # log(score) so the deep valley shows up. Right: you vs Stata.
        ax.figure.subplots_adjust(left=0.11, right=0.62, bottom=0.13, top=0.95)
        ax.contourf(grid_slopes, grid_iceps, np.log(grid_score), levels=30, cmap="viridis_r")
        ax.contour(grid_slopes, grid_iceps, np.log(grid_score), levels=15, colors="white", linewidths=0.4)
        ax.plot(ols["b1"], ols["b0"], marker="*", markersize=18, color="#ffd700", markeredgecolor="black")
        ax.set_xlabel("Slope (extra $ per year of school)")
        ax.set_ylabel("Intercept ($ at 0 years of school)")

        b1, b0 = widget.x[0], widget.y[0]
        score = float(((y - b0 - b1 * x) ** 2).sum())
        gap = score / ols["ssr"] - 1
        panel = (f"            YOU      STATA\n"
                 f"intercept {b0:7.3f}  {ols['b0']:7.3f}\n"
                 f"slope     {b1:7.3f}  {ols['b1']:7.3f}\n"
                 f"score    {score:8.1f} {ols['ssr']:8.1f}\n\n"
                 + ("On the valley floor:\nno lower score exists."
                    if gap < 0.002 else f"Your score is {gap:.1%}\nworse than Stata's."))
        ax.text(1.05, 0.5, panel, transform=ax.transAxes, va="center", ha="left",
                family="monospace", fontsize=10,
                bbox=dict(boxstyle="round,pad=0.6", facecolor="#f6f6f6", edgecolor="#ccc"))

    # ChartPuck.from_callback: a draggable dot on a matplotlib picture that is
    # redrawn by draw_map whenever the dot moves. puck.x / puck.y are lists
    # (one entry per puck) in the chart's own units.
    # throttle=80: send the position at most every 80 ms while dragging.
    puck = mo.ui.anywidget(ChartPuck.from_callback(
        draw_map, x_bounds=slope_range, y_bounds=icept_range, figsize=(9.5, 4.6),
        x=float(ols["b1"] - 0.3), y=float(ols["b0"] + 3.0), throttle=80, puck_color="#d62728"))
    puck
    return (puck,)


@app.cell
def _(alt, mo, ols, pd, puck, workers, x, y):
    # The puck's position is the line you chose.
    my_b1, my_b0 = float(puck.x[0]), float(puck.y[0])
    my_score = float(((y - my_b0 - my_b1 * x) ** 2).sum())

    _dots = workers.assign(fit=my_b0 + my_b1 * workers["educ_jit"])
    # Residual = real wage - guess. Positive: the worker earns MORE than the line says.
    _dots["miss"] = (_dots["wage"] > _dots["fit"]).map(
        {True: "positive: earns more than the line guesses", False: "negative: earns less than the line guesses"})
    _n_pos = int((_dots["wage"] > _dots["fit"]).sum())
    _xs = pd.DataFrame({"educ_jit": [-0.5, 18.5]})
    _scale_y = alt.Scale(domain=[-2, 26])
    _sticks = alt.Chart(_dots).mark_rule(opacity=0.5, clip=True).encode(
        x="educ_jit:Q", y=alt.Y("wage:Q", scale=_scale_y), y2="fit:Q",
        color=alt.Color("miss:N", title="Residual",
                        scale=alt.Scale(domain=["positive: earns more than the line guesses",
                                                "negative: earns less than the line guesses"],
                                        range=["#1f77b4", "#d62728"]),
                        legend=alt.Legend(orient="top-left")))
    _cloud = alt.Chart(_dots).mark_circle(size=22, color="#555", opacity=0.6, clip=True).encode(
        x=alt.X("educ_jit:Q", title="Years of schooling (educ)", scale=alt.Scale(domain=[-0.5, 18.5])),
        y=alt.Y("wage:Q", title="Hourly wage, $ (1976)", scale=_scale_y))
    _mine = alt.Chart(_xs.assign(fit=my_b0 + my_b1 * _xs["educ_jit"])).mark_line(
        color="black", strokeWidth=3, clip=True).encode(x="educ_jit:Q", y="fit:Q")

    _gap = my_score / ols["ssr"] - 1
    _verdict = ("🏆 **You are on the bottom of the valley, right next to Stata's star. "
                "Nobody gets below 5,980.68.**" if _gap < 0.002 else
                f"Your line's score is **{_gap:.1%} worse** than Stata's. Drag toward the yellow valley!")
    mo.vstack([
        mo.md(f"**Your line** (black): wage = {my_b0:.3f} + {my_b1:.3f} × educ. "
              f"Blue sticks: workers above the line ({_n_pos}). Red sticks: workers below it ({len(_dots) - _n_pos})."),
        (_sticks + _cloud + _mine).properties(width=620, height=340),
        mo.hstack([
            mo.stat(f"{my_score:,.2f}", label="Your score (sum of squared misses)"),
            mo.stat(f"{ols['ssr']:,.2f}", label="Stata's score"),
        ], justify="start", gap=2),
        mo.md(_verdict),
    ])
    return my_b0, my_b1, my_score


@app.cell
def _(mo):
    mo.md(r"""
    ### The same map in 3D: a bowl

    Lift every point of the map to the height of its score and you get a
    **bowl** (a long, narrow one). The red ball is your line; the gold ball
    is Stata's, at the **very bottom**. Drag to spin, scroll to zoom.
    Notice it is a long **valley**, not a round bowl: a steeper line with a
    lower start scores almost as well, so you can slide along the valley floor
    and barely climb. Only one spot on that floor is the lowest.
    """)
    return


@app.cell
def _(grid_iceps, grid_score, grid_slopes, mo, np, ols):
    import matplotlib as _mpl
    from wigglystuff import ThreeWidget

    _top = grid_score.max()

    def to_box(slope, icept, score):
        # Squeeze (slope, intercept, score) into a box the widget can draw:
        # slope and intercept run -1..1 across the map, height runs 0 (Stata) to 1.2 (worst line).
        return {"x": float((slope - ols["b1"]) / 0.4),
                "z": float(-(icept - ols["b0"]) / 4.0),
                "y": float(1.2 * (score - ols["ssr"]) / (_top - ols["ssr"]))}

    _cmap = _mpl.colormaps["viridis_r"]
    bowl_points = []
    for _i, _b0 in enumerate(grid_iceps):
        for _j, _b1 in enumerate(grid_slopes):
            _p = to_box(_b1, _b0, grid_score[_i, _j])
            _p.update(color=_mpl.colors.to_hex(_cmap(np.sqrt(_p["y"] / 1.2))), size=0.035)
            bowl_points.append(_p)


    def stem(slope, icept, score, color):
        # A ball plus dotted guide lines down to the floor and out to the two
        # floor edges, so you can read off where the ball sits.
        top = to_box(slope, icept, score)
        pts = [{**top, "color": color, "size": 0.16}]
        for _k in range(1, 25):
            _f = _k / 25
            pts.append({"x": top["x"], "y": top["y"] * _f, "z": top["z"], "color": color, "size": 0.025})
            pts.append({"x": top["x"], "y": 0.0, "z": top["z"] + (-0.72 - top["z"]) * _f, "color": color, "size": 0.02})
            pts.append({"x": top["x"] + (-0.72 - top["x"]) * _f, "y": 0.0, "z": top["z"], "color": color, "size": 0.02})
        return pts

    bowl_points += stem(ols["b1"], ols["b0"], ols["ssr"], "#e6b800")

    bowl = mo.ui.anywidget(ThreeWidget(data=bowl_points, width=900, height=580, show_grid=True,
                                       show_axes=True, axis_labels=[f"slope ({grid_slopes[0]:.2f} → {grid_slopes[-1]:.2f})",
                                                    "score (sum of squared residuals)",
                                                    f"intercept ({grid_iceps[-1]:.1f} → {grid_iceps[0]:.1f})"],
                                       # Limits a bit inside the bowl, so the camera starts zoomed in.
                                       xlim=(-0.72, 0.72), ylim=(0, 0.8), zlim=(-0.72, 0.72),
                                       camera_azimuth=35, camera_elevation=28))
    bowl
    return bowl, bowl_points, stem


@app.cell
def _(bowl, bowl_points, mo, my_b0, my_b1, my_score, ols, stem):
    # Move the red ball (and its guide lines) whenever the puck moves; the bowl
    # itself is not redrawn, so your spin and zoom stay put.
    bowl.widget.data = bowl_points + stem(my_b1, my_b0, my_score, "#d62728")
    mo.md(f"""
    <div style="font-family:monospace; font-size:15px; line-height:1.6">
    <span style="color:#d62728">● YOU  </span> slope = {my_b1:.4f} &nbsp; intercept = {my_b0:7.4f} &nbsp; score = {my_score:10,.1f}<br>
    <span style="color:#e6b800">● STATA</span> slope = {ols["b1"]:.4f} &nbsp; intercept = {ols["b0"]:7.4f} &nbsp; score = {ols["ssr"]:10,.1f}
    </div>
    <small>Dotted lines drop from each ball to the floor and run out to the slope and intercept edges. Scroll inside the box to zoom, drag to spin.</small>
    """)
    return


@app.cell
def _(mo, ols, x, y):
    _sxy = ((x - ols["xbar"]) * (y - ols["ybar"])).sum()
    mo.md(rf"""
    **Stata never guesses.** A bit of algebra (the bottom of a bowl is where
    it is flat in every direction) finds the bottom exactly:

    $$
    \hat\beta_1=\frac{{\sum_i (x_i-\bar x)(y_i-\bar y)}}{{\sum_i (x_i-\bar x)^2}}
    = \frac{{{_sxy:,.3f}}}{{{ols['sst_x']:,.3f}}} = {ols['b1']:.7f}
    $$

    $$
    \hat\beta_0=\bar y-\hat\beta_1\,\bar x = {ols['ybar']:.4f} - {ols['b1']:.4f}\times{ols['xbar']:.4f} = {ols['b0']:.7f}
    $$

    One more year of school ↔ about **54 cents** more per hour (1976 dollars).
    The bowl is long and narrow because slope and intercept can trade off:
    a steeper line with a lower start scores almost as well.
    """)
    return


@app.cell
def _(mo, ols):
    mo.md(rf"""
    ---
    ## 2. Rerun 1976

    Our slope is **{ols['b1']:.3f}**. But every wage contains some **luck**
    (the residual). With different luck, would a survey still find 0.54?

    Let's build a **pretend world** where we *know* the truth:

    $$\text{{wage}} = {ols['b0']:.3f} + {ols['b1']:.3f}\times\text{{educ}} + \text{{luck}}$$

    so the **true slope is {ols['b1']:.3f}**. Each rerun of the survey asks
    **n** workers. Each worker's schooling is drawn from the real 1976 workers,
    and their luck is drawn out of a hat holding the 526 real residuals (each
    one put back after drawing), so a pretend survey can even be bigger than
    the real one. Then we run `regress` on that survey.
    We repeat the survey as many times as you like.

    **Hover** over a slider to preview a value; **click** to keep it.
    """)
    return


@app.cell
def _(mo):
    from wigglystuff import HoverSlider

    # HoverSlider: like a slider, but it also reports where the mouse is hovering
    # (hover_value), so the charts update while you sweep across the track.
    # sync_throttle_ms=150: send at most ~7 updates a second while hovering.
    # Both sliders' steps roughly double each time (like a log scale). 526 is the
    # real survey's size, where the SE should match Stata's. Above 100,000 surveys
    # each rerun takes about a second (longer in the browser version), so CLICK there.
    n_survey = mo.ui.anywidget(HoverSlider(steps=[25, 50, 100, 200, 526, 1000, 2000, 5000], value=526,
                                           label="Workers in each survey (n)", sync_throttle_ms=150, width=260))
    n_reps = mo.ui.anywidget(HoverSlider(steps=[1, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000,
                                                20000, 50000, 100000, 200000, 500000, 1000000],
                                         value=2000, label="Number of surveys", sync_throttle_ms=250,
                                         width=260))
    # How wide each interval is, in SEs either side of the slope:  slope ± k × SE.
    # The surveys (and their SEs) stay the same, so moving it does not rerun them;
    # the dashboard turns k into the confidence it buys (1.96 SE -> 95%).
    n_ses = mo.ui.anywidget(HoverSlider(steps=[0.5, 1, 1.5, 1.65, 1.96, 2.5, 2.58, 3, 3.5], value=1.96,
                                        label="Interval: ± how many SEs", sync_throttle_ms=100, width=260))
    redraw = mo.ui.button(value=0, on_click=lambda v: v + 1, label="🎲 Rerun the surveys")
    mo.hstack([n_survey, n_reps, n_ses, redraw], justify="start", gap=2)
    return n_reps, n_ses, n_survey, redraw


@app.cell
def _(ThreadPoolExecutor, n, n_reps, n_survey, np, ols, os, redraw, sys, x):
    # R reruns of the survey, each with m workers (rows = reruns). We read the
    # HOVER value, so the charts follow the mouse; it equals the clicked value
    # once the mouse leaves the slider.
    _m = int(n_survey.value["hover_value"])
    rr_asked = int(n_reps.value["hover_value"])
    # Cap the work at 1 billion worker-rows (about 2 seconds on a laptop): 1,000,000
    # surveys of up to 1,000 workers fit, but bigger surveys get fewer reruns.
    rr_reps = min(rr_asked, 1_000_000_000 // _m)

    def _one_batch(reps, rng):
        # `reps` surveys of _m workers at once: rows = surveys, columns = workers.
        # In the pretend world  wage = b0 + b1*educ + luck,  so each survey's slope and
        # SE come from five sums of educ (x) and luck (u) alone; no residual table needed:
        #   slope = b1 + Sxu / Sxx,    SSR = Suu - Sxu^2 / Sxx    (S = centred sums)
        xs = x[rng.integers(0, n, size=(reps, _m), dtype=np.int16)]               # schooling
        us = ols["uhat"][rng.integers(0, n, size=(reps, _m), dtype=np.int16)]     # luck
        sx, su = xs.sum(axis=1), us.sum(axis=1)
        sxx = np.einsum("ij,ij->i", xs, xs) - sx * sx / _m                         # row-by-row dot products
        sxu = np.einsum("ij,ij->i", xs, us) - sx * su / _m
        suu = np.einsum("ij,ij->i", us, us) - su * su / _m
        gap = sxu / sxx                                                            # this survey's slope - truth
        return ols["b1"] + gap, np.sqrt((suu - gap * sxu) / (_m - 2) / sxx)        # slope, and the SE Stata prints

    # Run the surveys in batches of about 1 million worker-rows, spread over the
    # computer's CPU cores (threads). Each batch gets its own random stream, so the
    # result is the same however many cores run it. The browser version (WASM)
    # has no threads, so there the batches run one after another.
    _size = max(20, 1_000_000 // _m)
    _starts = range(0, rr_reps, _size)
    _streams = np.random.SeedSequence(100 + redraw.value).spawn(len(_starts))
    _jobs = [(min(_size, rr_reps - _s), np.random.default_rng(_ss)) for _s, _ss in zip(_starts, _streams)]
    if sys.platform == "emscripten":
        _batches = [_one_batch(*_j) for _j in _jobs]
    else:
        with ThreadPoolExecutor(max_workers=os.cpu_count()) as _pool:
            _batches = list(_pool.map(lambda _j: _one_batch(*_j), _jobs))
    rr_b1 = np.concatenate([_b for _b, _ in _batches])
    rr_se = np.concatenate([_se for _, _se in _batches])
    rr_m = _m

    return rr_asked, rr_b1, rr_m, rr_reps, rr_se


@app.cell
def _(
    alt,
    mo,
    n_ses,
    np,
    ols,
    pd,
    rr_asked,
    rr_b1,
    rr_m,
    rr_reps,
    rr_se,
    t_pdf,
    t_tail,
):
    # One dashboard for Steps A, B and C: both plots use the same surveys and the
    # same x-axis, so they update together when you move either slider.
    _se_avg = rr_se.mean()
    # You pick how many SEs either side (k); the t curve says what confidence that
    # buys: the area under it between -k and +k (1.96 -> 95%, 2.58 -> 99%).
    # The SEs do not change; only how many SEs wide each interval is.
    _tc = float(n_ses.value["hover_value"])
    _conf = 100 * (1 - 2 * t_tail(_tc, rr_m - 2))
    _lvl = f"{_conf:.1f}%"
    _lo_x = min(-0.05, ols["b1"] - max(4.5, _tc + 1) * _se_avg)      # always keep zero in view
    _hi_x = ols["b1"] + max(4.5, _tc + 1) * _se_avg
    _xscale = alt.Scale(domain=[_lo_x, _hi_x])

    # Left (Step A): every survey's slope, with the green "truth ± t_c SE" band.
    # One legend names every layer: each layer's data gets a "what" column holding
    # its label, and all layers share one colour scale, so the legend lists them in
    # this order.
    _names = {"bars": "Surveys: how many found each slope",
              "curve": "t curve: the spread Stata's SE predicts",
              "band": f"Green zone: truth ± {_tc:g} SE ({_lvl} of surveys)",
              "truth": f"True slope {ols['b1']:.3f}",
              "zero": "Zero: schooling does nothing"}
    _leg = alt.Scale(domain=list(_names.values()),
                     range=["#1f77b4", "#ff7f0e", "#b9dfb4", "#2ca02c", "black"])
    _key = lambda legend=None: alt.Color("what:N", scale=_leg, legend=legend)
    _band = alt.Chart(pd.DataFrame({"lo": [ols["b1"] - _tc * _se_avg], "hi": [ols["b1"] + _tc * _se_avg],
                                    "what": [_names["band"]]})).mark_rect(opacity=0.4).encode(x=alt.X("lo:Q", scale=_xscale), x2="hi:Q",
                                             color=_key(alt.Legend(
                                                 title=None, orient="bottom", direction="vertical",
                                                 symbolType="square", labelLimit=400, labelFontSize=12)))
    # Bin the slopes ourselves (60 bins), so plot A gets the same round axis ticks as plot C.
    _counts, _edges = np.histogram(rr_b1, bins=60, range=(_lo_x, _hi_x))
    _bins = pd.DataFrame({"left": _edges[:-1], "right": _edges[1:], "count": _counts, "what": _names["bars"]})
    _hist = alt.Chart(_bins).mark_rect(opacity=0.85).encode(color=_key(),
    
        x=alt.X("left:Q", scale=_xscale, title="Slope found in each survey"), x2="right:Q",
        y=alt.Y("count:Q", title="Number of surveys"), y2=alt.datum(0))
    _truth_a = alt.Chart(pd.DataFrame({"v": [ols["b1"]], "what": [_names["truth"]]})).mark_rule(strokeWidth=2.5).encode(
        x=alt.X("v:Q", scale=_xscale), color=_key())
    # The t curve Stata's SE implies: a bell centred on the truth, as wide as the
    # average SE, scaled to counts (surveys × bin width × height). With few surveys
    # the bars are ragged; with many they fill the curve.
    _grid = np.linspace(_lo_x, _hi_x, 300)
    _bell = pd.DataFrame({"v": _grid, "count": rr_reps * (_edges[1] - _edges[0])
                          * t_pdf((_grid - ols["b1"]) / _se_avg, rr_m - 2) / _se_avg,
                          "what": _names["curve"]})
    _curve_a = alt.Chart(_bell).mark_line(strokeWidth=2.5).encode(
        x=alt.X("v:Q", scale=_xscale), y="count:Q", color=_key())
    _zero_a = alt.Chart(pd.DataFrame({"v": [0.0], "what": [_names["zero"]]})).mark_rule(strokeWidth=2.5).encode(
        x=alt.X("v:Q", scale=_xscale), color=_key())
    _chart_a = (_band + _hist + _curve_a + _truth_a + _zero_a).properties(
        width=450, height=340, title=f"A. Slopes from {rr_reps:,} surveys")

    # Right (Step C): the first (up to) 100 surveys, each with its interval at the chosen confidence level.
    _k = min(rr_reps, 100)
    _ci = pd.DataFrame({"survey": np.arange(1, _k + 1), "slope": rr_b1[:_k],
                        "low": rr_b1[:_k] - _tc * rr_se[:_k], "high": rr_b1[:_k] + _tc * rr_se[:_k],
                        "t": rr_b1[:_k] / rr_se[:_k]})
    _ci["covers"] = np.where((_ci["low"] <= ols["b1"]) & (_ci["high"] >= ols["b1"]), "yes", "no (miss)")
    _bars = alt.Chart(_ci).mark_rule(strokeWidth=2).encode(
        y=alt.Y("survey:O", axis=None),
        x=alt.X("low:Q", scale=_xscale, title=f"Slope ± {_tc:.2f} SE, one bar per survey"), x2="high:Q",
        color=alt.Color("covers:N", scale=alt.Scale(domain=["yes", "no (miss)"], range=["#4c78a8", "#d62728"]),
                        legend=alt.Legend(title="Covers 0.541?", orient="bottom")),
        tooltip=[alt.Tooltip("slope:Q", format=".3f"), alt.Tooltip("low:Q", format=".3f"),
                 alt.Tooltip("high:Q", format=".3f"), alt.Tooltip("t:Q", format=".2f")])
    _dots = alt.Chart(_ci).mark_point(filled=True, size=10, color="black").encode(
        y="survey:O", x=alt.X("slope:Q", scale=_xscale))
    _truth_c = alt.Chart(pd.DataFrame({"v": [ols["b1"]]})).mark_rule(color="black", strokeDash=[6, 4]).encode(
        x=alt.X("v:Q", scale=_xscale))
    _zero_c = alt.Chart(pd.DataFrame({"v": [0.0]})).mark_rule(color="black", strokeWidth=2.5).encode(
        x=alt.X("v:Q", scale=_xscale))
    _chart_c = (_bars + _dots + _truth_c + _zero_c).properties(
        width=450, height=340, title=f"C. {_lvl} intervals of the first {_k} of {rr_reps:,} surveys")

    # Step B, as one line above the plots.
    _t_all = rr_b1 / rr_se
    _reject = np.mean(np.abs(_t_all) > _tc)
    _hits = int((_ci["covers"] == "yes").sum())
    # Share of ALL surveys inside the green band (truth ± t_c × the average SE).
    _inside = np.mean(np.abs(rr_b1 - ols["b1"]) <= _tc * _se_avg)
    # Share of ALL surveys whose own interval covers the truth. With R surveys this
    # share wobbles around the level p by about ± 1.96 × sqrt(p (1 - p) / R).
    _cover = np.mean(np.abs(rr_b1 - ols["b1"]) <= _tc * rr_se)
    _p = _conf / 100
    _wobble = 1.96 * np.sqrt(_p * (1 - _p) / rr_reps)
    # The scorecard under the plots: one row per number, each with a plain-English
    # meaning and what it should be close to.
    _sd = rr_b1.std(ddof=1) if rr_reps > 1 else float("nan")
    _rows = [
        ("①", "Real wobble of the slope", "SD of all the slopes",
         "—" if rr_reps == 1 else f"{_sd:.4f}",
         f"Line up the slopes from all {rr_reps:,} surveys of {rr_m} workers: they typically sit this far "
         f"from the true {ols['b1']:.3f}. We can only see this because we reran the survey.",
         "the width of the blue histogram (plot A)"),
        ("②", "Stata's guess of ①", "average SE",
         f"{_se_avg:.4f}",
         f"Each survey's SE, worked out from that ONE survey alone (what Stata prints), averaged. "
         f"For the real 1976 table, n = 526: {ols['se1']:.4f}.",
         "should be close to ①" + ("" if rr_reps == 1 else f" (gap {_se_avg / _sd - 1:+.1%})")),
        ("③", "Slopes in the green zone", f"within truth ± {_tc:g} × ②",
         f"{_inside:.1%}",
         f"Share of the {rr_reps:,} slopes that land within {_tc:g} SEs of the truth: the bridge.",
         f"t curve promises {_lvl}"),
        ("④", "Intervals that catch 0.541", f"slope ± {_tc:g} × own SE",
         f"{_cover:.2%}",
         f"Each survey builds its own interval; this share contains the true slope. "
         f"Plot C draws the first {_k}: {_hits} of them hit.",
         f"promise {_lvl} (± {_wobble:.2%} luck with {rr_reps:,} surveys)"),
        ("⑤", "Surveys that rule out zero", f"|t| = |slope ÷ SE| > {_tc:g}",
         f"{_reject:.1%}",
         f"Share of surveys whose slope is more than {_tc:g} of its own SEs away from zero.",
         f"real 1976 survey: t = {ols['t1']:.2f}"),
    ]
    _cell = "padding:6px 10px; border-bottom:1px solid rgba(127,127,127,0.25); vertical-align:top"
    _body = "".join(
        f"<tr><td style='{_cell}; font-size:18px'>{_n}</td>"
        f"<td style='{_cell}'><b>{_name}</b><br><small style='opacity:0.7'>{_how}</small></td>"
        f"<td style='{_cell}; font-size:20px; font-weight:700; font-family:monospace; white-space:nowrap'>{_v}</td>"
        f"<td style='{_cell}'>{_mean}</td>"
        f"<td style='{_cell}; opacity:0.8'><small>{_chk}</small></td></tr>"
        for _n, _name, _how, _v, _mean, _chk in _rows)
    # The story that goes with the scorecard (read top to bottom with ① to ⑤).
    _story = mo.md(f"""
    ### 🕰️ The story: Stata the fortune-teller vs. you with a time machine

    **1976.** A survey team knocks on 526 doors, writes down wages and schooling, and
    goes home. Stata gets that ONE survey and announces: *"Each extra year of school
    pays {ols['b1']:.2f} dollars an hour, give or take {ols['se1']:.3f}."* That
    "give or take" is the **SE**. Bold claim from someone who has seen one survey.

    **You have a time machine** (this notebook). Go back and rerun the survey with
    fresh random workers: again, and again, a million times if you are bored. The
    rule of the world never changes (the true slope is {ols['b1']:.3f}); only the
    luck of who opens the door does.

    - **① The truth about wobble.** Your surveys disagree with each other. ①
      measures by how much. Only time travellers ever get to see this number.
    - **② Stata's prophecy.** Inside every rerun, Stata sees only its own
      {rr_m} workers and guesses the wobble anyway. ② is its average guess.
      **If ② ≈ ①, the fortune-teller is legit**, and that is why you can trust
      the {ols['se1']:.3f} in the real table *without* a time machine.
    - **③ The fine print of the prophecy.** *"{_lvl} of surveys will land within
      {_tc:g} SEs of the truth."* Count them: ③. (Green zone, plot A.)
    - **④ The fishing net.** In real life nobody knows the truth. So each survey
      throws a net, slope ± {_tc:g} SE, and hopes the fish ({ols['b1']:.3f}) is
      inside. ④ = share of nets that catch it. The red bars in plot C are the
      unlucky fishermen: they did nothing wrong, they just knocked on weird doors.
    - **⑤ Your uncle at dinner.** *"School does nothing!"* If he were right,
      slopes would hover around zero. ⑤ = share of surveys that prove him wrong.
      Our real survey sits {ols['t1']:.0f} SEs from zero. Sorry, uncle.

    **Plot twist:** a bigger net (more SEs, third slider) catches the fish more
    often but says less. "Between −3 and +5 dollars" is always right and totally
    useless. **Moral:** in real life you get no time machine, just one survey and
    its SE. This table is the proof that the SE is not lying.
    """)
    _head = "".join(f"<th style='{_cell}; text-align:left'>{_h}</th>"
                    for _h in ["", "Number", "Value", "What it means", "Compare with"])
    _scorecard = mo.Html(f"<table style='border-collapse:collapse; width:100%; font-size:14px'>"
                         f"<thead><tr>{_head}</tr></thead><tbody>{_body}</tbody></table>")
    mo.vstack([

        mo.md(f"### ± {_tc:g} SE  →  {_lvl} confidence  "
              f"<small>(area under the t curve between −{_tc:g} and +{_tc:g})</small>"),
        mo.callout(mo.md(
            f"**B. t-statistic.** Our real 1976 survey: t = {ols['b1']:.4f} ÷ {ols['se1']:.4f} = "
            f"**{ols['t1']:.2f}** SEs away from zero (black line). "
            f"A typical survey of **{rr_m} workers**: t ≈ {ols['b1']:.3f} ÷ {_se_avg:.3f} = **{ols['b1'] / _se_avg:.1f}**, "
            f"and **{_reject:.0%}** of these surveys have |t| > {_tc:.2f} (they would rule out zero)."),
            kind="info"),
        alt.hconcat(_chart_a, _chart_c).resolve_scale(color="independent"),
        *([mo.md(f"<small>⚠️ {rr_asked:,} surveys of {rr_m:,} workers would take too long here, "
                 f"so this run uses {rr_reps:,} surveys.</small>")] if rr_reps < rr_asked else []),
        mo.callout(_story, kind="neutral"),
        _scorecard,
    ])
    return


@app.cell
def _(mo, ols):
    mo.md(rf"""
    ### How to read the dashboard

    - **A (left): the surveys disagree, and their spread is the standard error.**
      The first two numbers under the plots match: one survey's SE predicts how
      much the slope would wobble if we reran it. With n = 526 it is about
      {ols['se1']:.3f}, Stata's number.
    - **The bridge:** about **95% of surveys land within 1.96 SE of the truth**
      (green band, third number). Steps B and C are this one sentence, used two ways.
    - **B (the blue line on top): the bridge, aimed at zero.** If the truth were
      "schooling does nothing" (0), 95% of surveys would land within 1.96 SE of
      zero. So we measure our slope's distance from zero in SEs:
      $t = \text{{slope}} / \text{{SE}} = {ols['t1']:.2f}$. Almost never happens if the
      truth is zero, so the truth is not zero.
    - **C (right): the bridge, read backwards.** "The slope lands within 1.96 SE
      of the truth" is the same distance as "the truth is within 1.96 SE of the
      slope". So slope ± {ols['tc']:.2f} SE catches the truth whenever the survey was
      one of the 95%. The bars that miss (red) are unlucky surveys, not mistakes.

    *Try:* drag **workers** down to 25. Both plots widen together, t shrinks
    toward 2, and now some surveys cannot rule out zero. Then sweep the
    **number of surveys**: the plots get smoother, but the spread barely moves. Finally move **± how many SEs**: the SEs stay put, only the
    width of each interval changes, and the notebook tells you the confidence it
    buys (± 1 SE → 68%, ± 1.96 → 95%, ± 2.58 → 99%). Wider bars miss less
    often, so the hit rate follows. That share is the area under the orange t
    curve between −k and +k SEs.
    """)
    return


@app.cell(hide_code=True)
def _(mo, n, ols, x):
    _sd_x = x.std()
    _k = ols["rmse"] / _sd_x
    mo.accordion({"📐 The maths: why the number of WORKERS changes the spread, but the number of SURVEYS does not": mo.md(rf"""
    **1. Workers per survey ($n$) change the true spread.** Stata's formula
    (derived in the lecture notes) is

    $$\text{{se}}(\hat\beta_1) = \frac{{\hat\sigma}}{{\sqrt{{\sum_i (x_i-\bar x)^2}}}} .$$

    The bottom is a sum over the $n$ workers in the survey. Each worker adds
    about $\text{{SD}}(x)^2 = {_sd_x:.2f}^2$ to it, so the sum is about
    $n\times {_sd_x:.2f}^2$, and

    $$\text{{se}}(\hat\beta_1) \approx \frac{{\hat\sigma}}{{\text{{SD}}(x)\,\sqrt{{n}}}}
      = \frac{{{ols['rmse']:.2f}}}{{{_sd_x:.2f}\,\sqrt{{n}}}} = \frac{{{_k:.2f}}}{{\sqrt{{n}}}} .$$

    | workers per survey $n$ | ${_k:.2f}/\sqrt{{n}}$ |
    |---:|---:|
    | 25 | {_k / 25 ** 0.5:.3f} |
    | 100 | {_k / 100 ** 0.5:.3f} |
    | 526 | {_k / n ** 0.5:.3f} |

    **Four times the workers, half the spread** (the $1/\sqrt{{n}}$ rule).
    More workers means more luck that cancels out inside each survey.

    **2. The number of surveys ($R$) does NOT change the true spread.**
    Each survey is still a survey of $n$ workers, so each one still wobbles
    by about ${_k:.2f}/\sqrt{{n}}$, however many of them we stack up. What
    $R$ changes is how **well we can measure** that spread. The SD of $R$
    slopes is itself a little noisy:

    $$\text{{measured SD}} \approx \text{{true SE}} \times \Bigl(1 \pm \frac{{1}}{{\sqrt{{2R}}}}\Bigr).$$

    | surveys $R$ | typical error of the measured SD |
    |---:|---:|
    | 10 | ±22% |
    | 100 | ±7% |
    | 1,000 | ±2% |
    | 10,000 | ±0.7% |

    So with 10 or 50 surveys the SD **jumps around** every time you press
    🎲: that is measurement noise, not a real change. With 2,000+ surveys it
    sits still at the true SE.

    *Try it:* set $n$ = 526 and sweep the number of surveys from 10 to
    10,000: the SD settles down near {ols['se1']:.3f}. Then fix the surveys
    at 5,000 and sweep $n$: the SD really moves.
    """)})
    return


@app.cell
def _(mo, ols, stata_table):
    mo.vstack([
        mo.md(rf"""
    ---
    ## Back to the real table

    Our one real 1976 survey is one of those bars:

    - **Coefficient** = {ols['b1']:.7f}: the bottom of the bowl.
    - **Std. err.** = {ols['se1']:.6f}: how much the slope would wobble across reruns.
    - **t** = {ols['b1']:.4f} ÷ {ols['se1']:.4f} = **{ols['t1']:.2f}** standard errors away from zero.
    - **95% interval** = {ols['b1']:.4f} ± {ols['tc']:.4f} × {ols['se1']:.4f}
      = **[{ols['lo1']:.4f}, {ols['hi1']:.4f}]**. ({ols['tc']:.4f} is `invttail(524, 0.025)`.)
      The method behind it catches the truth in 95 of 100 surveys.
    """),
        stata_table({"b", "se", "t", "ci"}),
    ])
    return


if __name__ == "__main__":
    app.run()
