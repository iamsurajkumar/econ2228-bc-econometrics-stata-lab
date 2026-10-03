****************************************************************************
* WEEK 4: POOLED OLS VS. FIXED EFFECTS -- COMPARE A SCHOOL WITH ITSELF
*
* Goes with Week_04_Pooled_vs_FE.pdf. Run this file from top to bottom.
* Three made-up schools (Maple, Oak, Pine), four years each.
*
* PART 1 -- Pooled OLS vs. fixed effects
*   Step 1: pooled OLS through every school-year dot.
*   Step 2: subtract each school's own average, then run OLS again.
*   Step 3: let xtreg, fe do the same work for us.
*
* PART 2 -- Dummy variables: one intercept per school
*   Step 4: make the dummies by hand.
*   Step 5: one regression per school, then one regression with the
*           dummies (and the dummy variable trap).
*   Step 6: let Stata make the dummies with the i. prefix.
*
* Next week (Week 5): the same tools on real Michigan schools, Papke (2005).
*
* This file was prepared with the help of Claude, an AI agent by Anthropic.
****************************************************************************

* Tell Stata which folder to work in. Change this to YOUR week-04 folder.
cd "/Users/macbox/Library/CloudStorage/Dropbox/PhD/teaching/econometrics/lectures/week-04"

* Remove any data, results, and graphs left over from earlier work.
clear all

* Show all output at once, without pausing for "--more--".
set more off

* Close a log that may still be open from an earlier run (no error if none).
capture log close

* Start a log: a text file that records every command and its output.
* replace = overwrite the old log; text = save as plain text.
log using "week04_pooled_vs_fe.log", replace text

****************************************************************************
****************************************************************************
* PART 1: TOY EXAMPLE -- THREE MADE-UP SCHOOLS, FOUR YEARS EACH
****************************************************************************
****************************************************************************

* Type the data in by hand. One row is one school in one year, just like
* the Papke data. str5 = school is text up to 5 characters long.
* Inside every school, pass rates rise by 1 point when spending rises by 0.1.
input str5 school year lavgrexpp math4
"Maple" 1994 8.4 42
"Maple" 1995 8.5 43
"Maple" 1996 8.6 44
"Maple" 1997 8.7 45
"Oak"   1994 8.1 52
"Oak"   1995 8.2 53
"Oak"   1996 8.3 54
"Oak"   1997 8.4 55
"Pine"  1994 7.9 68
"Pine"  1995 8.0 69
"Pine"  1996 8.1 70
"Pine"  1997 8.2 71
end

* Give each variable a readable description (shown in tables and graphs).
label variable lavgrexpp "Log average real spending per pupil"
label variable math4     "Fourth-grade math pass rate (%)"

* Check the grain: school + year should identify each row exactly once.
* isid stops with an error if any school-year appears twice.
isid school year

* Spending in dollars, so we can read the log (slide 5).
* exp() undoes the log: exp(8.4) is about $4,450 per pupil (Maple, 1994).
* Each 0.1 step in the log is about a 10% rise in dollars.
generate spend_dollars = exp(lavgrexpp)
format spend_dollars %9.0fc
label variable spend_dollars "Real spending per pupil ($)"

* Print the data. sepby(school) draws a line between schools;
* noobs hides the row numbers.
list, sepby(school) noobs

* Average spending and pass rate for each school.
* Maple spends the most and scores the lowest; Pine is the opposite.
tabstat lavgrexpp math4, by(school) statistics(mean) nototal

* Plot the 12 dots, one colour per school (same colours as the slides).
* Each (scatter ... if ...) draws one school; twoway puts them on one graph.
* The three slashes at the end of a line mean "the command continues on
* the next line".
twoway (scatter math4 lavgrexpp if school == "Maple", mcolor(blue))  ///
       (scatter math4 lavgrexpp if school == "Oak",   mcolor(green)) ///
       (scatter math4 lavgrexpp if school == "Pine",  mcolor(red)),  ///
       legend(order(1 "Maple" 2 "Oak" 3 "Pine"))                     ///
       xtitle("Log spending per pupil (lavgrexpp)")                  ///
       ytitle("Math pass rate (%)")                                  ///
       title("Three schools, four years each")

