****************************************************************************
* WEEK 6: DO SMALLER CLASSES HELP KIDS LEARN?
*         TENNESSEE'S CLASS-SIZE EXPERIMENT (PROJECT STAR)
*
* Goes with Week_06_STAR.pdf and the notebook week06_star_notebook.py.
* Run this file from top to bottom.
*
* THE PLAN: one question, three regressions, and we read EVERY number in
* the regression table on the way. This is review for the midterm.
*
*   Model 1  score on "small class" (yes/no)  -> the gap, SE, t, p, CI, R2
*   Model 2  + school dummies                 -> does the gap move?
*   Model 3  all three class types            -> the F-test
*
* At the end, all three go side by side in one table (star_table.tex).
*
* REFERENCE
*   Krueger, Alan B. (1999). "Experimental Estimates of Education
*   Production Functions." Quarterly Journal of Economics 114(2), 497-532.
*   Data: Achilles et al. (2008), Tennessee's Student Teacher Achievement
*   Ratio (STAR) Project, Harvard Dataverse, doi:10.7910/DVN/SIWH9F.
*
* This file was prepared with the help of Claude, an AI agent by Anthropic.
****************************************************************************

* Tell Stata which folder to work in. Change this to YOUR week-06 folder.
cd "/Users/macbox/Library/CloudStorage/Dropbox/PhD/teaching/econometrics/lectures/week-06"

* Remove any data, results, and graphs left over from earlier work.
clear all

* Show all output at once, without pausing for "--more--".
set more off

* Close a log that may still be open from an earlier run (no error if none).
capture log close

* Start a log: a text file that records every command and its output.
* replace = overwrite the old log; text = save as plain text.
log using "week06_star.log", replace text

****************************************************************************
****************************************************************************
* PART 0: THE QUESTION
****************************************************************************
****************************************************************************

* THE STORY
* Smaller classes cost a lot of money: more teachers, more classrooms.
* Parents and teachers are sure they help. But are they right? Comparing
* schools with small and big classes does not settle it: schools with
* small classes are often richer, so their kids would do well anyway.
*
* In 1985 Tennessee ran a real EXPERIMENT (Project STAR). In 79 schools,
* kindergarten children and teachers were put by LOTTERY into one of three
* kinds of class:
*   small class               13-17 children
*   regular class             22-25 children
*   regular class + an aide   22-25 children and a teacher's aide
* Because a lottery decided, the three groups were alike in everything
* else (parents, income, ability...). So if small classes score higher at
* the end of the year, the CLASS SIZE gets the credit.
*
* THE QUESTION (Alan Krueger, 1999)
* How much higher do children in small classes score on the end-of-year
* reading + math test?
*
* BEFORE RUNNING ANYTHING: write down your guess. The average child scores
* about 920 points, and children differ by about 75 points.
* Is the effect 0 points? 5? 20? 50?

****************************************************************************
****************************************************************************
* PART 1: THE DATA
****************************************************************************
****************************************************************************

* Make a folder for the data (capture = no error if it already exists).
capture mkdir "data"

* Download the file once, from Harvard Dataverse.
* "confirm file" checks whether we already have it; _rc is 0 if yes.
* If not, "copy" downloads it from the internet into the data folder.
capture confirm file "data/STAR_Students.sav"
if _rc != 0 {
    copy "https://dataverse.harvard.edu/api/access/datafile/666716?format=original" ///
         "data/STAR_Students.sav"
}

* The file was saved by SPSS (another statistics program), not Stata.
* "import spss" reads it. Real data come in many formats.
import spss using "data/STAR_Students.sav", clear

* How big is it?
describe, short

* WHAT TO SEE: 11,601 students (rows) and 379 variables (columns).

* SPSS stored the names in CAPITALS (STDNTID, GKCLASSTYPE, ...).
* rename *, lower = make every name lower case, so they are easier to type.
rename *, lower

* ONE ROW = ONE CHILD. Check: the student ID should never repeat.
isid stdntid

