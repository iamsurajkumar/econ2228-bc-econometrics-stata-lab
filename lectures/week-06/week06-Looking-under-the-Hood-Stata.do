*==============================================================================
* week06-Looking-under-the-Hood-Stata.do
*
* THE QUESTION
*   Is another year of school worth it?
*
*   Economists have asked this with the same regression since Jacob Mincer's
*   "Schooling, Experience, and Earnings" (1974). Every "return to college"
*   number in the news starts here. We run it on 526 American workers from
*   1976 and then rebuild every number in Stata's output by hand, because each
*   number answers one part of the question:
*
*       wage_i = b0 + b1 * educ_i + u_i
*
*       wage  = average hourly earnings, dollars per hour (1976 dollars)
*       educ  = years of schooling
*       b1    = slope: extra dollars per hour for one more year of schooling
*       b0    = intercept: fitted wage at educ = 0
*       u_i   = residual: actual wage minus fitted wage
*
*   Section  Student question                    Numbers rebuilt
*   -------  ----------------------------------  -------------------------------
*      1     How much is a year of school worth?  slope b1, intercept b0
*      2     What would I have earned?            fitted values, residuals
*      3     Can you beat Stata?  (line game)     SSR, "least squares"
*      4     Who beats the line?                  residuals, ranked
*      5     How much does school explain?        SS, df, MS, R2, Adj R2, Root MSE
*      6     Could this be luck?  (shuffle test)  F, Prob > F
*      7     How sure are we about b1?            SE, t, p-value, 95% CI
*      8     Check every number against Stata     e(), _b[], _se[]
*      9     What is hiding in the residual?      cliffhanger for next week
*
*   WHAT TO EXPECT (Stata's own output, 526 workers):
*       b1 = .5413593   b0 = -.9048516   F(1,524) = 103.36
*       R-squared = 0.1648   Adj R-squared = 0.1632   Root MSE = 3.3784
*
* DATA
*   Wooldridge's WAGE1 (526 workers; 1976 Current Population Survey, per the
*   textbook's data appendix), downloaded with `bcuse` from the Boston College
*   archive. Needs internet the first time; installs `bcuse` if missing.
*
* FILES
*   Input : none on disk (bcuse downloads wage1).
*   Output: none. Results print to the Results window / log. The shuffle test
*           writes a temporary file that Stata deletes on exit.
*
* HOW TO RUN
*   Step through it a few lines at a time (select lines, then Ctrl+D /
*   Cmd+Shift+D). Section 3 is meant to be re-run with your own numbers.
*   Requirements: Stata BE or better, no user-written packages except bcuse.
*==============================================================================

clear all           // wipe memory so earlier work cannot leak into this run
set more off        // do not pause the output after every screenful
set type double     // every new variable from `generate` keeps 16 digits (default `float` keeps 7),
                    // so our sums match Stata's to many decimal places


*==============================================================================
* 0. Guess first, then look at the data
*==============================================================================
* BEFORE RUNNING ANYTHING, write down your guess:
*   In 1976, how many extra dollars PER HOUR did one more year of school pay?
*   (Hint: the average wage was about $6/hour.)

* bcuse is a user-written command. `capture` runs `which bcuse` and hides the
* error if it is missing; _rc ("return code") is then nonzero, so we install it
* once from SSC. On the lab computers it is already there and nothing happens.
capture which bcuse
if _rc ssc install bcuse

bcuse wage1, clear              // load the Wooldridge WAGE1 dataset
describe                        // 24 variables, but the "Variable label" column is EMPTY

* The bcuse copy has no variable labels, so we add them. A label is a short
* description that Stata prints next to the variable name in describe,
* regress and graphs. Wording follows Wooldridge's description of WAGE1.
* "=1 if ..." marks a dummy (0/1) variable.
label variable wage     "average hourly earnings, $ per hour (1976)"
label variable educ     "years of education"
label variable exper    "years of potential experience"
label variable tenure   "years with current employer"
label variable nonwhite "=1 if nonwhite"
label variable female   "=1 if female"
label variable married  "=1 if married"
label variable numdep   "number of dependents"
label variable smsa     "=1 if lives in a metropolitan area (SMSA)"
label variable northcen "=1 if lives in north central U.S."
label variable south    "=1 if lives in southern region"
label variable west     "=1 if lives in western region"
label variable construc "=1 if works in construction industry"
label variable ndurman  "=1 if works in nondurable manufacturing"
label variable trcommpu "=1 if works in transport, communications, public utilities"
label variable trade    "=1 if works in wholesale or retail trade"
label variable services "=1 if works in services industry"
label variable profserv "=1 if works in professional services industry"
label variable profocc  "=1 if in a professional occupation"
label variable clerocc  "=1 if in a clerical occupation"
label variable servocc  "=1 if in a service occupation"
label variable lwage    "log(wage)"
label variable expersq  "exper squared"
label variable tenursq  "tenure squared"

describe                        // run again: now every variable says what it means
summarize wage educ             // N should be 526 for both (no missing values)

* Plot first: does a straight line make sense?
twoway (scatter wage educ) (lfit wage educ)   // dots + the OLS line through them

regress wage educ               // THE TARGET: everything below rebuilds this table


*==============================================================================
* 1. How much is a year of school worth?  (slope and intercept)
*==============================================================================
* The OLS slope is   b1 = sum[(x - xbar)(y - ybar)] / sum[(x - xbar)^2]
*                       = how x and y move together / how much x moves alone
* The intercept makes the line pass through the point of means (xbar, ybar):
*                    b0 = ybar - b1 * xbar

* A "scalar" is a single stored number. We name each piece so that later
* lines can reuse it. Each `summarize` prints its table; the number we
* keep is left behind in r() (r(mean), r(N), r(sum), ...), so read the table
* and then see it saved as a scalar.
* After every `scalar` line, `display "name = " name` prints what was just
* stored, so you can match it against the table above it.
summarize educ                     // summarize leaves results in r()
scalar xbar = r(mean)                      // r(mean) = average of educ
display "xbar = " xbar
scalar N    = r(N)                         // r(N) = number of observations used
display "N = " N
summarize wage
scalar ybar = r(mean)                      // average hourly wage
display "ybar = " ybar

* Deviations from the mean.
generate xdev  = educ - xbar        // how far each worker's schooling is from average
generate ydev  = wage - ybar        // how far each worker's wage is from average
generate xdev2 = xdev^2             // squared x deviation (the denominator pieces)
generate xydev = xdev * ydev        // product of deviations (the numerator pieces)

summarize xydev
scalar Sxy = r(sum)                        // r(sum) = total of the variable: sum[(x-xbar)(y-ybar)]
display "Sxy = " Sxy
summarize xdev2
scalar Sxx = r(sum)                        // sum[(x-xbar)^2], also called SST_x
display "Sxx = " Sxx

scalar b1 = Sxy / Sxx                      // slope
display "b1 = " b1
scalar b0 = ybar - b1 * xbar               // intercept
display "b0 = " b0

display "slope     b1 = " %10.7f b1 "   Stata: " %10.7f _b[educ]     // _b[name] = coefficient from the last regress
display "intercept b0 = " %10.7f b0 "   Stata: " %10.7f _b[_cons]    // _cons is Stata's name for the intercept
* %10.7f is a number format: width 10, 7 digits after the decimal point.

* How close was your guess? Now turn $/hour in 1976 into something you feel.
* A full-time year is about 2,000 hours (40 hours x 50 weeks).
scalar per_year_1976 = b1 * 2000           // extra dollars per year, 1976 prices
display "per_year_1976 = " per_year_1976
* Prices rose roughly 5.6-fold from 1976 to 2025 (CPI-U annual averages, about
* 322 / 56.9). Check at https://www.bls.gov/data/inflation_calculator.htm
scalar cpi_ratio = 5.6
display "cpi_ratio = " cpi_ratio
scalar per_year_today = per_year_1976 * cpi_ratio   // extra dollars per year, today's prices
display "per_year_today = " per_year_today
scalar college_today = 4 * per_year_today  // four years of college, every year of a career
display "college_today = " college_today
display "One more year of school: about $" %6.0fc per_year_today " a year in today's dollars"
* %6.0fc = no decimals, with thousands commas.


*==============================================================================
* 2. What would I have earned?  (fitted values and residuals)
*==============================================================================
* fitted value  = what the line predicts for each worker:  yhat = b0 + b1*educ
* residual      = what the line misses:                    u    = wage - yhat

* The line's prediction for a high-school graduate (12 years) and a college
* graduate (16 years):
scalar wage_hs  = b0 + b1 * 12
display "wage_hs = " wage_hs
scalar wage_col = b0 + b1 * 16
display "wage_col = " wage_col

* The intercept is the prediction at educ = 0, and it is NEGATIVE: -$0.90/hour.
* Nobody is paid a negative wage. Why does the line say so? Look at how few
* workers sit near educ = 0: the line is extrapolating where there is no data.
tabulate educ

generate yhat = b0 + b1 * educ      // the line's guess for each worker
generate uhat = wage - yhat         // actual minus guess

summarize yhat uhat                        // residuals should average 0 by construction
list wage educ yhat uhat in 1/5            // eyeball the first five workers


*==============================================================================
* 3. Can you beat Stata?  (the line game)
*==============================================================================
* Every line through the cloud misses each worker by some residual. Square the
* misses and add them up: that is the Sum of Squared Residuals (SSR).
* OLS = "Ordinary LEAST SQUARES": the line with the smallest possible SSR.
*
* YOUR TURN: change the two numbers below, then re-run this whole section.
* Post your SSR. Can anybody in the room beat the OLS line?

scalar b0_guess = 0                        // <-- your intercept
display "b0_guess = " b0_guess
scalar b1_guess = 0.5                      // <-- your slope
display "b1_guess = " b1_guess

* `capture` runs a command and ignores an error if it fails. Here `drop`
* fails the first time (the variables do not exist yet); on re-runs it clears
* your previous guess.
capture drop uhat_guess uhat_guess2
generate uhat_guess  = wage - (b0_guess + b1_guess * educ)   // your misses
generate uhat_guess2 = uhat_guess^2                          // squared

summarize uhat_guess2
scalar SSR_guess = r(sum)                  // YOUR sum of squared residuals
display "SSR_guess = " SSR_guess

capture drop uhat2
generate uhat2 = uhat^2             // squared OLS residual
summarize uhat2
scalar SSR = r(sum)                        // the OLS sum of squared residuals
display "SSR = " SSR

display "Your SSR: " %10.2f SSR_guess "     OLS SSR: " %10.2f SSR
display "You missed by " %8.2f SSR_guess - SSR " more squared dollars than OLS"

* Picture: your line (dashed) against the OLS line.
* `=b0_guess' asks Stata to evaluate the expression and paste the NUMBER into
* the command; twoway function needs a number, not a scalar name.
twoway (scatter wage educ, msize(small))                                   ///
       (function y = `=b0_guess' + `=b1_guess'*x, range(educ) lpattern(dash)) ///
       (lfit wage educ),                                                   ///
       legend(order(2 "Your line" 3 "OLS line"))
