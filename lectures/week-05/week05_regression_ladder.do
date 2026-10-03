****************************************************************************
* WEEK 5: DOES MORE SCHOOL MONEY RAISE TEST SCORES?
*         FIVE REGRESSIONS, FROM NAIVE TO PAPKE (2005)
*
* Goes with week_05_lecture.pdf. Run this file from top to bottom.
*
* THE PLAN: we answer ONE question with FIVE regressions. Each regression
* fixes one problem of the one before it, and we watch how the answer moves.
*
*   Model 1  Naive:              math4 on spending, nothing else
*   Model 2  + school controls:  add poverty (lunch) and school size
*   Model 3  + year dummies:     compare schools within the same year
*   Model 4  School FE only:     compare each school only with itself
*   Model 5  School FE + years:  both fixes at once (Papke's model)
*
* At the end, all five go side by side in one table (ladder_table.tex).
*
* REFERENCE
*   Papke, Leslie E. (2005). "The effects of spending on test pass rates:
*   evidence from Michigan." Journal of Public Economics 89, 821-839.
*   (Papke_2005_Effects_of_Spending_on_Test_Pass_Rates.pdf is in the
*   Module 5 folder on Canvas.)
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
log using "week05_regression_ladder.log", replace text

****************************************************************************
****************************************************************************
* PART 0: THE QUESTION
****************************************************************************
****************************************************************************

* THE STORY
* Before 1994, rich school districts in Michigan spent much more per pupil
* than poor ones, because schools were paid for mostly by local property
* taxes. In 1994 Michigan changed the rules (a reform called "Proposal A").
* The state now gave every district a minimum amount per pupil, so money
* went up fastest in the districts that used to spend the least.
*
* THE QUESTION (Leslie Papke, 2005)
* If a school gets 10% more money per pupil, how many more of its 4th
* graders pass the state math test?
*
* BEFORE RUNNING ANYTHING: write down your guess. 0 points? 2? 10?

****************************************************************************
****************************************************************************
* PART 1: THE DATA
****************************************************************************
****************************************************************************

* Load the real data.
* Source: Boston College Wooldridge dataset school93_98, used by Papke.
* Codebook: http://fmwww.bc.edu/ec-p/data/wooldridge/school93_98.des
* If Stata says "command bcuse not found", run: ssc install bcuse
bcuse school93_98, clear

* ONE ROW = ONE SCHOOL IN ONE SCHOOL YEAR. The same school appears in
* several rows, one for each year from 1993 to 1998. Data like this, the
* same units followed over time, is called PANEL DATA.

* Check that claim: school ID + year should identify each row exactly once.
* isid gives an error if any school-year appears twice.
isid schid year

* Tell Stata this is panel data: schid is the school, year is the time.
xtset schid year

* THE FOUR VARIABLES WE USE
* The dataset's own labels just repeat the variable names, so we give
* each one a clear description.

* math4: OUTCOME (what we want to explain). Percent of 4th graders who
* pass Michigan's state math test (the MEAP), from 0 to 100.
label variable math4     "4th-grade math pass rate (%)"

* lavgrexpp: MAIN VARIABLE (the cause we are interested in). Spending per
* pupil, built in three steps:
*   1. "real" = adjusted for inflation, in 1997 dollars, so a dollar in
*      1994 and a dollar in 1998 buy the same amount;
*   2. "avg" = averaged over THIS year and LAST year, because a 4th
*      grader also learned from the money spent on them in 3rd grade;
*   3. "l" = log, so a CHANGE in lavgrexpp is a PERCENT change in money.
label variable lavgrexpp "Log avg. real spending per pupil (this + last year)"

* lunch: CONTROL. Percent of students poor enough to get free school
* lunch. Papke uses it to measure how poor a school's students are.
label variable lunch     "Students eligible for free lunch (%)"

* lenrol: CONTROL. log(number of students in the school) = school size.
label variable lenrol    "Log enrollment (school size)"

* Look at the four variables: number of rows with data (Obs), average,
* spread, smallest and largest value.
summarize math4 lavgrexpp lunch lenrol

* WHAT TO SEE
* lavgrexpp has fewer rows than the others: it is missing in every 1993
* row, because it needs LAST year's spending and the data start in 1993.
* It is also missing for some schools in later years (mostly 1994 and
* 1995), where a school's spending was not reported.

* Count the rows where a variable is missing, year by year.
* missing(x) is 1 if x is empty and 0 if not; tabstat adds them up.
generate miss_spend = missing(lavgrexpp)
tabstat miss_spend, by(year) statistics(sum)

* SAME ROWS FOR EVERY MODEL
* We keep only the rows where all four variables are present. Then all
* five models use exactly the same school-years, and any change in the
* answer comes from the MODEL, not from rows coming and going.
keep if !missing(math4, lavgrexpp, lunch, lenrol)

* How many school-years are left? (Should be 7,274, in 1994-1998.)
count

* How many rows in each year?
tabulate year

* Papke also adds the SQUARE of lunch and of lenrol. A squared term lets
* the effect bend instead of being a straight line: for example, going
* from 60% to 70% poor students may matter more or less than going from
* 10% to 20%.

* lunch2 = free-lunch percent, squared.
generate lunch2 = lunch^2
label variable lunch2  "Free lunch (%), squared"

* lenrol2 = log enrollment, squared.
generate lenrol2 = lenrol^2
label variable lenrol2 "Log enrollment, squared"

* HOW TO READ THE SPENDING COEFFICIENT IN EVERY MODEL BELOW
* lavgrexpp is in logs, so: coefficient / 10 = change in the pass rate
* (in percentage points) when spending rises by 10%.
* Example: a coefficient of 20 means 10% more money -> 2 points more pass.
*
* WHY? A 10% rise in money raises its LOG by about 0.10. One school:
*
*   +--------------+--------------------+---------------+
*   |              | Spending per pupil | log(spending) |
*   +--------------+--------------------+---------------+
*   | Before       | $5,000             | 8.517         |
*   | After (+10%) | $5,500             | 8.612         |
*   | Change       | +10%               | +0.095 ~ 0.10 |
*   +--------------+--------------------+---------------+
*
* So "10% more money" means "lavgrexpp goes up by about 0.10", and
*   change in pass rate = coefficient x 0.10 = coefficient / 10.
* The pass rate is already a percent, so the change is in PERCENTAGE
* POINTS: 60% -> 62% is +2 points (not "2 percent").

* Check the table with Stata. display works like a calculator.
* ln() = natural log.
display ln(5000)
display ln(5500)
display ln(5500) - ln(5000)

****************************************************************************
****************************************************************************
* MODEL 1: THE NAIVE REGRESSION
*   math4 = a + b*lavgrexpp + error
****************************************************************************
****************************************************************************

* First, the picture. Every dot is one school in one year.
* The red line is the straight line that fits the dots best: it is
* exactly the regression we run next.

* The correlation: a number from -1 to 1 for how closely two variables
* move together (0 = not at all).
correlate math4 lavgrexpp

* Save the correlation, rounded to 2 decimals, in a local called r.
* A local is a named box that holds a number; we use it as `r'.
local r : display %4.2f r(rho)

* scatter = the dots; lfit = the fitted straight line. msize(vsmall) =
* small dots; mcolor(%30) = 30% see-through, so crowded areas look darker.
* note() writes the correlation under the chart.
twoway (scatter math4 lavgrexpp, msize(vsmall) mcolor(%30))             ///
       (lfit math4 lavgrexpp, lcolor(red)),                              ///
       legend(off) note("Correlation = `r'")                             ///
       xtitle("Log avg. spending per pupil (lavgrexpp)")                 ///
       ytitle("Math pass rate (%)")                                      ///
       title("Model 1: math pass rate vs. spending")

* Save the graph as a picture in the working folder.
graph export "ladder_model1_scatter.png", replace

* Now the regression itself: the slope of that red line.
regress math4 lavgrexpp

* Store the results under the name m1 for the table at the end.
estimates store m1

* WHAT TO SEE
* - lavgrexpp: about 19.6. So 10% more money -> about 2 points more pass.
*   HOW WE GET THERE (the rule from the top of the file):
*     math4 changes by 19.6 x (change in lavgrexpp).
*     10% more money raises lavgrexpp by about 0.10.
*     So math4 changes by 19.6 x 0.10 = 1.96, about 2 points.
*   In words: a school spending $5,000 per pupil that moves to $5,500
*   is predicted to have a pass rate about 2 points higher, e.g.
*   60% -> 62%.
*   Exact version: the log really rises by 0.095, so 19.6 x 0.095 = 1.87.
*   "About 2" is close enough for reading the table.
*   Other sizes: 1% more money -> 19.6 / 100 = about 0.2 points;
*   doubling money (+100%, log rises by 0.69) -> 19.6 x 0.69 = about 13.6.
* - P>|t| = 0.000: very unlikely to be zero by chance.
* - BUT R-squared is only about 0.03: spending explains 3% of why pass
*   rates differ. Most of the story is something else.
*
* THE PROBLEM: this compares ALL school-years with each other: a rich
* suburb in 1998 with a poor city school in 1994. Schools that spend more
* may differ in many other ways. Is 2 points the effect of MONEY, or of
* everything else that comes with it?

****************************************************************************
****************************************************************************
* MODEL 2: ADD SCHOOL CHARACTERISTICS
*   math4 = a + b*lavgrexpp + poverty + school size + error
****************************************************************************
****************************************************************************

* Idea: compare schools that are SIMILAR in poverty and size. Adding
* lunch, lunch2, lenrol and lenrol2 holds those fixed, so b now compares
* schools with the same share of poor students and the same size.
regress math4 lavgrexpp lunch lunch2 lenrol lenrol2

* Store the results under the name m2.
estimates store m2

* Compare the spending coefficient with the models so far.
estimates table m1 m2, keep(lavgrexpp) b(%9.2f) se(%9.2f)

* WHAT TO SEE
* - lunch: about -0.52. One more percentage point of poor students ->
*   about half a point LOWER pass rate. Poverty matters a lot.
* - lavgrexpp went UP, from about 19.6 to about 22.9.
*   Surprise! Adding controls does not always make an effect smaller.
*   Why it went up is worked out step by step just below.
* - R-squared jumps to about 0.30: poverty explains much more than money.

* WHY DID THE MONEY EFFECT GO UP? (OMITTED VARIABLE BIAS)
* To keep it simple, we add only ONE control, lunch, and check 3 steps.

* STEP 1: Do schools with more money have more or fewer poor students?
* Regress lunch on spending.
regress lunch lavgrexpp

* WHAT TO SEE: slope about +9.8. More money comes with slightly MORE
* poor students, because the reform sent extra money to low-spending
* districts, which were often poorer.

* STEP 2: Holding spending fixed, what does poverty do to pass rates?
* Add lunch to Model 1.
regress math4 lavgrexpp lunch

* WHAT TO SEE
* - lunch: about -0.41. More poor students -> LOWER pass rates.
* - lavgrexpp: about 23.7, up from 19.6 in Model 1.

* STEP 3: Put the pieces together. Model 1 left lunch out, so its slope
* mixes two things: the money effect itself, PLUS the poverty that comes
* with the money. The two pull in OPPOSITE directions:
*   Model 1 slope = money effect + (money -> poverty) x (poverty -> pass)
*         19.6    =     23.7     +        9.8        x      (-0.41)
*         19.6    =     23.7     -        4.0
* So in Model 1, the extra poverty that comes with more money hid about
* 4 points of the money effect. Holding lunch fixed brings them back.
*
* THE RULE: leaving out a variable pushes b DOWN when that variable
* (a) moves WITH the cause (here: +) and (b) LOWERS the outcome (here: -).
* It pushes b UP when both signs are the same.
*
* THE PROBLEM LEFT: we still compare 1994 rows with 1998 rows. Look at
* the next picture.

****************************************************************************
****************************************************************************
* MODEL 3: ADD YEAR DUMMIES
*   math4 = a + b*lavgrexpp + controls + one intercept per year + error
****************************************************************************
****************************************************************************

* First, the picture: the same scatter, one small panel per year.
* As in Model 1, twoway puts two layers together: the dots (scatter) and
* the red best-fit line (lfit). by(year) draws a separate panel for each
* year, all with the SAME axes, and fits a SEPARATE line in each panel.
* rows(2) = two rows of panels; note("") removes Stata's "Graphs by year".
* The legend: order() names each layer: 1 = the dots, 2 = the line.
* With panels, WHERE the legend goes is set inside by(): at(6) puts it in
* the empty 6th slot, and pos(0) centres it there.
twoway (scatter math4 lavgrexpp, msize(vsmall) mcolor(%40))             ///
       (lfit math4 lavgrexpp, lcolor(red)),                              ///
    legend(order(1 "One school-year" 2 "Best-fit line (lfit)") cols(1)) ///
    by(year, rows(2) note("") legend(at(6) pos(0))                       ///
       title("Math pass rate vs. spending, by year"))                    ///
    xtitle("Log avg. spending per pupil (lavgrexpp)")                   ///
    ytitle("Math pass rate (%)")

* Save the graph as a picture in the working folder.
graph export "ladder_model3_by_year.png", replace

* WHAT TO SEE IN THE PICTURE
* From 1994 to 1998 the whole cloud moves UP (and a little to the right).
* Pass rates rose in almost EVERY school, rich or poor, partly because the
* test itself changed. Spending also rose everywhere. So "later year"
* looks like "more money AND higher scores", even if money did nothing.

* FIRST, HOW A LOOP WORKS
* A loop repeats the same commands several times, once for each value.
*   forvalues y = 1994/1998 {      <- y takes the values 1994, ..., 1998
*       ...commands...             <- run once for EACH value of y
*   }                              <- end of the loop
* Inside the loop, `y' (left quote ` under Esc, then right quote ') is
* replaced by the current value: 1994 the first time, 1995 the next...
* Rules: the { must be on the forvalues line; the } on its own line.
* A tiny example that only prints the value each time:
forvalues y = 1994/1998 {
    display "Now working on year `y'"
}

* WHAT TO SEE: five lines, "Now working on year 1994" up to 1998. The
* single display command ran five times, each time with a new `y'.

* THE RED LINES IN NUMBERS: one regression per year
* Each red line above is the Model 1 regression, run on ONE year only.
* The same loop, but now with a regression inside instead of display.
* if year == `y' = use only the rows of that year.
* quietly = run without printing; we print one table at the end instead.
forvalues y = 1994/1998 {
    quietly regress math4 lavgrexpp if year == `y'
    estimates store yr`y'
}

* All five yearly slopes side by side, with Model 1 (all years) first.
* keep(lavgrexpp) = show only the spending row (not the constant).
* NUMBER FORMATS: a format tells Stata how to print a number.
*   %9.2f  =  %  start of a format
*             9  the column is 9 characters wide
*             .2 two decimal places: 19.62 instead of 19.619243
*             f  "fixed": normal digits, never 1.96e+01
*   b(%9.2f) formats the coefficients; se(%9.2f) the standard errors.
*   stats(N) adds a row with the number of observations, and
*   stfmt(%9.0fc) formats that row: .0 = no decimals, c = commas
*   (7,274). Note: estimates table ignores the c, so it prints 7274.
estimates table m1 yr1994 yr1995 yr1996 yr1997 yr1998,                   ///
    keep(lavgrexpp) b(%9.2f) se(%9.2f) stats(N) stfmt(%9.0fc)

* WHAT TO SEE
* - The slope changes a lot from year to year: about 18.0 in 1994, then
*   6.8, 8.8 and 7.0, and about -1.4 in 1998 (flat: its standard error,
*   2.55, is bigger than the slope itself).
* - From 1995 on, EVERY yearly slope is far below Model 1's 19.6. How can
*   the all-years slope be bigger than almost every one-year slope? Because
*   Model 1 also compares ACROSS years: later years have more money AND
*   higher scores (the cloud moving up and right), and Model 1 counts that
*   statewide rise as a money effect.
* - Year dummies (next) use the same idea: compare schools only WITHIN
*   the same year, then combine the five yearly comparisons into ONE slope.

* The average pass rate in each year, to see the jump in numbers.
tabstat math4, by(year) statistics(mean)

* YEAR DUMMIES (i.year)
* A dummy is a 0/1 variable. i.year makes one dummy per year: it is 1 in
* that year and 0 otherwise. Each year then gets its OWN intercept, which
* soaks up anything that hit every school in that year (a harder or
* easier test, a statewide change). One year must be left out as the
* base (otherwise the dummies always add up to 1: the dummy variable
* trap). Stata leaves out the first year, 1994.
* What is left for b: comparing schools WITHIN the same year.
regress math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year

* Store the results under the name m3.
estimates store m3

* Compare the spending coefficient with the models so far.
estimates table m1 m2 m3, keep(lavgrexpp) b(%9.2f) se(%9.2f)

* WHAT TO SEE
* - The year rows: pass rates in 1998 are about 23 points higher than in
*   1994 (the base year), for every school, whatever it spent. The table
*   of averages above shows the same jump: about 51% in 1994, 74% in 1998.
* - lavgrexpp FALLS from about 22.9 to about 7.6: 10% more money -> about
*   0.8 points. Most of Model 2's number was the statewide rise over
*   time, not money.
*
* THE PROBLEM LEFT: within a year, we still compare DIFFERENT schools.
* Two schools with the same poverty and size can still differ in parents,
* teachers, neighbourhood... things not in our data.

****************************************************************************
****************************************************************************
* MODEL 4: SCHOOL FIXED EFFECTS ONLY (NO YEAR DUMMIES)
*   math4 = (one intercept per school) + b*lavgrexpp + controls + error
****************************************************************************
****************************************************************************

* Idea: compare each school ONLY WITH ITSELF in other years. Everything
* about a school that stays the same over these five years (its
* neighbourhood, its parents, its building) cannot explain changes in
* that school, so it drops out. This is "school fixed effects", the same
* as one dummy per school (like Maple, Oak and Pine in Week 4).
*
* xtreg ..., fe does this for us, using the schid we gave to xtset.
* To show one fix at a time, we take the year dummies OUT again here.
xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2, fe

* Store the results under the name m4.
estimates store m4

* Compare the spending coefficient with the models so far.
estimates table m1 m2 m3 m4, keep(lavgrexpp) b(%9.2f) se(%9.2f)

* WHAT TO SEE
* - lavgrexpp JUMPS to about 45: 10% more money -> 4.5 points. Too big
*   to believe!
* - Why? Inside one school, spending rose year after year AND the pass
*   rate rose year after year (the statewide jump from Model 3). With no
*   year dummies, comparing a school with itself over time is the same as
*   comparing early years with late years, so b takes credit for the
*   whole statewide rise.
* - LESSON: school fixed effects remove differences BETWEEN schools, but
*   not changes over TIME. We need both fixes.

****************************************************************************
****************************************************************************
* MODEL 5: SCHOOL FIXED EFFECTS + YEAR DUMMIES (PAPKE'S MODEL)
*   math4 = (one intercept per school) + (one intercept per year)
*           + b*lavgrexpp + controls + error
****************************************************************************
****************************************************************************

* Both fixes at once:
*   - school fixed effects: compare each school only with itself;
*   - year dummies: remove the jump that hit every school in a year.
* What is left for b: did a school whose money rose MORE THAN USUAL (for
* that school, and for that year in Michigan) also improve more than usual?
xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, fe

* Store the results under the name m5.
estimates store m5

* Compare the spending coefficient with the models so far.
estimates table m1 m2 m3 m4 m5, keep(lavgrexpp) b(%9.2f) se(%9.2f)

* WHAT TO SEE
* - lavgrexpp: about 6.3. 10% more money -> about 0.6 points more pass.
*   Smaller than Model 1, but still positive and significant.
*   (Papke's own number is 7.2; her sample is slightly different.)
* - lunch shrinks from about -0.58 to about -0.16, and its standard error
*   triples (0.027 -> 0.080), so it only just misses significance at the
*   5% level (P>|t| about 0.05). Why so much less precise? See below.

* xtsum splits the spread of a variable into two parts:
*   between = how much schools differ from EACH OTHER;
*   within  = how much ONE school changes over time.
xtsum lunch lavgrexpp

* WHAT TO SEE
* lunch: between about 25, within about 4. Poverty differs a lot
* across schools but barely moves inside a school in five years. Fixed
* effects only uses the within part, so there is little left to learn
* about poverty from. Spending, in contrast, moves a fair amount within
* a school, thanks to the reform: that is what Papke uses.

****************************************************************************
* REBUILD xtsum BY HAND (for lunch), to see where its numbers come from
****************************************************************************
*
* Toy example first. Free-lunch % for two schools over three years:
*
*   +----------+------+------+------+----------------+
*   |          | 1994 | 1995 | 1996 | school average |
*   +----------+------+------+------+----------------+
*   | School A |  80  |  82  |  78  |       80       |
*   | School B |  10  |  12  |   8  |       10       |
*   +----------+------+------+------+----------------+
*
* BETWEEN: how different are the school AVERAGES from each other?
*   Here 80 vs 10: a big gap. between sd = sd of the school averages.
*
* WITHIN: how far is each year from ITS OWN school's average?
*   School A: 80-80 = 0, 82-80 = +2, 78-80 = -2.  Small.
*   within sd = sd of these deviations (all schools, all years).
*
*   In terminal math:  within = x(i,t) - xbar(i) + xbar
*     x(i,t)  = lunch for school i in year t
*     xbar(i) = school i's own average over its years
*     xbar    = overall average of all 7274 rows (36.71)
*   The "+ xbar" is cosmetic: it shifts every value by the same 36.71,
*   so the numbers look like lunch percentages. Adding a constant does
*   NOT change the sd. Fixed effects only uses x(i,t) - xbar(i).
*
* Now the same steps on the real data.

* Step 1. Each school's own average lunch, copied onto all its rows.
*   bysort schid: = do the next command separately for each school.
*   egen ... mean() = the average within that school.
bysort schid: egen lunch_bar = mean(lunch)       // each school's average

* Step 2. Flag ONE row per school (tag = 1 on the first row, 0 else),
*   so each school counts once, not once per year.
egen tag = tag(schid)                             // one row per school

* Step 3. BETWEEN: summarize the 1773 school averages.
summarize lunch_bar if tag                        // sd = 25.43, min 0, max 100

* Step 4. OVERALL: all 7274 rows. Stata keeps the mean in r(mean),
*   which Step 5 uses. (Run Step 5 right after this line.)
summarize lunch                                   // overall mean 36.71

* Step 5. WITHIN: this year minus the school's average, plus 36.71.
generate lunch_w = lunch - lunch_bar + r(mean)    // within transform
summarize lunch_w                                 // sd = 4.36, min 3.21, max 66.35

* WHAT TO SEE (compare with the xtsum table above)
* - Step 3 sd = 25.43 = xtsum "between". Min 0 / max 100: one school
*   averaged 0% free-lunch students across its years, another 100%.
* - Step 5 sd = 4.36 = xtsum "within". A typical year is about +/-4
*   points from its school's usual level.
* - Within min 3.21 and max 66.35 are NOT real lunch values. Take the
*   36.71 back off to read them:
*     3.21  - 36.71 = -33.5  -> one school-year 33.5 points BELOW its
*                               school's average
*     66.35 - 36.71 = +29.6  -> one school-year 29.6 points ABOVE it
* - WHY xtsum LEAVES THE MEAN BLANK for between and within:
*     within mean  = exactly 36.71 (deviations sum to 0, then +36.71),
*                    so it repeats the overall mean.
*     between mean = 37.34 (Step 3), close to 36.71 but not equal: the
*                    panel is unbalanced, and a school with 2 years
*                    counts as much as one with 5. Not useful to show.
* - T-bar = 4.10 in xtsum = 7274 rows / 1773 schools = average number of
*   years per school.

* Remove the helper variables so the data are as before.
drop lunch_bar tag lunch_w

****************************************************************************
****************************************************************************
* WRAP-UP: ALL FIVE MODELS SIDE BY SIDE
****************************************************************************
****************************************************************************

* A quick table in the Results window: coefficients (b) and standard
* errors (se, the line under each b). N = rows used; r2 = R-squared.
estimates table m1 m2 m3 m4 m5,                                          ///
    keep(lavgrexpp lunch lunch2 lenrol lenrol2)                          ///
    b(%9.3f) se(%9.3f) stats(N r2) stfmt(%9.3f)

* The same table as a LaTeX file (ladder_table.tex) for the slides.
* esttab comes from the estout package. If Stata says "command esttab not
* found", run: ssc install estout
* indicate() adds a "Yes/No" row instead of listing every year dummy.
* For xtreg, fe the R-squared shown is the WITHIN R-squared.
esttab m1 m2 m3 m4 m5 using "ladder_table.tex", replace booktabs nofloat ///
    keep(lavgrexpp lunch lunch2 lenrol lenrol2)                          ///
    coeflabels(lavgrexpp "Log spending (lavgrexpp)"                      ///
               lunch "Free lunch (\%)" lunch2 "Free lunch squared"       ///
               lenrol "Log enrollment" lenrol2 "Log enrollment squared") ///
    mtitles("Naive" "+ Controls" "+ Year" "School FE" "School + Year")   ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nonotes                     ///
    indicate("Year dummies = *.year")                                    ///
    addnotes("School FE: Models 4 and 5 compare each school with itself.") ///
    stats(N r2, labels("Observations" "R-squared") fmt(%9.0fc %9.3f))

* The same table again as a web page (ladder_table.html): double-click it
* to open it in any browser. Two changes from the LaTeX version:
*   html replaces booktabs nofloat (those two are LaTeX-only);
*   "Free lunch (%)" has no backslash (the \ is only needed in LaTeX).
esttab m1 m2 m3 m4 m5 using "ladder_table.html", replace html            ///
    keep(lavgrexpp lunch lunch2 lenrol lenrol2)                          ///
    coeflabels(lavgrexpp "Log spending (lavgrexpp)"                      ///
               lunch "Free lunch (%)" lunch2 "Free lunch squared"        ///
               lenrol "Log enrollment" lenrol2 "Log enrollment squared") ///
    mtitles("Naive" "+ Controls" "+ Year" "School FE" "School + Year")   ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nonotes                     ///
    indicate("Year dummies = *.year")                                    ///
    addnotes("School FE: Models 4 and 5 compare each school with itself.") ///
    stats(N r2, labels("Observations" "R-squared") fmt(%9.0fc %9.3f))

* THE STORY OF THE SPENDING COEFFICIENT (10% more money ->)
*   Model 1  Naive                about 19.6  ->  2.0 points
*   Model 2  + school controls    about 22.9  ->  2.3 points
*   Model 3  + year dummies       about  7.6  ->  0.8 points
*   Model 4  School FE only       about 45.1  ->  4.5 points
*   Model 5  School FE + year     about  6.3  ->  0.6 points
*
* THREE TAKEAWAYS
* 1. The answer depends on WHICH COMPARISON the regression makes. Every
*    model is "correct" Stata; they answer different questions.
* 2. Each fix removes one problem: controls remove differences in poverty
*    and size; year dummies remove the statewide rise over time; school
*    fixed effects remove everything fixed about a school. Fixing only
*    one of them (Model 4) can make things worse.
* 3. Papke's answer: 10% more money -> about 0.6-0.7 more points on the
*    math pass rate. Real, but modest.
*
* COMING LATER (not today): the standard errors here treat the five years
* of one school as five unrelated pieces of information. They are not, so
* the standard errors are too small. "Clustered" standard errors fix that.

* Stop recording and save the log file.
log close