* Save the graph as a picture in the working folder.
graph export "schools_scatter.png", replace

****************************************************************************
* STEP 1: POOLED OLS -- ONE LINE THROUGH ALL 12 DOTS
****************************************************************************

* Regress pass rate on spending using all 12 rows together.
* This compares high-spending Maple with low-spending Pine.
* Expect a NEGATIVE slope (about -36.7), even though every school's own
* path slopes up.
regress math4 lavgrexpp

* Store the slope so we can compare it with later results.
* _b[lavgrexpp] is the coefficient on lavgrexpp from the last regression.
scalar b_pooled = _b[lavgrexpp]

* Slide 6: the same dots, plus two kinds of line.
* lfit draws the OLS line. Grey dashed = one line through all 12 dots.
* Coloured = each school's own line, which slopes UP.
twoway (scatter math4 lavgrexpp if school == "Maple", mcolor(blue))  ///
       (scatter math4 lavgrexpp if school == "Oak",   mcolor(green)) ///
       (scatter math4 lavgrexpp if school == "Pine",  mcolor(red))   ///
       (lfit math4 lavgrexpp if school == "Maple", lcolor(blue))     ///
       (lfit math4 lavgrexpp if school == "Oak",   lcolor(green))    ///
       (lfit math4 lavgrexpp if school == "Pine",  lcolor(red))      ///
       (lfit math4 lavgrexpp, lcolor(gray) lpattern(dash)),          ///
       legend(order(1 "Maple" 2 "Oak" 3 "Pine" 7 "Pooled OLS"))      ///
       xtitle("Log spending per pupil (lavgrexpp)")                  ///
       ytitle("Math pass rate (%)")                                  ///
       title("One line through every dot tells the wrong story")

* Save the graph as a picture in the working folder.
graph export "schools_pooled_vs_within.png", replace

****************************************************************************
* STEP 2A: FIND EACH SCHOOL'S AVERAGE
****************************************************************************

* bysort school: = do the next command separately for each school.
* egen ... mean() puts that school's average on every one of its rows.
bysort school: egen mean_spend = mean(lavgrexpp)

* Same for the pass rate.
bysort school: egen mean_math4 = mean(math4)

* Describe the two new variables.
label variable mean_spend "School's average log spending"
label variable mean_math4 "School's average pass rate"

* Show each year's values next to the school's average.
list school year lavgrexpp mean_spend math4 mean_math4, sepby(school) noobs

****************************************************************************
* STEP 2B: SUBTRACT THE AVERAGE -- "THIS YEAR MINUS MY USUAL LEVEL"
****************************************************************************

* New variable: this year's spending minus the school's average spending.
generate dm_spend = lavgrexpp - mean_spend

* New variable: this year's pass rate minus the school's average pass rate.
generate dm_math4 = math4     - mean_math4

* Describe the two new variables.
label variable dm_spend "Spending minus school average"
label variable dm_math4 "Pass rate minus school average"

* Show the demeaned values. Every school is now centred at (0, 0), and
* the three schools look identical: -0.15, -0.05, 0.05, 0.15 for spending
* and -1.5, -0.5, 0.5, 1.5 for scores.
list school year dm_spend dm_math4, sepby(school) noobs

* Check: each school's demeaned values should average to zero.
* format(%9.4f) shows 4 decimal places.
tabstat dm_spend dm_math4, by(school) statistics(mean) nototal format(%9.4f)

* Plot the demeaned data ONE SCHOOL AT A TIME, each with its own OLS line
* (lfit). All three graphs use the same axis labels (xlabel and ylabel),
* so students can compare them directly: after demeaning, every
* school sits around (0, 0) and every school's line is the same line.
* xline(0) and yline(0) draw lines through zero on each axis.
* name(...) keeps each graph in memory so we can combine them below.

* Maple on its own.
twoway (scatter dm_math4 dm_spend if school == "Maple", mcolor(blue))  ///
       (lfit dm_math4 dm_spend if school == "Maple", lcolor(blue)),    ///
       xline(0, lcolor(gs12)) yline(0, lcolor(gs12))                   ///
       xlabel(-0.2(0.1)0.2) ylabel(-2(1)2) legend(off)                 ///
       xtitle("Spending minus average") ytitle("Pass rate minus average") ///
       title("Maple") name(g_maple, replace)

