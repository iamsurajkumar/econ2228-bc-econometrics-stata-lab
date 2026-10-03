****************************************************************************
* WEEK 5: PAPKE (2005) -- DOES SCHOOL SPENDING RAISE TEST SCORES?
*
* Goes with Week_05_Papke.pdf. Run this file from top to bottom.
* Builds on Week 4 (Maple, Oak, Pine): pooled OLS, fixed effects, dummies.
*
* PART 1 -- Real Michigan schools after the 1994 funding reform (Proposal A).
*   Pooled OLS vs. school fixed effects, with year dummies (i.year) and
*   clustered standard errors. Table saved as papke_table.tex for the slides.
*
* APPENDIX A (optional): plot real Michigan schools yourself, and the
*   free-lunch confidence-interval picture.
*
* A harder picture of pooled vs. fixed effects with the real data is in a
* separate, optional file: week05_papke_picture_optional.do
*
* This file was prepared with the help of Claude, an AI agent by Anthropic.
****************************************************************************

* Tell Stata which folder to work in. Change this to YOUR week-05 folder.
cd "/Users/macbox/Library/CloudStorage/Dropbox/PhD/teaching/econometrics/lectures/week-05"

* Remove any data, results, and graphs left over from earlier work.
clear all

* Show all output at once, without pausing for "--more--".
set more off

* Close a log that may still be open from an earlier run (no error if none).
capture log close

* Start a log: a text file that records every command and its output.
* replace = overwrite the old log; text = save as plain text.
log using "week05_papke.log", replace text

****************************************************************************
****************************************************************************
* PART 1: PAPKE (2005) -- POOLED OLS VS. FIXED EFFECTS, MICHIGAN SCHOOLS
****************************************************************************
****************************************************************************

* THE POLICY STORY
* In 1994 Michigan changed how schools are funded (Proposal A). The reform
* raised spending in low-spending districts and slowed it in high-spending
* ones. So spending changed over time INSIDE the same schools -- exactly the
* variation fixed effects uses. Papke asks: when a school's spending rises,
* does its 4th-grade math pass rate rise too?

* Load the real data.
* Source: Boston College Wooldridge dataset school93_98, used by Papke.
* One row is one school in one school year, just like Maple, Oak and Pine.
* Codebook: http://fmwww.bc.edu/ec-p/data/wooldridge/school93_98.des
* If Stata says "command bcuse not found", run: ssc install bcuse
bcuse school93_98, clear

* The dataset's own labels just repeat the variable names, so give each
* variable we use a clear description. Definitions come from the codebook
* (link above) and Papke (2005).

* schid: an ID number for each school.
label variable schid     "School ID"

* distid: an ID number for each school district.
label variable distid    "School district ID"

* year: the school year, 1993 to 1998. 1993 means the 1992-93 school year.
label variable year      "School year (1993 = 1992-93)"

* math4: OUTCOME. Percent of 4th graders with a satisfactory score on
* Michigan's state math test (the MEAP), 0 to 100.
label variable math4     "4th-grade math pass rate (%)"

* lavgrexpp: MAIN VARIABLE. Spending per pupil, adjusted for inflation
* ("real", in 1997 dollars), averaged over this year and last year, then
* logged: log((this year + last year) / 2). Papke averages two years
* because learning builds up over time.
label variable lavgrexpp "Log avg. real spending per pupil (this + last year)"

* lunch: CONTROL. Percent of students eligible for free lunch (0 to 100).
* A measure of how poor the school's students are.
label variable lunch     "Students eligible for free lunch (%)"

* lenrol: CONTROL. log(enrol), where enrol = number of students in the
* school (school size).
label variable lenrol    "Log enrollment (school size)"

* See the new descriptions in the "Variable label" column.
describe schid distid year math4 lavgrexpp lunch lenrol

* Averages, smallest and largest values of the main variables.
summarize math4 lavgrexpp lunch lenrol

* Count the rows (school-years) in the data.
count

* How many rows in each year?
tabulate year

* Check the grain: school ID + year should identify each row exactly once.
isid schid year

* Tell Stata this is panel data: schid is the school, year is the time.
xtset schid year

* Papke's controls include squared terms (as in her Table 7). A squared
* term lets the effect of poverty or size bend instead of being a straight
* line (for example, going from 60% to 70% free lunch may matter more than
* going from 10% to 20%).

* lunch2 = free-lunch percent, squared.
generate lunch2 = lunch^2