* /// continues a command on the next line.


*==============================================================================
* 4. Who beats the line?  (residual hall of fame)
*==============================================================================
* A big positive residual = paid far more than schooling alone predicts.
* A big negative residual = paid far less. Look at the OTHER columns: what do
* the winners have that the line does not know about?
* gsort -uhat sorts from the largest residual down (the minus means descending).

gsort -uhat
list wage educ yhat uhat exper tenure female profocc in 1/5    // the top five

gsort uhat
list wage educ yhat uhat exper tenure female profocc in 1/5    // the bottom five
* Everything the line ignores (experience, tenure, job, gender, luck) lives
* in the residual. Hold that thought for section 9.


*==============================================================================
* 5. How much does school explain?  (the ANOVA table)
*==============================================================================
* Total variation in wage is split into a part the line explains and a part
* it does not:
*       SST  =  SSE  +  SSR
*       Total = Model + Residual
*   SST = sum[(y - ybar)^2]   how much wages vary around their average
*   SSE = sum[(yhat - ybar)^2] how much the FITTED values vary (Stata: "Model")
*   SSR = sum[uhat^2]          what is left over (Stata: "Residual"; section 3)
* Naming warning: some books use SSE for the RESIDUAL sum and SSR for the
* explained one. Paul's handouts use SSE = explained, SSR = residual.

