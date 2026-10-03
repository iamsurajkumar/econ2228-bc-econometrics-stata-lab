# /// script
# requires-python = ">=3.13"
# dependencies = ["marimo>=0.23.3", "pandas>=3.0.6", "numpy>=2.5.3", "altair>=6.3.0"]
# ///

# Week 4 visual companion: understand the comparison before naming the regression.
# Run from the course folder: marimo edit lectures/week-04/week04_pooled_vs_fe.py

import marimo

__generated_with = "0.24.2"
app = marimo.App(auto_download=["ipynb"])


@app.cell
def _():
    import altair as alt
    import marimo as mo
    import numpy as np
    import pandas as pd

    # notebook_location() works on your laptop AND in the browser version.
    folder = mo.notebook_location()
    toy = pd.read_csv(str(folder / "toy_panel.csv"))
    real = pd.read_csv(str(folder / "papke_twins.csv"))

    def slope(x, y):
        """OLS slope with an intercept, for displaying the classroom examples."""
        x = np.asarray(x, dtype=float)
        y = np.asarray(y, dtype=float)
        design = np.column_stack([np.ones(len(x)), x])
        coefficients, *_ = np.linalg.lstsq(design, y, rcond=None)
        return float(coefficients[0]), float(coefficients[1])

    @alt.theme.register("lecture_white", enable=True)
    def lecture_white():
        ink, grid = "#222222", "#dddddd"
        return alt.theme.ThemeConfig(config={
            "background": "white",
            "view": {"stroke": grid},
            "title": {"color": ink},
            "axis": {"labelColor": ink, "titleColor": ink, "gridColor": grid,
                     "domainColor": ink, "tickColor": ink},
            "legend": {"labelColor": ink, "titleColor": ink},
        })

    return alt, mo, np, pd, real, slope, toy


@app.cell
def _(mo):
    mo.md(r"""
    # Fixed effects: compare a school with itself

    **Today has two parts:** three made-up schools (Maple, Oak, Pine), then real
    Michigan schools from Papke's paper, to ask why the comparison we make
    matters. The pictures here are a teaching aid. Stata is where we run the
    regressions.

    No panel-regression background is needed. Start with the dots and ask:

    > When a school spends more than it usually does, do its scores also rise?

    The small example below makes every school's scores rise as its spending rises.
    Yet a line through all schools can point the other way.
    """)
    return


@app.cell
def _(mo):
    story = mo.ui.dropdown(
        {
            "reversed": "Higher-spending school starts with lower scores",
            "aligned": "Higher-spending school starts with higher scores",
        },
        value="reversed",
        label="How do the schools differ before we follow them over time?",
    )
    gap = mo.ui.slider(
        8, 32, value=26, step=1,
        label="Distance between the usual scores of the high- and low-spending schools",
    )
    noise = mo.ui.slider(
        0, 3, value=0, step=0.5,
        label="Add year-to-year bumps (to make the dots less tidy)",
    )
    school_to_inspect = mo.ui.dropdown(
        ["Maple", "Oak", "Pine"], value="Maple", label="School to inspect year by year",
    )
    mo.vstack([story, gap, noise, school_to_inspect])
    return gap, noise, school_to_inspect, story


@app.cell
def _(gap, noise, np, slope, story, toy):
    example = toy[["school", "year", "lavgrexpp"]].copy()
    average_spending = example.groupby("school")["lavgrexpp"].transform("mean")

    if story.value == "reversed":
        usual_scores = {"Maple": 43.5, "Oak": 53.5, "Pine": 43.5 + gap.value}
    else:
        usual_scores = {"Maple": 43.5 + gap.value, "Oak": 53.5, "Pine": 43.5}

    # These made-up numbers isolate one idea: every school's own slope is +10.
    example["math4"] = example["school"].map(usual_scores)
    example["math4"] += 10 * (example["lavgrexpp"] - average_spending)
    if noise.value:
        example["math4"] += np.random.default_rng(11).normal(
            0, noise.value, len(example)
        )
    example["math4"] = example["math4"].round(1)

    example["usual_spending"] = example.groupby("school")["lavgrexpp"].transform("mean")
    example["usual_score"] = example.groupby("school")["math4"].transform("mean")
    example["spending_vs_usual"] = example["lavgrexpp"] - example["usual_spending"]
    example["score_vs_usual"] = example["math4"] - example["usual_score"]

    pooled_intercept, pooled_slope = slope(example["lavgrexpp"], example["math4"])
    school_intercept, school_slope = slope(
        example["spending_vs_usual"], example["score_vs_usual"]
    )

    school_means = (
        example.groupby("school", as_index=False)
        .agg(lavgrexpp=("lavgrexpp", "mean"), math4=("math4", "mean"))
    )
    return (
        example,
        pooled_intercept,
        pooled_slope,
        school_intercept,
        school_means,
        school_slope,
    )