* THE FILE IS "WIDE": one row per child, with SEPARATE COLUMNS for each
* grade. The first two letters say which grade:
*   gk = kindergarten, g1 = 1st grade, g2 = 2nd grade, g3 = 3rd grade.
*
*   +---------+-------------+-----------+-------------+-----+
*   | stdntid | gkclasstype | gktreadss | g1classtype | ... |
*   +---------+-------------+-----------+-------------+-----+
*   |  10133  |      3      |    427    |      3      | ... |
*   +---------+-------------+-----------+-------------+-----+
*
* (The take-home turns this into "long" form with reshape.)
* Look at the kindergarten columns:
describe gk*

****************************************************************************
****************************************************************************
* PART 2: KINDERGARTEN, THE SCORE, AND THE "SMALL" DUMMY
****************************************************************************
****************************************************************************

* Many children joined STAR in a later grade. Keep the ones who were in
* STAR in kindergarten (flagsgk = 1), the year of the first lottery.
tab flagsgk
keep if flagsgk == 1
count

* WHAT TO SEE: 6,325 kindergarteners.

* The three class types. The words come from value labels in the file.
* nolabel shows the numbers behind the words.
tab gkclasstype
tab gkclasstype, nolabel

* WHAT TO SEE: 1 = small (1,900 kids), 2 = regular (2,194),
* 3 = regular + aide (2,231).

* THE OUTCOME: reading score + math score on the Stanford Achievement Test.
generate score = gktreadss + gktmathss
label variable score "Kindergarten reading + math score"

* Look at the scores: number with data (Obs), average, spread, min, max.
summarize gktreadss gktmathss score

* WHAT TO SEE: about 5,800 children have a score (some missed a test).
* Average about 922 points; standard deviation about 74 points.

* THE MAIN VARIABLE: a DUMMY (yes/no, 1/0). Today we compare SMALL with
* REGULAR classes, so:
*   small = 1 in a small class, 0 in a regular class,
*           missing (.) in a regular + aide class (left out for now).
generate small = .
replace small = 1 if gkclasstype == 1
replace small = 0 if gkclasstype == 2

* Give the values words, so tables say "small"/"regular" instead of 1/0.
* label define = make a list of words; label values = attach it.
label define smalllbl 0 "regular" 1 "small"
label values small smalllbl
label variable small "Small class (vs regular)"

* ALWAYS CHECK a new variable against the one it came from.
tab gkclasstype small, missing

****************************************************************************
****************************************************************************
* MODEL 1: A REGRESSION ON A YES/NO VARIABLE
*   score = b0 + b1*small + error
****************************************************************************
****************************************************************************

* First, without a regression: the average score in each group.
* bysort small: = do the next command separately for each value of small.
bysort small: summarize score

* WHAT TO SEE
*   regular:  918.0 points (2,005 children)
*   small:    931.9 points (1,738 children)
*   (the third block, small = ., is the aide classes)

* The gap by hand. After summarize, Stata keeps the average in r(mean).
* A local is a named box that holds a number; we use it as `name'.
quietly summarize score if small == 1
local mean_small = r(mean)
quietly summarize score if small == 0
local mean_regular = r(mean)
display "Gap (small - regular) = " `mean_small' - `mean_regular'

* WHAT TO SEE: 13.9 points.

* Now the regression.
regress score small

* Store the results under the name m1 for the table at the end.
estimates store m1

* WHAT TO SEE
* - _cons = 918.0 = the average in REGULAR classes (where small = 0).
* - small = 13.9  = the GAP. Small classes score 13.9 points higher.
* The regression just compares the two averages. With a 0/1 variable,
* "one unit more of x" means "moving from the regular to the small group".
*
*   +---------+--------------------+-------------------------+
*   | small   | the regression says| = the group average     |
*   +---------+--------------------+-------------------------+
*   | 0       | 918.0              | regular classes: 918.0  |
*   | 1       | 918.0 + 13.9       | small classes:   931.9  |
*   +---------+--------------------+-------------------------+