generate ydev2    = ydev^2           // squared deviation of actual wage
generate yhatdev2 = (yhat - ybar)^2  // squared deviation of fitted wage

summarize ydev2
scalar SST = r(sum)                        // Total SS
display "SST = " SST
summarize yhatdev2
scalar SSE = r(sum)                        // Model SS
display "SSE = " SSE
display "SSR = " SSR                       // Residual SS, already built in section 3

* Degrees of freedom: how many independent pieces of information each SS has.
scalar k       = 1                         // number of slope coefficients (just educ)
display "k = " k
scalar df_m    = k                         // Model df
display "df_m = " df_m
scalar df_r    = N - k - 1                 // Residual df: N minus slopes minus intercept
display "df_r = " df_r
scalar df_t    = N - 1                     // Total df: N minus one (the mean was estimated)
display "df_t = " df_t

* Mean squares: each SS divided by its df (an average squared deviation).
scalar MS_m = SSE / df_m                   // Model MS
display "MS_m = " MS_m
scalar MS_r = SSR / df_r                   // Residual MS = estimate of the error variance
display "MS_r = " MS_r
scalar MS_t = SST / df_t                   // Total MS = sample variance of wage
display "MS_t = " MS_t

display "Model    SS = " %12.5f SSE "  df = " df_m "  MS = " %12.7f MS_m
display "Residual SS = " %12.5f SSR "  df = " df_r "  MS = " %12.7f MS_r
display "Total    SS = " %12.5f SST "  df = " df_t "  MS = " %12.7f MS_t
display "check SSE + SSR = SST: " %12.5f SSE + SSR "  vs  " %12.5f SST