* Oak on its own.
twoway (scatter dm_math4 dm_spend if school == "Oak", mcolor(green))   ///
       (lfit dm_math4 dm_spend if school == "Oak", lcolor(green)),     ///
       xline(0, lcolor(gs12)) yline(0, lcolor(gs12))                   ///
       xlabel(-0.2(0.1)0.2) ylabel(-2(1)2) legend(off)                 ///
       xtitle("Spending minus average") ytitle("Pass rate minus average") ///
       title("Oak") name(g_oak, replace)

* Pine on its own.
twoway (scatter dm_math4 dm_spend if school == "Pine", mcolor(red))    ///
       (lfit dm_math4 dm_spend if school == "Pine", lcolor(red)),      ///
       xline(0, lcolor(gs12)) yline(0, lcolor(gs12))                   ///
       xlabel(-0.2(0.1)0.2) ylabel(-2(1)2) legend(off)                 ///
       xtitle("Spending minus average") ytitle("Pass rate minus average") ///
       title("Pine") name(g_pine, replace)

* Put the three graphs side by side in one row. The three lines match.
graph combine g_maple g_oak g_pine, rows(1) ycommon xcommon            ///
       title("After demeaning, every school has the same line")

* Save the combined graph as a picture in the working folder.
graph export "schools_demeaned.png", replace

****************************************************************************
* STEP 2C: RUN OLS AGAIN ON THE DEMEANED DATA
****************************************************************************

* Regress demeaned pass rate on demeaned spending.
* Now each school is compared only with itself. Expect a slope of 10:
* 0.1 more log spending goes with 1 more point of pass rate.
regress dm_math4 dm_spend

* Store this slope for the comparison at the end.
scalar b_manual = _b[dm_spend]

****************************************************************************
* STEP 3: THE SMART WAY -- LET xtreg, fe DO THE DEMEANING
****************************************************************************

* xtset needs a numeric panel ID, so turn the school name into a number
* (Maple = 1, Oak = 2, Pine = 3) stored in a new variable school_id.
encode school, generate(school_id)

* Show which number stands for which school (1 = Maple, 2 = Oak, 3 = Pine).
* encode attaches the school names to the numbers as a "value label".
label list school_id

* See it row by row. Stata shows the name, but the number is stored
* underneath; nolabel shows the stored number instead of the name.
*
* IMPORTANT STATA QUIRK: to fit its columns, Stata shortens long variable
* names in output and puts a ~ where letters are hidden. list shortens
* names longer than 8 characters. school_id has 9 characters, so without
* abbreviate(9) the column header would read "school~d". abbreviate(9)
* lets list show names up to 9 characters in full. You will see ~ in
* regression tables and other output too (there the limit is longer):
* it always means "part of this variable name is hidden".
list school school_id, sepby(school) noobs nolabel abbreviate(9)

* Tell Stata this is panel data: school_id is the unit, year is the time.
xtset school_id year

* WHAT IS A FIXED-EFFECTS REGRESSION?
* Every school has its own "usual level" of scores: neighbourhood,
* parents, teachers, building. These things stay the same over the four
* years. That usual level is the school's FIXED EFFECT. We cannot measure
* it, but because it does not change over time we can remove it.
*
* A fixed-effects regression compares each school only with ITSELF:
* "in years when this school spent more than usual, did it score more
* than usual?" It never compares Maple with Pine.
*
* xtreg ..., fe does this in one command: for each school it subtracts
* the school's own average from every year (exactly steps 2A-2B), then
* runs OLS on what is left (step 2C). So we expect the same slope: 10.
*
* In the output, read ONLY the coefficient on lavgrexpp (slide 16): 10.
* When a school's spending rises by about 10% (0.1 in logs), that same
* school's pass rate rises by about 10 x 0.1 = 1 percentage point.
* Check on Maple: 1994 -> 1995, $4,450 -> $4,910, math4 42 -> 43.
* Ignore _cons (about -27): it is an average of the schools' intercepts at
* log spending 0 ($1 per pupil), so it has no useful meaning here. Part 2
* shows how to get intercepts that do mean something. The rest of the
* output (sigma_u, rho, corr(u_i, Xb)) comes next week.
xtreg math4 lavgrexpp, fe