@app.cell
def _(
    alt,
    example,
    mo,
    pd,
    pooled_intercept,
    pooled_slope,
    school_intercept,
    school_means,
    school_slope,
):
    x_grid = pd.DataFrame({
        "lavgrexpp": [example["lavgrexpp"].min() - 0.04,
                      example["lavgrexpp"].max() + 0.04]
    })
    x_grid["fitted"] = pooled_intercept + pooled_slope * x_grid["lavgrexpp"]

    across_line = alt.Chart(x_grid).mark_line(
        color="#555555", strokeDash=[7, 5], size=3
    ).encode(x="lavgrexpp:Q", y="fitted:Q")
    school_paths = alt.Chart(example.sort_values(["school", "year"])).mark_line(
        size=2
    ).encode(
        x=alt.X("lavgrexpp:Q", title="Spending per pupil (log scale)",
                scale=alt.Scale(zero=False)),
        y=alt.Y("math4:Q", title="Fourth-grade math pass rate (%)",
                scale=alt.Scale(zero=False)),
        color=alt.Color("school:N", title="School"),
        detail="school:N", order="year:Q",
    )
    dots = alt.Chart(example).mark_circle(size=95, opacity=0.9).encode(
        x=alt.X("lavgrexpp:Q", title="Spending per pupil (log scale)",
                scale=alt.Scale(zero=False)),
        y=alt.Y("math4:Q", title="Fourth-grade math pass rate (%)",
                scale=alt.Scale(zero=False)),
        color=alt.Color("school:N", title="School"),
        tooltip=["school", "year", alt.Tooltip("lavgrexpp:Q", format=".2f"), "math4"],
    )
    averages = alt.Chart(school_means).mark_point(
        shape="diamond", size=180, filled=True, stroke="white", strokeWidth=1
    ).encode(x="lavgrexpp:Q", y="math4:Q", color="school:N",
             tooltip=["school", "lavgrexpp", "math4"])
    raw_chart = (across_line + school_paths + dots + averages).properties(
        title="Original values: each color follows one school", width=460, height=310
    ).interactive()

    centered = example.copy()
    centered["fitted"] = (
        school_intercept + school_slope * centered["spending_vs_usual"]
    )
    within_path = alt.Chart(centered.sort_values(["school", "year"])).mark_line(
        size=2
    ).encode(
        x=alt.X("spending_vs_usual:Q", title="This year's spending − school's usual spending",
                scale=alt.Scale(zero=False)),
        y=alt.Y("score_vs_usual:Q", title="This year's score − school's usual score",
                scale=alt.Scale(zero=False)),
        color=alt.Color("school:N", title="School"),
        detail="school:N", order="year:Q",
    )
    within_dots = alt.Chart(centered).mark_circle(size=95).encode(
        x="spending_vs_usual:Q", y="score_vs_usual:Q", color="school:N",
        tooltip=["school", "year", "spending_vs_usual", "score_vs_usual"],
    )
    within_grid = pd.DataFrame({
        "spending_vs_usual": [centered["spending_vs_usual"].min() - 0.02,
                              centered["spending_vs_usual"].max() + 0.02]
    })
    within_grid["fitted"] = (
        school_intercept + school_slope * within_grid["spending_vs_usual"]
    )
    within_line = alt.Chart(within_grid).mark_line(
        color="#222222", strokeDash=[7, 5], size=3
    ).encode(
        x="spending_vs_usual:Q", y="fitted:Q"
    )
    zero_x = alt.Chart(pd.DataFrame({"zero": [0]})).mark_rule(
        color="#aaaaaa", strokeDash=[3, 3]
    ).encode(x="zero:Q")
    zero_y = alt.Chart(pd.DataFrame({"zero": [0]})).mark_rule(
        color="#aaaaaa", strokeDash=[3, 3]
    ).encode(y="zero:Q")
    centered_chart = (zero_x + zero_y + within_path + within_dots + within_line).properties(
        title="After subtracting each school's usual level", width=460, height=310
    ).interactive()

    mo.hstack([raw_chart, centered_chart], gap=1)
    return


@app.cell
def _(mo, pooled_slope, school_slope, story):
    direction = "opposite" if story.value == "reversed" else "the same"
    mo.md(f"""
    **Look at the same dots in both pictures.** The left dashed line uses every
    school-year at once: its slope is **{pooled_slope:+.1f}**. The right picture
    first subtracts each school's usual spending and usual score; its dashed line
    has slope **{school_slope:+.1f}**.

    In this made-up example, each school improves by 1 point when its own spending
    rises by 0.1. But the schools' usual score levels point in {direction} directions.
    Move the gap slider: the all-dot line changes as the schools' starting levels
    spread apart, while the right-hand comparison stays close to +10.
    """)
    return