* Total MS is just the variance of wage, so summarize should agree:
summarize wage
display "var(wage) = " %12.7f r(Var)       // r(Var) = sample variance

* R-squared: share of the variation in wage that the line explains.
scalar R2 = SSE / SST                      // equivalently 1 - SSR/SST
display "R2 = " R2

* Adjusted R-squared: the same idea after dividing each SS by its df, which
* penalises adding regressors that explain little. 1 - (typical miss)/(typical spread).
scalar R2adj = 1 - MS_r / MS_t
display "R2adj = " R2adj

* Root MSE: square root of the Residual MS. The typical size of a residual,
* in dollars per hour, the same units as wage.
scalar rmse = sqrt(MS_r)
display "rmse = " rmse

display "R-squared     = " %6.4f R2
display "Adj R-squared = " %6.4f R2adj
display "Root MSE      = " %6.4f rmse

* DEBATE: schooling explains only about 16% of the differences in wages.
* Is education unimportant? Keep your answer until section 7.


*==============================================================================
* 6. Could this be luck?  (F, Prob > F, and the shuffle test)
*==============================================================================
* F compares explained variation per regressor to unexplained variation per
* leftover degree of freedom. Large F = the line explains much more than noise.
scalar Fstat = MS_m / MS_r
display "Fstat = " Fstat
* Prob > F: the chance of an F this large if educ truly did nothing.
* Ftail(df1, df2, F) returns the upper-tail probability of the F distribution.
scalar pF = Ftail(df_m, df_r, Fstat)
display "pF = " pF
display "F(" df_m "," df_r ") = " %8.2f Fstat "   Prob > F = " %6.4f pF