* FITTED VALUES = the regression's guess for each child.
* With a 0/1 x there are only TWO guesses: the two group averages.
predict scorehat, xb
tab scorehat small

* RESIDUALS = actual score - guess = how far a child is from their
* group's average. Positive = did better than the group average.
predict uhat, residuals
list stdntid small score scorehat uhat in 1/5

* WHAT TO SEE: child 12424 is in a regular class, scored 967; the guess
* is 918.0, so the residual is +49.0.

* On average the residuals are exactly zero (OLS makes sure of this).
summarize uhat

****************************************************************************
****************************************************************************
* READ EVERY NUMBER IN THE MODEL 1 TABLE
****************************************************************************
****************************************************************************

* Show Model 1 again (estimates replay = re-print stored results).
estimates replay m1

* (a) THE STANDARD ERROR (SE) = 2.45
* If Tennessee ran the same lottery again with NEW children, we would get
* a slightly different gap: maybe 11, maybe 17. The SE measures how much
* the gap moves from one rerun to the next. (The notebook does the reruns.)
display "b1 = " _b[small] "    SE = " _se[small]

* The same numbers live in two matrices that regress leaves behind:
*   e(b) = the coefficients,  e(V) = their variances.
* SE = square root of the variance (the top-left number of V).
matrix B = e(b)
matrix V = e(V)
matrix list B
matrix list V
display "SE by hand = " sqrt(V[1,1])

* (b) THE t-STATISTIC = 5.68
* How many SEs is our gap away from zero?  t = b1 / SE = 13.9 / 2.45.
* We save it as a SCALAR (a named number). Unlike a local, a scalar stays
* in Stata's memory after the selected lines finish, so you can run the
* rest of this file in pieces and t_small is still there.
scalar t_small = _b[small] / _se[small]
display "t = " t_small

* We also save the degrees of freedom: e(df_r) changes as soon as we run
* another regression, but this scalar does not.
scalar df_small = e(df_r)

* (c) THE 95% CONFIDENCE INTERVAL = [9.1, 18.7]
* gap +/- (about 2) x SE. The exact "about 2" comes from the t
* distribution: invt(degrees of freedom, 0.975). e(df_r) = degrees of
* freedom = children - 2 = 3,741.
display "critical value = " invt(e(df_r), 0.975)
display "95% CI: [" _b[small] - invt(e(df_r), 0.975)*_se[small] ", " ///
                    _b[small] + invt(e(df_r), 0.975)*_se[small] "]"

* (d) THE p-VALUE = 0.000
* Suppose small classes truly did NOTHING (b1 = 0). How often would luck
* alone give a t this far from zero, in either direction?
*
* ttail(df, t) = the chance that a t-distributed number is BIGGER than t.
* It is the area of the RIGHT tail only:
*
*                        _.-'''-._
*                     .-'    |    '-.
*                   .'       |       '.
*            _ _ .-'         |         '-.|#####_ _ _
*           -----------------+------------+--------->
*                            0            t
*                                         |#####| = ttail(df, t)
*
* df = degrees of freedom = how many children we have, minus the number of
* coefficients we estimated. Here: 3,743 - 2 = 3,741 (stored in e(df_r),
* and saved above as the scalar df_small).
*
* Try ttail at 1.96 with LOTS of degrees of freedom: 2.5% is in the tail.
display "ttail(3741, 1.96) = " ttail(3741, 1.96)

* Now with only 5 degrees of freedom (7 children): the tail is FATTER.
* With few children, the SE itself is a noisy guess, so big t's happen
* by luck more often than the bell curve says.
display "ttail(5, 1.96)    = " ttail(5, 1.96)

* WHAT TO SEE: 0.025 versus 0.054. With few children, "1.96" is not
* far enough to call something unusual.

* TWO-SIDED p: luck could push the gap up OR down, so we count BOTH tails.
* abs() = absolute value, so it works for a negative t too.
*
*            |#####_ _ _ .-'''''''''''-. _ _ _#####|
*           -+-----------------+-----------------+->
*           -t                 0                 t
*
display "two-sided p = " 2*ttail(df_small, abs(t_small))