* Store this slope for the comparison at the end.
scalar b_fe = _b[lavgrexpp]

* Note: the slope matches step 2C exactly. The standard errors differ a
* little, because xtreg knows it spent 3 degrees of freedom on the school
* averages and our hand-made regression did not.

****************************************************************************
****************************************************************************
* PART 2: DUMMY VARIABLES -- ONE INTERCEPT PER SCHOOL
*
* The Maple, Oak and Pine data are still in memory from Part 1.
****************************************************************************
****************************************************************************

* WHAT IS A DUMMY VARIABLE?
* A dummy (also called an indicator or binary variable) is a variable that
* is 1 if something is true and 0 if it is not. For example, maple = 1 on
* Maple's four rows and 0 on everyone else's rows.
*
* WHY WOULD DUMMIES GIVE FIXED EFFECTS?
* On the pooled-vs-within picture, each school has its own line. The three
* lines are parallel (same slope, 10) but sit at different heights. The height is the school's
* "usual level" -- its fixed effect. A dummy lets each school have its own
* height (its own intercept) while all schools share one slope.
*
* So there are two ways to remove the usual level:
*   (a) subtract each school's average (steps 2-3 above), or
*   (b) give each school its own intercept with a dummy (this part).
* Both give exactly the same slope.

****************************************************************************
* STEP 4: MAKE THE DUMMIES BY HAND
****************************************************************************

* (school == "Maple") is 1 when the statement is true and 0 when false.
* So maple = 1 on Maple's rows and 0 on all other rows.
generate maple = (school == "Maple")

* Same for Oak.
generate oak   = (school == "Oak")

* Same for Pine.
generate pine  = (school == "Pine")

* Look at the dummies. Every row has exactly one 1: each school-year
* belongs to exactly one school.
list school year maple oak pine, sepby(school) noobs

****************************************************************************
* STEP 5: ONE INTERCEPT PER SCHOOL
****************************************************************************

* FIRST, A PICTURE: WHERE DO THE SCHOOLS' LINES SIT AT LOG SPENDING 8?
* The same dots as our first graph, plus each school's own line (slope 10)
* extended to the left. The dashed line at 8 (xline(8)) is a spending level
* inside our data. The diamonds (scatteri y x) mark where each line crosses
* it: Maple 38, Oak 51, Pine 69 -- each school's pass rate at log spending 8.
* function y = ... draws a straight line from its formula; range() sets
* where it starts and ends. text(y x "words") writes a label.
twoway (scatter math4 lavgrexpp if school == "Maple", mcolor(blue))          ///
       (scatter math4 lavgrexpp if school == "Oak",   mcolor(green))         ///
       (scatter math4 lavgrexpp if school == "Pine",  mcolor(red))           ///
       (function y = 38 + 10*(x - 8), range(7.8 8.8) lcolor(blue))         ///
       (function y = 51 + 10*(x - 8), range(7.8 8.8) lcolor(green))        ///
       (function y = 69 + 10*(x - 8), range(7.8 8.8) lcolor(red))          ///
       (scatteri 38 8 51 8 69 8, msymbol(D) mcolor(black) msize(medlarge))   ///
       , xline(8, lcolor(gs10) lpattern(dash))                               ///
       text(38 8.02 "Maple 38", placement(se) color(blue))                   ///
       text(51 8.02 "Oak 51", placement(se) color(green))                    ///
       text(69 8.02 "Pine 69", placement(se) color(red))                     ///
       text(81 8 "log spending = 8", placement(n))                           ///
       legend(off) yscale(range(34 84))                                      ///
       xtitle("Log spending per pupil (lavgrexpp)")                          ///
       ytitle("Math pass rate (%)")                                          ///
       title("Each school's line at log spending 8")                         ///
       xsize(5) ysize(4) scale(1.3)

* Save the graph as a picture in the working folder.
graph export "schools_at_spending8.png", replace