* What does "if educ truly did nothing" look like? Make it true: shuffle the
* schooling numbers across workers, so each wage is paired with a stranger's
* education. Any pattern left is pure luck.
set seed 2228                              // fixes the random draws so everyone gets the same shuffle
generate rnd = runiform()           // a random number for each worker
sort rnd                                   // put workers in random order
generate educ_shuf = educ[mod(_n, _N) + 1] // each worker takes the NEXT worker's schooling
* _n = this row's number, _N = number of rows; mod() wraps the last row to the first.

regress wage educ_shuf                     // one shuffled world
scalar F_shuf = e(F)                       // e(F) = F statistic stored by the last regress
display "F_shuf = " F_shuf
display "Real F: " %8.2f Fstat "     Shuffled F: " %8.2f F_shuf

* One shuffle is one draw. `permute` repeats the shuffle 500 times, reruns the
* regression each time, and counts how often luck produces an F as big as 103.
*   educ          = the variable to shuffle
*   F=e(F)        = the number to record each time
*   reps(500)     = number of shuffles
*   seed(2228)    = same random draws for everyone
*   saving(...)   = keep all 500 F values in a file so we can plot them
* `tempfile` makes a file name that Stata deletes automatically when it exits.
* A local macro holds text; `shuffles' (backtick + apostrophe) reads it back.
tempfile shuffles
permute educ F=e(F), reps(500) seed(2228) saving(`shuffles'): regress wage educ
* Read the "upper" row: c = number of shuffles with F at least as big as the
* real 103.36. Out of 500 shuffles, c = 0: luck never came close.

* Plot the 500 "luck" F values against the real one. preserve/restore lets us
* open the shuffles file and come back to our data untouched.
preserve
use `shuffles', clear
summarize F                                // luck alone gives F near 1
histogram F, xline(`=Fstat') xtitle("F statistic from 500 shuffled datasets") ///
    note("Vertical line = the real F")
restore


*==============================================================================
* 7. How sure are we about b1?  (SE, t, p-value, 95% CI)
*==============================================================================
* SE of the slope: how much b1 would change from sample to sample.
*       SE(b1) = sqrt( MS_r / Sxx )
* Noisy data (big MS_r) or little spread in educ (small Sxx) both make b1 less precise.
scalar se_b1 = sqrt(MS_r / Sxx)
display "se_b1 = " se_b1

* SE of the intercept: sqrt( MS_r * (1/N + xbar^2 / Sxx) )
scalar se_b0 = sqrt(MS_r * (1/N + xbar^2 / Sxx))
display "se_b0 = " se_b0

* t statistic: how many SEs the estimate is from zero (the null "no effect").
scalar t_b1 = b1 / se_b1
display "t_b1 = " t_b1
scalar t_b0 = b0 / se_b0
display "t_b0 = " t_b0

* With one regressor, F = t squared, so the F test and the t test on educ are
* the same test:
display "t_b1^2 = " t_b1^2 "   Fstat = " Fstat

* Two-sided p-value: chance of a |t| this large if the true coefficient were 0.
* ttail(df, t) is the upper-tail probability of the t distribution, so we
* double it for both tails. abs() makes negative t work too.
scalar p_b1 = 2 * ttail(df_r, abs(t_b1))
display "p_b1 = " p_b1
scalar p_b0 = 2 * ttail(df_r, abs(t_b0))
display "p_b0 = " p_b0
* 2.8e-22 is scientific notation: 0.00000000000000000000028. Stata's table
* rounds it to 0.000.