* Describe the new variable.
label variable lunch2  "Free lunch (%), squared"

* lenrol2 = log enrollment, squared.
generate lenrol2 = lenrol^2

* Describe the new variable.
label variable lenrol2 "Log enrollment, squared"

* YEAR DUMMIES (i.year) -- the same idea as the school dummies in Week 4.
* Last week, one dummy per school gave each SCHOOL its own intercept.
* Now, one dummy per year gives each YEAR its own intercept: it absorbs
* anything that hit every Michigan school in the same year, such as a
* test becoming easier or harder. One year is left out as the base (the
* dummy variable trap again): the first year with spending data, 1994.

* See the year dummies by hand. tabulate ..., generate(yr) makes one 0/1
* variable per year: yr1 = 1993, yr2 = 1994, ..., yr6 = 1998.
tabulate year, generate(yr)

* One school over time: each row has exactly one yr dummy equal to 1.
list schid year yr1-yr6 if schid == 5144, noobs abbreviate(4)

* We do not need these by hand: i.year makes them inside the regression.
drop yr1-yr6

* CLUSTERED STANDARD ERRORS: vce(cluster schid) = the same school's rows in
* different years are likely related; this lets the errors be correlated
* within a school. It changes only the standard errors, not the
* coefficients.

* POOLED OLS: one regression through every school-year, like the grey line
* for Maple, Oak and Pine. It mixes comparisons between different schools
* with comparisons of a school with itself.
regress math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, vce(cluster schid)

* Store the results under the name "pooled" for the table below.
estimates store pooled

* FIXED EFFECTS: compare each Michigan school only with itself, exactly
* like Step 3 for Maple, Oak and Pine. Each school's "usual level" (its
* neighbourhood, parents, teachers) is removed.
xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, fe vce(cluster schid)

* Store the results under the name "fixed" for the table below.
estimates store fixed

* Put the two regressions side by side. keep() lists the rows to show,
* including the year effects (i.year); b and se show coefficients and
* standard errors (the se is the line under each coefficient).
* stats(N N_g) shows the number of rows and, for fixed effects, the number
* of schools; stfmt(%9.0f) shows them without decimals.
estimates table pooled fixed,                                            ///
    keep(lavgrexpp lunch lunch2 lenrol lenrol2 i.year)                   ///
    b(%9.3f) se(%9.3f) stats(N N_g) stfmt(%9.0f)

* Save the same table as a LaTeX file (papke_table.tex) for the slides.
* esttab comes from the estout package. If Stata says "command esttab not
* found", run: ssc install estout
* Options: using = the file to write; replace = overwrite it; booktabs and
* nofloat = a plain LaTeX table the slides can \input; keep() = rows to
* show (the years are 1995.year to 1998.year; 1994 is the base year);
* coeflabels() = row names; mtitles() = column names; b(3) se(3) = 3
* decimals, with the standard error in brackets under each coefficient;
* star() = the usual significance stars: * p<0.10, ** p<0.05, *** p<0.01
* (more stars = stronger evidence the effect is not zero);
* stats() = number of rows and schools.
esttab pooled fixed using "papke_table.tex", replace booktabs nofloat    ///
    keep(lavgrexpp lunch lunch2 lenrol lenrol2                           ///
         1995.year 1996.year 1997.year 1998.year)                        ///
    coeflabels(lavgrexpp "Log spending (lavgrexpp)"                      ///
               lunch "Free lunch (\%)" lunch2 "Free lunch squared"       ///
               lenrol "Log enrollment" lenrol2 "Log enrollment squared"  ///
               1995.year "Year 1995" 1996.year "Year 1996"               ///
               1997.year "Year 1997" 1998.year "Year 1998")              ///
    mtitles("Pooled OLS" "Fixed effects") nonumbers                      ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nonotes                     ///
    stats(N N_g, labels("Observations" "Schools") fmt(%9.0fc %9.0fc))

* WHAT TO SAY ABOUT THE TABLE
* - lunch: -0.58 pooled, -0.16 fixed effects (and no longer significant).
*   Poverty differs a lot BETWEEN schools but barely moves INSIDE a school,
*   so fixed effects has little poverty change to learn from.
* - year: pass rates in 1998 are about 23 points higher than in 1994 in
*   BOTH columns, for every school, whatever it spent (the base year is
*   1994; 1993 has no spending data). Without i.year, that statewide jump
*   would be credited to spending, which also rose over these years.