* Those three numbers are the intercepts we want. Next we move zero to 8,
* so the regression's constant is exactly this "height at 8".

* THEN, MEASURE SPENDING FROM 8 INSTEAD OF FROM 0.
* A regression's constant (_cons) is the predicted pass rate when the
* x-variable is 0. For lavgrexpp, 0 means spending e^0 = $1 per pupil --
* far outside our data (7.9 to 8.7, about $2,700 to $6,000). The constant
* would then be a meaningless number (-42, a negative pass rate!).
* So we subtract 8 (like demeaning, we just move where zero is):
* spend8 = 0 now means log spending 8, about e^8 = $3,000 per pupil.
* The slope does not change: one more unit of spend8 is one more unit of
* lavgrexpp.
generate spend8 = lavgrexpp - 8

* Describe the new variable.
label variable spend8 "Log spending minus 8"

****************************************************************************
* STEP 5a: FIRST, ONE SEPARATE REGRESSION PER SCHOOL
****************************************************************************

* Before any dummies: run a separate regression for each school, using
* only that school's four rows (the "if" condition). Each _cons is that
* school's pass rate at log spending 8 -- the diamonds in the picture above.

* Maple's rows only. Expect _cons = 38 and slope = 10.
regress math4 spend8 if school == "Maple"

* Oak's rows only. Expect _cons = 51 and slope = 10.
regress math4 spend8 if school == "Oak"

* Pine's rows only. Expect _cons = 69 and slope = 10.
regress math4 spend8 if school == "Pine"

* Three regressions, three intercepts (38, 51, 69), the same slope (10).
* Next: get all three intercepts from ONE regression, using dummies.

****************************************************************************
* STEP 5b: ONE REGRESSION WITH THE DUMMIES
****************************************************************************

* We include oak and pine but LEAVE OUT maple. Why? A regression already
* has a constant (_cons), and maple + oak + pine = 1 on every row. If we
* put in all three dummies AND the constant, Stata cannot tell them apart
* and drops one. This is called the "dummy variable trap".
*
* THE DUMMY VARIABLE TRAP, simply: on every row, maple + oak + pine = 1,
* which is exactly the value of the constant. So "maple" carries no new
* information once we know oak, pine and the constant: if a row is not Oak
* and not Pine, it must be Maple. Rule: with 3 groups, use 2 dummies.
* The school we leave out (Maple) becomes the BASE school: its line is the
* constant, and the other schools are measured relative to it.
regress math4 spend8 oak pine

* How to read the output: write the fitted equation, then switch the
* dummies on and off one school at a time.
*
*   math4 = 38 + 13*oak + 31*pine + 10*spend8
*
*   Maple: oak = 0, pine = 0  =>  math4 = 38           + 10*spend8
*   Oak:   oak = 1, pine = 0  =>  math4 = 38 + 13 = 51 + 10*spend8
*   Pine:  oak = 0, pine = 1  =>  math4 = 38 + 31 = 69 + 10*spend8
*
* Three lines, one per school:
*   - Same slope (10) in every line: that is the effect of spending.
*   - Different intercepts (38, 51, 69): each school's "usual level",
*     its fixed effect. Each is the predicted pass rate at log spending 8.
*   - Maple has both dummies = 0, so its line is just _cons. Maple is the
*     BASE school, and oak and pine are measured relative to Maple.
*
* Check with the data: Maple in 1994 spent 8.4 (spend8 = 0.4), so
* 38 + 10*0.4 = 42. Pine in 1994 spent 7.9 (spend8 = -0.1), so
* 69 + 10*(-0.1) = 68. Both match the data.
*
* So at the SAME spending, Pine scores 31 points more than Maple.
* That +31 is "the effect of being Pine rather than Maple" -- a fixed effect.

* Store this slope for the check at the end.
scalar b_dummy_hand = _b[spend8]

* Same intercepts as the three separate regressions in Step 5a: the
* dummies really do give each school its own intercept.
*
* One difference: separate regressions also let each school have its OWN
* slope. The dummy regression forces ONE shared slope. Here they agree
* because we built the toy data with slope 10 in every school. With real
* data the separate slopes would differ, and fixed effects combines them
* into one average within-school slope.