@app.cell
def _(example, mo, school_to_inspect):
    one_school = example.loc[example["school"] == school_to_inspect.value].copy()
    one_school = one_school[[
        "year", "lavgrexpp", "math4", "usual_spending", "usual_score",
        "spending_vs_usual", "score_vs_usual",
    ]].rename(columns={
        "lavgrexpp": "Spending",
        "math4": "Score",
        "usual_spending": "Usual spending",
        "usual_score": "Usual score",
        "spending_vs_usual": "Spending − usual",
        "score_vs_usual": "Score − usual",
    })
    one_school = one_school.round(2)
    mo.vstack([
        mo.md(f"### Follow {school_to_inspect.value}: what did we subtract?"),
        mo.as_html(one_school.to_html(index=False)),
        mo.md("Each row keeps the year's movement and removes this school's usual level."),
    ])
    return


@app.cell
def _(alt, mo, real):
    actual_paths = alt.Chart(real.sort_values(["school", "year"])).mark_line(
        point=alt.OverlayMarkDef(size=75), size=2
    ).encode(
        x=alt.X("lavgrexpp:Q", title="Log average real spending per pupil",
                scale=alt.Scale(zero=False)),
        y=alt.Y("math4:Q", title="Fourth-grade math pass rate (%)",
                scale=alt.Scale(zero=False)),
        color=alt.Color("school:N", title="Selected school"),
        detail="school:N", order="year:Q",
        tooltip=["school", "year", "lavgrexpp", "math4"],
    ).properties(
        title="Now look at three actual Michigan schools (1994–1998)",
        width=720, height=340,
    ).interactive()
    mo.vstack([
        actual_paths,
        mo.md("These selected schools have noisier paths than the toy example. Every path also climbs partly because **all Michigan schools rose together over these years** (spending went up, and the test changed too). Papke adds year effects (`i.year`) to remove that. These schools illustrate the data; **they are not the full sample used for Papke's estimate.**"),
    ])
    return


@app.cell
def _(mo):
    mo.md(r"""
    ## Now name the two comparisons

    - **Pooled OLS** draws one line through all school-years. It mixes differences
      across schools with changes over time inside each school.
    - **School fixed effects** asks how a school differs from its own usual level.
      Stable differences between schools drop out; year-to-year changes remain.

    Papke's question is whether more real spending per pupil raises Michigan
    fourth-graders' math pass rates. In the published Table 7, a 10% spending
    increase corresponds to about **+0.84 percentage points** in pooled OLS and
    **+0.72 points** with school fixed effects. Dividing the log-spending
    coefficient by 10 is Papke's rule of thumb.

    **What this tells us:** the positive relationship remains when each school is
    compared with itself. **What it does not tell us:** fixed effects alone do not
    prove that spending caused the score change. Student groups and other things
    can change from year to year. Papke also studies Michigan's 1994 Proposal A
    funding reform as an instrument for spending; that needs additional assumptions.

    ### One small data-version note

    The `bcuse school93_98` classroom file is close to Papke's data, but not the
    exact estimation file in the article. It gives 7,274 complete observations in
    1,773 schools, while Table 7 reports 7,242 in 1,771 schools. The coefficient
    values students get in Stata will differ slightly; focus first on what the two
    comparisons use.
    """)
    return


@app.cell
def _(mo):
    answer = mo.ui.dropdown(
        {
            "baseline": "Remove each school's usual score; keep its year-to-year changes",
            "all": "Keep every difference between schools in the comparison",
            "nothing": "Remove all year-to-year changes too",
        },
        value=None,
        label="When we subtract each school's usual level, what remains?",
    )
    check = mo.ui.button(label="Check")
    mo.vstack([answer, check])
    return answer, check


@app.cell
def _(answer, check, mo):
    mo.stop(not check.value)
    result = (
        "**Yes.** That is the fixed-effects comparison: remove each school's usual level, then use what changes over time."
        if answer.value == "baseline"
        else "Look at the right-hand picture: after subtracting the school's own average, the usual gap between schools is gone. What still varies year to year?"
    )
    mo.md(result)
    return


@app.cell
def _(mo):
    mo.md(r"""
    ## Stata is the analysis; this notebook is the picture

    The class do-file `week04_pooled_vs_fe.do` runs Maple, Oak and Pine first
    (by hand, then `xtreg`), then these models on the Michigan data. Compare the
    `lavgrexpp` row:

    ```stata
    bcuse school93_98, clear
    xtset schid year
    gen lunch2 = lunch^2
    gen lenrol2 = lenrol^2
    regress math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, vce(cluster schid)
    xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, fe vce(cluster schid)
    ```

    `xtset` tells Stata which rows belong to the same school and which variable
    records the year. `xtreg, fe` runs the school-with-itself comparison shown
    above. The school-clustered standard errors allow results from the same school
    in different years to be related.
    """)
    return


if __name__ == "__main__":
    app.run()