* HOW TO READ THE lavgrexpp COEFFICIENT
* lavgrexpp is LOG spending, so divide the coefficient by 10 to get the
* change in the pass rate (in percentage points) for 10% more spending.
* Pooled OLS: about 7.6 / 10 = 0.76 points. Fixed effects: about 6.3 / 10
* = 0.63 points. Both positive, but fixed effects is smaller: part of the
* pooled number came from comparing different kinds of schools, not from
* what money does inside a school.
*
* TEACHER NOTE: Papke's published Table 7 gives 8.442 (pooled) and 7.179
* (FE). The bcuse file is a close teaching version, not her exact sample
* (7,274 observations in 1,773 schools vs. her 7,242 in 1,771), so the
* numbers differ slightly. The lesson is what each comparison uses.

****************************************************************************
****************************************************************************
* APPENDIX A (OPTIONAL): PLOT REAL MICHIGAN SCHOOLS YOURSELF
*
* The two real-school pictures from the slides. Run it only if there is
* time, or try it at home. Change the school IDs to plot other schools.
****************************************************************************
****************************************************************************

****************************************************************************
* A1: THREE REAL SCHOOLS OVER TIME
****************************************************************************

* Schools 5144, 5753 and 6315, followed from 1994 to 1998.
* connected = dots joined by a line; sort(year) joins them in year order.
* mlabel(year) writes the year next to each dot.
* lfit = the pooled line through all 15 dots of the three schools.
twoway (connected math4 lavgrexpp if schid == 5144, sort(year)           ///
            mlabel(year) mlabcolor(blue) mcolor(blue) lcolor(blue))                      ///
       (connected math4 lavgrexpp if schid == 5753, sort(year)           ///
            mlabel(year) mlabcolor(orange) mcolor(orange) lcolor(orange))                  ///
       (connected math4 lavgrexpp if schid == 6315, sort(year)           ///
            mlabel(year) mlabcolor(green) mcolor(green) lcolor(green))                    ///
       (lfit math4 lavgrexpp if inlist(schid, 5144, 5753, 6315),         ///
            lcolor(gray) lpattern(dash)),                                ///
       legend(order(1 "School 5144" 2 "School 5753" 3 "School 6315"     ///
                    4 "Pooled line"))                                    ///
       xtitle("Log spending per pupil (lavgrexpp)")                      ///
       ytitle("Math pass rate (%)")                                      ///
       title("Three real Michigan schools, 1994-1998")

* Save the graph as a picture in the working folder.
graph export "real_three_schools.png", replace

* WHAT TO SEE
* Every school's path goes up steeply: over these years spending rose AND
* pass rates rose in almost every Michigan school (the statewide average
* went from about 51% to 74%, partly because the test changed). So
* following a school over time also follows the calendar.
*
* Check it with numbers. Fixed effects WITHOUT year controls:
xtreg math4 lavgrexpp, fe

* Fixed effects WITH year controls (i.year):
xtreg math4 lavgrexpp i.year, fe

* Without i.year the slope is about 45: mostly the statewide trend. With
* i.year it drops to about 7. That is why Papke controls for the year.

****************************************************************************
* A2: POVERTY BARELY MOVES INSIDE A SCHOOL
****************************************************************************

* Three schools with low, middle and high poverty: 1491, 3074 and 4068.
* Same kind of graph, with the free-lunch percent on the x-axis.
* year >= 1994 keeps the same years as the first graph. xscale(range())
* leaves room on the right so the year labels are not cut off.
twoway (connected math4 lunch if schid == 1491 & year >= 1994, sort(year)               ///
            mlabel(year) mlabcolor(green) mcolor(green) lcolor(green))                    ///
       (connected math4 lunch if schid == 3074 & year >= 1994, sort(year)               ///
            mlabel(year) mlabcolor(orange) mcolor(orange) lcolor(orange))                  ///
       (connected math4 lunch if schid == 4068 & year >= 1994, sort(year)               ///
            mlabel(year) mlabcolor(blue) mcolor(blue) lcolor(blue))                      ///
       (lfit math4 lunch if inlist(schid, 1491, 3074, 4068) & year >= 1994,             ///
            lcolor(gray) lpattern(dash)),                                ///
       legend(order(1 "School 1491 (low poverty)"                        ///
                    2 "School 3074 (middle)"                             ///
                    3 "School 4068 (high poverty)" 4 "Pooled line"))     ///
       xtitle("Students eligible for free lunch (%)")                    ///
       ytitle("Math pass rate (%)")                                      ///
       xscale(range(0 55))                                               ///
       title("Poverty differs across schools, not within")

