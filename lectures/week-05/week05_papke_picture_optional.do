****************************************************************************
* WEEK 5 (OPTIONAL): A PICTURE OF POOLED VS. FIXED EFFECTS, REAL DATA
*
* Extra material for week05_papke.do. Not needed for class; use it
* only if there is time. It draws the Maple/Oak/Pine picture from Week 4
* with the real Michigan schools from Papke (2005).
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
log using "week05_papke_picture_optional.log", replace text

****************************************************************************
* SET UP: THE SAME DATA AND REGRESSIONS AS week05_papke.do
****************************************************************************

* Load the Michigan school data (one row = one school in one year).
* If Stata says "command bcuse not found", run: ssc install bcuse
bcuse school93_98, clear

* Tell Stata this is panel data: schid is the school, year is the time.
xtset schid year

* Papke's squared controls. lunch2 = free-lunch percent, squared.
generate lunch2 = lunch^2

* lenrol2 = log enrollment, squared.
generate lenrol2 = lenrol^2

* Pooled OLS (same as week05_papke.do). Store it as "pooled".
regress math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, vce(cluster schid)
estimates store pooled

* Fixed effects (same as week05_papke.do). Store it as "fixed".
xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, fe vce(cluster schid)
estimates store fixed

****************************************************************************
* THE PICTURE
****************************************************************************

* We want the Maple/Oak/Pine picture again, but with 7,274 real rows.
*
* WHY NOT JUST PLOT math4 AGAINST lavgrexpp? Because between 1994 and 1998
* spending rose AND pass rates jumped (51% to 74%) in every school, partly
* because the test changed. A raw plot mostly shows that statewide trend.
* The regressions remove it with i.year (and poverty and size with the
* controls). So the picture must remove the same things first:
*
*   1. Take out what the regression controls for (year, poverty, size).
*   2. Plot what is left of spending against what is left of pass rates.
*   3. The line through what is left has EXACTLY the regression's slope.
*      (This is a known result called Frisch-Waugh; we just check it.)
*
* 7,274 dots would be a blur, so we sort the rows into 20 equal-sized
* groups ("bins") by spending and plot each group's average: 20 dots.

* Use exactly the same rows as the regressions. estimates restore brings
* back the stored pooled regression; e(sample) = 1 on the rows it used.
estimates restore pooled

* insample = 1 on the rows used by the regressions, 0 otherwise.
generate insample = e(sample)

* --- POOLED: remove year, poverty and size only ---

* What is left of the pass rate after year, poverty and size.
* predict ..., residuals = actual value minus the regression's prediction.
regress math4 lunch lunch2 lenrol lenrol2 i.year if insample
predict p_math4 if insample, residuals

* What is left of spending after year, poverty and size.
regress lavgrexpp lunch lunch2 lenrol lenrol2 i.year if insample
predict p_spend if insample, residuals

* Check: the slope here matches the pooled lavgrexpp coefficient (7.64).
regress p_math4 p_spend

* --- FIXED EFFECTS: ALSO remove each school's own average ---

* Same as above, plus each school's usual level. predict ..., e keeps only
* the part that changes inside a school from year to year.
xtreg math4 lunch lunch2 lenrol lenrol2 i.year if insample, fe
predict w_math4 if insample, e

* The same for spending.
xtreg lavgrexpp lunch lunch2 lenrol lenrol2 i.year if insample, fe
predict w_spend if insample, e

* Check: the slope here matches the fixed-effects coefficient (6.27).
regress w_math4 w_spend

* --- MAKE 20 BINS FOR EACH ---

* xtile splits the rows into 20 equal-sized groups by p_spend (1 = lowest).
xtile p_bin = p_spend if insample, nq(20)

* Average spending and pass rate in each pooled bin.
bysort p_bin: egen p_bin_spend = mean(p_spend)
bysort p_bin: egen p_bin_math4 = mean(p_math4)

* tag = 1 on ONE row per bin, so each bin is plotted once, not 364 times.
egen p_tag = tag(p_bin) if insample

* The same three steps for the fixed-effects version.
xtile w_bin = w_spend if insample, nq(20)
bysort w_bin: egen w_bin_spend = mean(w_spend)
bysort w_bin: egen w_bin_math4 = mean(w_math4)
egen w_tag = tag(w_bin) if insample

* --- THE PICTURE ---

* Grey = pooled (all schools compared). Blue = fixed effects (each school
* compared with itself). Dots = the 20 bin averages. Lines = the slopes
* from the regressions (lfit uses all rows, so they match exactly).
* Both on the same axes, so the two slopes can be compared by eye.
twoway (scatter p_bin_math4 p_bin_spend if p_tag, mcolor(gray))            ///
       (scatter w_bin_math4 w_bin_spend if w_tag, mcolor(navy))            ///
       (lfit p_math4 p_spend if insample, range(-0.3 0.4)                  ///
            lcolor(gray) lpattern(dash))                                   ///
       (lfit w_math4 w_spend if insample, range(-0.15 0.15) lcolor(navy)), ///
       xline(0, lcolor(gs12)) yline(0, lcolor(gs12))                       ///
       legend(order(3 "Pooled OLS (slope 7.6)"                             ///
                    4 "Fixed effects (slope 6.3)"))                        ///
       xtitle("Log spending, after removing year, poverty and size")       ///
       ytitle("Pass rate (%), after removing year, poverty and size")      ///
       title("Michigan schools: pooled vs. fixed effects")

* Save the graph as a picture in the working folder.
graph export "papke_pooled_vs_fe.png", replace

* WHAT TO SEE IN THE PICTURE
* - Both lines slope up: more spending goes with higher pass rates.
* - The blue line is a bit flatter (6.3 vs. 7.6). Part of the pooled slope
*   came from comparing different kinds of schools.
* - The blue dots sit in a much narrower band left to right. A school's
*   spending moves only a little from year to year, compared with the gaps
*   BETWEEN schools. Fixed effects uses only these small moves, so it has
*   less information -- that is why its standard error is bigger
*   (2.43 vs. 1.72 in the table).
* - Unlike Maple/Oak/Pine, the slope does not flip sign. Real data are
*   rarely that dramatic; here fixed effects makes the estimate smaller and
*   more believable, not the opposite.

* Stop recording and save the log file.
log close