* 95% CI: estimate +/- critical value * SE. invttail(df, 0.025) is the t value
* that leaves 2.5% in the upper tail (about 1.96 for large samples).
scalar tcrit = invttail(df_r, 0.025)
display "tcrit = " tcrit
scalar lo_b1 = b1 - tcrit * se_b1
display "lo_b1 = " lo_b1
scalar hi_b1 = b1 + tcrit * se_b1
display "hi_b1 = " hi_b1
scalar lo_b0 = b0 - tcrit * se_b0
display "lo_b0 = " lo_b0
scalar hi_b0 = b0 + tcrit * se_b0
display "hi_b0 = " hi_b0

display "educ : coef " %9.6f b1 "  SE " %9.6f se_b1 "  t " %6.2f t_b1 "  p " %5.3f p_b1 "  CI [" %9.6f lo_b1 ", " %9.6f hi_b1 "]"
display "_cons: coef " %9.6f b0 "  SE " %9.6f se_b0 "  t " %6.2f t_b0 "  p " %5.3f p_b0 "  CI [" %9.6f lo_b0 ", " %9.6f hi_b0 "]"

* BACK TO THE DEBATE: t = 10 says the effect of schooling is real and precisely
* measured. R-squared = 0.16 says schooling is far from the whole story. Both
* are true at once. (Same lesson as STAR: R-squared 0.009, effect still real.)


*==============================================================================
* 8. Check every number against Stata
*==============================================================================
* After `regress`, Stata stores results in e(). `ereturn list` shows them all:
* e(mss) Model SS, e(rss) Residual SS, e(df_m), e(df_r), e(F), e(r2), e(r2_a), e(rmse).
* We re-run regress so e() belongs to this model (the shuffles replaced it),
* then compare each stored number with ours. assert stops the do-file with an
* error if a claim is false.
* reldif(a,b) = relative difference; below 1e-6 means they agree to 6 digits.

regress wage educ
ereturn list                                 // see everything Stata saved

assert reldif(b1,   _b[educ])  < 1e-6        // slope
assert reldif(b0,   _b[_cons]) < 1e-6        // intercept
assert reldif(SSE,  e(mss))    < 1e-6        // Model SS
assert reldif(SSR,  e(rss))    < 1e-6        // Residual SS
assert df_m == e(df_m) & df_r == e(df_r)     // degrees of freedom
assert reldif(Fstat, e(F))     < 1e-6        // F statistic
assert reldif(R2,    e(r2))    < 1e-6        // R-squared
assert reldif(R2adj, e(r2_a))  < 1e-6        // Adj R-squared
assert reldif(rmse,  e(rmse))  < 1e-6        // Root MSE
assert reldif(se_b1, _se[educ])  < 1e-6      // _se[name] = standard error from the last regress
assert reldif(se_b0, _se[_cons]) < 1e-6

display as result "All hand-made numbers match Stata's regress output."


*==============================================================================
* 9. What is hiding in the residual?  (cliffhanger)
*==============================================================================
* The line uses schooling only. If it treated everyone fairly, the average
* residual would be about zero for every group. Is it?
tabstat uhat, by(female) statistics(mean n)    // average miss for men (0) and women (1)
tabstat uhat, by(married) statistics(mean n)   // and for unmarried (0) / married (1)
* If women's average residual is negative, women earn less than their
* schooling predicts. Is that discrimination, experience, job choice, or
* something else? NEXT WEEK: put female, exper and tenure into the regression
* and find out.


*==============================================================================
* 10. Your turn
*==============================================================================
* (a) Rescale wage to cents (generate wage_c = 100*wage) and rerun sections
*     1-7. Which numbers change, which stay the same? (R-squared and t do not.)
* (b) Replace wage with ln(wage), generate lwage = ln(wage). What does b1 mean now?
* (c) Why is Total MS equal to the variance of wage but Residual MS is not?
*
* NEXT WEEK: add exper and tenure. With k = 2 or 3 slopes, df_m = k, and the
* slope formula needs matrix algebra (Lecture 13): b = inv(X'X) * X'y.