* Save the graph as a picture in the working folder.
graph export "real_lunch_schools.png", replace

* WHAT TO SEE
* The schools sit far apart left to right (about 3%, 25% and 48% free
* lunch), but each school's dots barely move left or right over the years.
* Fixed effects only uses the moves INSIDE a school, so it has very little
* poverty variation to learn from. That is why the lunch coefficient
* shrinks from about -0.58 (pooled) to about -0.16 (fixed effects).

* xtsum splits the variation: "between" = across schools, "within" =
* inside a school over time. Compare the two standard deviations for lunch.
xtsum lunch

****************************************************************************
* A3: FREE LUNCH -- SIGNIFICANT IN POOLED, NOT WITH FIXED EFFECTS
****************************************************************************

* Picture of the free-lunch coefficient with its 95% confidence interval
* in each model. A dot is the estimate; a bar is the 95% interval (the
* range of true values that fit our data). If the bar crosses the zero
* line, we cannot rule out "no effect": not significant at the 5% level.

* Bring back the stored pooled regression from Part 2.
estimates restore pooled

* Save its free-lunch estimate (b) and standard error (se) in locals.
* A local is a named box that holds a number; we use it as `name'.
local b_pool  = _b[lunch]
local se_pool = _se[lunch]

* 95% interval = estimate +/- about 2 standard errors. invttail() gives the
* exact multiplier (about 1.96); e(df_r) = degrees of freedom.
local lo_pool = `b_pool' - invttail(e(df_r), 0.025) * `se_pool'
local hi_pool = `b_pool' + invttail(e(df_r), 0.025) * `se_pool'

* The same for the stored fixed-effects regression.
estimates restore fixed
local b_fe  = _b[lunch]
local se_fe = _se[lunch]
local lo_fe = `b_fe' - invttail(e(df_r), 0.025) * `se_fe'
local hi_fe = `b_fe' + invttail(e(df_r), 0.025) * `se_fe'

* Print the numbers so we can check them against the regression output.
display "Pooled: " %6.3f `b_pool' "   95% CI [" %6.3f `lo_pool' ", " %6.3f `hi_pool' "]"
display "FE:     " %6.3f `b_fe'   "   95% CI [" %6.3f `lo_fe'   ", " %6.3f `hi_fe'   "]"

* Draw it. pci draws a line between two points (y x y x): the interval.
* scatteri draws one point (y x): the estimate. Pooled at height 2,
* fixed effects at height 1. xline(0) = the "no effect" line.
twoway (pci 2 `lo_pool' 2 `hi_pool', lcolor(gray) lwidth(thick))        ///
       (scatteri 2 `b_pool', mcolor(gray) msize(large))                  ///
       (pci 1 `lo_fe' 1 `hi_fe', lcolor(navy) lwidth(thick))            ///
       (scatteri 1 `b_fe', mcolor(navy) msize(large)),                   ///
       xline(0, lcolor(red) lpattern(dash))                              ///
       ylabel(2 "Pooled OLS" 1 "Fixed effects", angle(0) noticks)        ///
       yscale(range(0.5 2.5)) ytitle("") xscale(range(-0.7 0.1))        ///
       xtitle("Free-lunch coefficient, with 95% confidence interval")    ///
       legend(off)                                                       ///
       title("Free lunch: significant pooled, not with fixed effects")    ///
       xsize(7) ysize(3.5) scale(1.4)

* xsize/ysize set the shape (wide and short); scale(1.4) makes text and
* dots 40% bigger so the picture is readable on a slide.

* Save the graph as a picture in the working folder.
graph export "lunch_confidence_intervals.png", replace

* WHAT TO SEE
* - Pooled: about -0.58, interval about [-0.66, -0.50]. Narrow and far
*   from zero: very significant (***).
* - Fixed effects: about -0.16, interval about [-0.34, 0.03]. Wider, and
*   it crosses zero: not significant.
* - Why wider? Fixed effects only uses poverty changes INSIDE a school, and
*   those are small (see xtsum above). Less information = more wobble.
* - Not significant does NOT mean poverty does not matter. It means that
*   comparing each school only with itself, the data cannot tell.

* Stop recording and save the log file.
log close