****************************************************************************
* STEP 5c: PICTURE -- THE BASE LINE AND THE SHIFTS
****************************************************************************

* Draw each school's dots and its own line from the regressions above,
* with spend8 on the x-axis, so each intercept is where a line crosses the
* dashed line at spend8 = 0 (xline(0)).
* function y = ... draws a straight line from its formula; range() sets
* where it starts and ends on the x-axis.
* scatteri y x draws one point: the three intercepts (38, 51, 69).
* The arrows (pcarrowi y1 x1 y2 x2) start at Maple's intercept (the base)
* and point up to Oak's and Pine's: +13 and +31, the dummy coefficients.
* text(y x "words") writes a label at that point.
twoway (scatter math4 spend8 if school == "Maple", mcolor(blue))            ///
       (scatter math4 spend8 if school == "Oak",   mcolor(green))           ///
       (scatter math4 spend8 if school == "Pine",  mcolor(red))             ///
       (function y = 38 + 10*x, range(-0.2 0.8) lcolor(blue))              ///
       (function y = 51 + 10*x, range(-0.2 0.8) lcolor(green))             ///
       (function y = 69 + 10*x, range(-0.2 0.8) lcolor(red))               ///
       (scatteri 38 0 51 0 69 0, msymbol(D) mcolor(black) msize(medlarge))   ///
       (pcarrowi 38 -0.04 51 -0.04, lcolor(black) mcolor(black))            ///
       (pcarrowi 38 -0.08 69 -0.08, lcolor(black) mcolor(black)),           ///
       xline(0, lcolor(gs10) lpattern(dash))                                 ///
       text(44.5 -0.04 "+13", placement(e))                                  ///
       text(60 -0.08 "+31", placement(w))                                    ///
       text(38 0.02 "38", placement(se))                                     ///
       text(51 0.02 "51", placement(se))                                     ///
       text(69 0.02 "69", placement(se))                                     ///
       text(49 0.6 "Maple (base)", color(blue))                              ///
       text(62 0.55 "Oak = base + 13", color(green))                         ///
       text(80 0.45 "Pine = base + 31", color(red))                          ///
       legend(off) xscale(range(-0.25 0.8)) xlabel(-0.2(0.2)0.8)            ///
       xtitle("Log spending minus 8 (spend8)") ytitle("Math pass rate (%)") ///
       xsize(5) ysize(4) scale(1.3)

* The labels next to the lines replace a legend. xsize/ysize make the
* picture squarer; scale(1.3) makes text and dots 30% bigger so it is
* readable on a slide.

* Save the graph as a picture in the working folder.
graph export "dummy_intercepts.png", replace

****************************************************************************
* STEP 6: LET STATA MAKE THE DUMMIES -- THE i. PREFIX
****************************************************************************

* i.school_id tells Stata: "make one dummy for each value of school_id and
* leave one out as the base". Stata leaves out the lowest number, 1 = Maple.
* The output shows the same numbers as Step 5b (_cons 38, Oak +13,
* Pine +31).
* This is the same i. we used for i.year in the Week 3 Papke regressions.
regress math4 spend8 i.school_id

* Store this slope for the check at the end.
scalar b_dummy = _b[spend8]

****************************************************************************
* SIDE BY SIDE -- WHICH COMPARISON, AND ALL FE ROUTES AGREE
****************************************************************************

* Print all the slopes together. %8.2f = show 2 decimal places.
display as text "Pooled OLS slope:          " as result %8.2f b_pooled
display as text "Demeaned-by-hand slope:    " as result %8.2f b_manual
display as text "xtreg, fe slope:           " as result %8.2f b_fe
display as text "Hand-made dummies slope:   " as result %8.2f b_dummy_hand
display as text "i.school_id slope:         " as result %8.2f b_dummy

* Pooled OLS compares different schools and gets the sign wrong (-36.7).
* Every way of comparing each school with ITSELF gives 10.
*
* NEXT WEEK: the same tools on 1,773 real Michigan schools (Papke 2005).
* There we also need YEAR dummies (i.year), which work just like the
* school dummies above: one dummy per year, one year left out as the base.

* Stop recording and save the log file.
log close