* WHAT TO SEE: about 0.00000001. Luck almost never does this.
* Stata rounds it to 0.000 in the table (the column P>|t|).

* ONE-SIDED TEST. The question "do small classes HELP?" only cares about
* one direction:  H0: b1 <= 0  (they do not help)
*                 H1: b1 > 0   (they help)
* Only the upper (right) tail counts, so the p-value is half as big.
display "one-sided p (H1: b1 > 0) = " ttail(df_small, t_small)

* The OTHER direction, H1: b1 < 0 ("small classes HURT"), uses the LEFT
* tail: the chance of a t SMALLER than ours = 1 - ttail(df, t).
display "one-sided p (H1: b1 < 0) = " 1 - ttail(df_small, t_small)

* WHAT TO SEE: almost 1. Our t is far to the right, so it gives no
* evidence at all that small classes hurt.

* CRITICAL VALUES go the other way round: invttail(df, area) gives the t
* that leaves that much area in the right tail.
display "5% two-sided: reject if |t| > " invttail(df_small, 0.025)
display "5% one-sided: reject if  t  > " invttail(df_small, 0.05)
display "1% two-sided: reject if |t| > " invttail(df_small, 0.005)

* WHAT TO SEE: 1.96, 1.65, 2.58: the numbers from the t table (table G.2
* in Wooldridge) for "infinite" degrees of freedom.

* AN EXAMPLE FROM THE LECTURE (house prices, Wooldridge's HPRICE1 data):
* a bedrooms coefficient with t = 1.53 and 88 - 5 = 83 degrees of freedom.
display "two-sided p = " 2*ttail(83, 1.53)
display "one-sided p = " ttail(83, 1.53)
display "one-sided critical values: 10% = " invttail(83, 0.10) ///
        "   5% = " invttail(83, 0.05)

* WHAT TO SEE: two-sided p = 0.13, one-sided p = 0.065. Against H1: b > 0
* we reject H0 at the 10% level (1.53 > 1.29) but not at 5% (1.53 < 1.66).
* SAME t, DIFFERENT ANSWER: decide one- or two-sided BEFORE you look.
*
* WHY "t"? The distribution was found in 1908 by William Gosset, a
* chemist at the Guinness brewery in Dublin who tested barley and beer
* with very small samples. Guinness did not let staff publish under
* their own names, so he signed his paper "Student". Ronald Fisher later
* wrote the statistic with the letter t, and the name "Student's t"
* stuck. (The notebook draws the t curve for any degrees of freedom.)

* (e) A t-TEST GIVES THE SAME t
* ttest compares the two group averages directly. (It subtracts in the
* other order, regular - small, so its difference and t have a minus.)
ttest score, by(small)

* (f) R-SQUARED = 0.009
* The share of the differences in scores BETWEEN CHILDREN that the model
* explains:  R2 = explained sum of squares / total sum of squares.
* e(mss) = explained ("model") SS,  e(rss) = residual SS.
display "R2 by hand = " e(mss) / (e(mss) + e(rss))
display "R2 Stata   = " e(r2)

* WHAT TO SEE: less than 1%! Children differ a LOT for reasons that have
* nothing to do with class size (home, sleep, age, luck on test day).
* But the effect of class size is still REAL (t = 5.7).
* A LOW R2 DOES NOT MEAN THE POLICY DOES NOT MATTER.

* (g) HOW BIG IS 13.9 POINTS? Compare it with how much children differ.
* After summarize, r(sd) holds the standard deviation.
quietly summarize score
display "Effect in standard deviations = " _b[small] / r(sd)

* WHAT TO SEE: about 0.19 SD: about a fifth of the usual gap between two
* random children. (Krueger reports percentiles: about +4 percentile
* points in the first year in a small class.)
*
* THE QUESTION LEFT: the lottery was held INSIDE each school. Does the
* gap hold when we compare children only with others in the same school?

****************************************************************************
****************************************************************************
* MODEL 2: ADD SCHOOL DUMMIES
*   score = b0 + b1*small + (one intercept per school) + error
****************************************************************************
****************************************************************************

* i.gkschid = one dummy per school (like Maple, Oak, Pine in Week 4).
* Now b1 compares small and regular classes INSIDE the same school.
* quietly = do not print the 79 school rows; we print what we need below.
quietly regress score small i.gkschid

* Store the results under the name m2.
estimates store m2

* Compare the small-class coefficient with Model 1.
estimates table m1 m2, keep(small) b(%9.2f) se(%9.2f) stats(N r2)

* WHAT TO SEE
* - small: 13.9 -> 16.0. Hardly moves. That is what a lottery buys you:
*   small classes were not hiding in better schools, so holding the
*   school fixed changes little. (Compare Papke in Week 5, where adding
*   school fixed effects changed the answer a lot: there was no lottery.)
* - R2: 0.009 -> 0.24. Schools differ a lot, so school dummies explain
*   much more of the scores. But the class-size effect barely changes.
*   EXPLAINING MORE OF Y IS NOT THE SAME AS GETTING THE EFFECT RIGHT.
* - SE: 2.45 -> 2.22. Removing school differences from the noise makes
*   the estimate a little more precise.
*
* THE QUESTION LEFT: we ignored the third group, regular + aide. Is an
* aide as good as a small class?

****************************************************************************
****************************************************************************
* MODEL 3: ALL THREE CLASS TYPES, AND THE F-TEST
*   score = b0 + b1*(small) + b2*(regular + aide) + error
****************************************************************************
****************************************************************************

* ib2. = make REGULAR (value 2) the base group. Each coefficient is then
* a gap compared with a regular class. (One group must be the base, or the
* dummies always add up to 1: the dummy variable trap from Week 4.)
regress score ib2.gkclasstype

* Store the results under the name m3.
estimates store m3

* WHAT TO SEE
* - SMALL CLASS:          13.9 (t = 5.8). Same gap as before.
* - REGULAR + AIDE CLASS:  0.3 (t = 0.14, p = 0.89). An aide adds nothing.
* - Up top: F(2, 5783) = 21.26, Prob > F = 0.0000.

* THE F-TEST: does class type matter AT ALL?
* H0: BOTH gaps are zero (small = 0 AND aide = 0). One test for both.
test 1.gkclasstype 3.gkclasstype

* WHAT TO SEE: F = 21.26, the same F that regress prints at the top.
* The top-of-table F always tests "all the x's together are zero".

* Is a small class better than a regular class WITH an aide?
* H0: the two gaps are equal.
test 1.gkclasstype = 3.gkclasstype

* WHAT TO SEE: F = 32.1, p = 0.000. Yes: a small class beats an aide.

****************************************************************************
****************************************************************************
* WRAP-UP: ALL THREE MODELS SIDE BY SIDE
****************************************************************************
****************************************************************************

* A quick table in the Results window.
* In Model 3 the small-class row is called 1.gkclasstype; the table shows
* it on its own row.
estimates table m1 m2 m3, keep(small 1.gkclasstype 3.gkclasstype) ///
    b(%9.2f) se(%9.2f) stats(N r2) stfmt(%9.3f)

* The same table as a LaTeX file (star_table.tex) for the slides and as a
* web page (star_table.html). esttab comes from the estout package. If
* Stata says "command esttab not found", run: ssc install estout
* rename() puts Model 3's small-class row on the same line as "small";
* keep() then lists the rows to show, using the NEW name.
* indicate() adds a "Yes/No" row instead of listing 79 school dummies.
esttab m1 m2 m3 using "star_table.tex", replace booktabs nofloat       ///
    rename(1.gkclasstype small) keep(small 3.gkclasstype)              ///
    coeflabels(small "Small class" 3.gkclasstype "Regular + aide")     ///
    mtitles("Small vs regular" "+ School dummies" "All three types")   ///
    b(2) se(2) star(* 0.10 ** 0.05 *** 0.01) nonotes                   ///
    indicate("School dummies = *.gkschid")                             ///
    stats(N r2, labels("Observations" "R-squared") fmt(%9.0fc %9.3f))

esttab m1 m2 m3 using "star_table.html", replace html                  ///
    rename(1.gkclasstype small) keep(small 3.gkclasstype)              ///
    coeflabels(small "Small class" 3.gkclasstype "Regular + aide")     ///
    mtitles("Small vs regular" "+ School dummies" "All three types")   ///
    b(2) se(2) star(* 0.10 ** 0.05 *** 0.01) nonotes                   ///
    indicate("School dummies = *.gkschid")                             ///
    stats(N r2, labels("Observations" "R-squared") fmt(%9.0fc %9.3f))

* THREE TAKEAWAYS
* 1. A regression on a yes/no variable compares two averages: the
*    coefficient IS the gap (13.9 points, about 0.19 SD).
* 2. Every number in the table answers a plain question: SE = how much
*    would it move in a rerun; t = how many SEs from zero; p = how often
*    luck alone does this; CI = the range we cannot rule out; R2 = how
*    much of the differences between kids we explain (here: very little,
*    and that is fine).
* 3. With a LOTTERY, adding controls (school dummies) barely moves the
*    answer. Without one (Papke, Week 5), it can move a lot.
*
* COMING LATER: Krueger's paper finds that the gain grows by about one
* percentile point per year and is bigger for minority children and
* children on free lunch.
* You can check two of these in the take-home below.

****************************************************************************
****************************************************************************
* TAKE-HOME (OPTIONAL)
****************************************************************************
****************************************************************************

* (T1) DOES A SMALL CLASS HELP CHILDREN ON FREE LUNCH MORE?
* gkfreelunch: 1 = free lunch, 2 = not. Make a 0/1 dummy first.
* The "if !missing()" part keeps children with no information as missing.
generate freelunch = (gkfreelunch == 1) if !missing(gkfreelunch)

* ## = both dummies AND their product (an "interaction"). The product
* row says how much MORE (or less) the small-class gap is for free-lunch
* children.
regress score i.small##i.freelunch
test 1.small#1.freelunch

* WHAT TO SEE
* - freelunch: about -39. Poorer children score much lower.
* - small#freelunch: about -0.5, p = 0.92. In test-score POINTS the gap is
*   about the same for both groups. (Krueger measures scores in
*   percentiles and finds a somewhat bigger gain for free-lunch children:
*   how you measure the outcome can matter.)

* (T2) RESHAPE: DOES THE BENEFIT LAST TO 3RD GRADE?
* preserve = take a snapshot of the data; restore (below) brings it back.
preserve

* Keep the ID, the kindergarten lottery result, and the scores per grade.
keep stdntid small gktreadss gktmathss g1treadss g1tmathss             ///
     g2treadss g2tmathss g3treadss g3tmathss

* WIDE -> LONG. The @ marks where the grade sits inside each name:
*   g@treadss matches gktreadss, g1treadss, g2treadss, g3treadss
* j(grade) = name of the new variable that holds k, 1, 2, 3.
* string = those values contain a letter (k), so grade is text.
reshape long g@treadss g@tmathss, i(stdntid) j(grade) string

* Now ONE ROW = ONE CHILD IN ONE GRADE (four rows per child).
list in 1/8
generate score_g = gtreadss + gtmathss

* The small-class gap in each grade, by KINDERGARTEN lottery result.
bysort grade: regress score_g small

* WHAT TO SEE (the gap, in points)
*   grade k: 13.9    grade 1: 19.8    grade 2: 9.6    grade 3: 11.7
* The gain is still there in 3rd grade.
* Careful: some children left STAR after kindergarten, so later grades
* have fewer children (3,743 in k, 1,983 in grade 3).

* Bring back the wide data.
restore

* Stop recording and save the log file.
log close
