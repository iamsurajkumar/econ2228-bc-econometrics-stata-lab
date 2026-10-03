
/* Start with an empty Stata session; this clears memory, not files on disk. */
clear all

/* Let the do-file run without pausing at the bottom of each output screen. */
set more off

/*
    WEEK 2 MINI RESEARCH PROJECT
    -----------------------------
    Question:
        Do USDA WASDE production revisions show up in Bloomberg futures-price
        surprises on the release date?

    Everything needed for the student exercise is in this Lecture 2 folder:
        wasde_revisions_week2.dta
        bbg_futures_week2.dta
        Week02_WASDE_BBG.do

    The Bloomberg variable price_surprise is a precomputed futures PC1 shock;
 
*/

/* Close an old log with the same name, if one is still open. */
capture log close

/* Record all commands and results in a plain-text log in this folder. */
log using "Week02_WASDE_BBG.log", text replace

/* Display the research question at the top of the log. */
display as text "Research question: do production revisions move futures prices?"

/* Explain the two data sources before opening either file. */
display as text "WASDE = USDA production information; Bloomberg = futures-market reaction."

/*--------------------------------------------------------------------------*
  1. Explore the WASDE file: one row per release x commodity
 *--------------------------------------------------------------------------*/

/* Load the simplified WASDE data and replace anything currently in memory. */
use "wasde_revisions_week2.dta", clear

/* Describe the number of observations, variables, and storage types. */
describe

/* Browse the data */
browse

/* Report detailed descriptive statistics for the production revision. */
summarize production_revision, detail
histogram production_revision

/* Count observations by crop. */
tabulate commodity

/* Deliberately test an incomplete key; release date alone is not unique. */
capture noisily isid release_date

/* Confirm that release date and crop uniquely identify each WASDE row. */
isid release_date commodity

/*--------------------------------------------------------------------------*
  2. Explore the Bloomberg file: one row per release x commodity
 *--------------------------------------------------------------------------*/

/* Load the simplified Bloomberg futures data. */
use "bbg_futures_week2.dta", clear

/* Describe the Bloomberg dataset. */
describe

/* Display the first ten observations so students can inspect the rows. */
list release_date commodity price_surprise in 1/10, noobs

/* Report detailed descriptive statistics for the price surprise. */
summarize price_surprise, detail

/* Count observations by crop. */
tabulate commodity

/* Show that one release event contains several commodity observations. */
tabulate event_id

/* Deliberately test an incomplete key; release date alone is not unique. */
capture noisily isid release_date

/* Confirm that release date and crop uniquely identify each Bloomberg row. */
isid release_date commodity


/*--------------------------------------------------------------------------*
  3. Merge the research files: the final key is release_date x commodity
 *--------------------------------------------------------------------------*/

/* Load the WASDE file as the master dataset for the research merge. */
use "wasde_revisions_week2.dta", clear

/* Confirm that the proposed 1:1 key is unique in the master file. */
isid release_date commodity

/* Ask students to predict the three _merge counts before seeing them. */
display as text "Prediction: 60 matched, 1 master-only, and 1 using-only observation."

/* Merge the WASDE and Bloomberg variables using release date and crop. */
merge 1:1 release_date commodity using "bbg_futures_week2.dta"

/* Count matches and mismatches by their _merge code. */
tabulate _merge

/* Add a heading before listing master-only observations. */
display as text "Master-only observation(s):"

/* Display observations found only in the master WASDE file. */
list release_date commodity production_revision if _merge == 1, noobs

/* Add a heading before listing using-only observations. */
display as text "Using-only observation(s):"

/* Display observations found only in the using Bloomberg file. */
list release_date commodity price_surprise if _merge == 2, noobs

/* Count master-only observations. */
count if _merge == 1

/* Count using-only observations. */
count if _merge == 2

/* Count observations successfully matched in both files. */
count if _merge == 3

/* Keep only rows containing variables from both source files. */
keep if _merge == 3

/* Remove the merge diagnostic after inspecting it. */
drop _merge

/* Confirm that the key remains unique in the matched analysis sample. */
isid release_date commodity

/* Give the explanatory variable a readable label in the results table. */
label variable production_revision "WASDE production revision (percent)"

/* Give the outcome variable a readable label in the results table. */
label variable price_surprise "Bloomberg futures surprise (PC1)"

/* Review the distributions of the two variables used in the regression. */
summarize production_revision price_surprise

/* Show the simple correlation before estimating the regression. */
correlate production_revision price_surprise

/* Plot the two variables before asking the regression for a summary slope. */
twoway (scatter price_surprise production_revision, mcolor(navy) msize(small)), yline(0) xline(0) title("WASDE revisions and futures-price surprises", color(black)) xtitle("Production revision") ytitle("Futures-price surprise") legend(off) note("Each point is one commodity-release observation.")


/* Simple Regression */
regress price_surprise production_revision








/* Close the log after all commands and results have been recorded. */
log close

/*
    Interpretation prompt for students:
        Is the coefficient negative, as a simple supply story suggests?
        What does one unit of production revision predict for the surprise?
        What would we need before calling this causal?
*/

/*




/*--------------------------------------------------------------------------*
  4. Install one command and export the results table in two formats
 *--------------------------------------------------------------------------*/

/* Run this once in the Command window if esttab is not installed:
       ssc install estout
*/

/* Check whether the user-written esttab command is available. */
capture which esttab

/* If esttab is unavailable, tell the student how to install it and stop. */
if _rc {
    /* Stop with a helpful message if estout has not been installed. */
    display as error "esttab is not installed. Run: ssc install estout"

    /* Stop the do-file because the table cannot yet be exported. */
    exit 199
}

/* Clear any stored estimation results from an earlier run. */
eststo clear

/* Estimate the one simple regression for today's mini-project. */
eststo main: regress price_surprise production_revision

/* Export the regression coefficient, standard error, sample size, and R-squared. */
esttab main using "Week02_WASDE_BBG_results.tex", replace tex se ///
    stats(N r2, labels("Observations" "R-squared") fmt(0 3)) ///
    mtitles("WASDE--Bloomberg") label ///
    title("WASDE revisions and Bloomberg futures surprises") ///
    addnotes("Classroom extract: 12 release events and 5 crops." ///
             "Coefficient is an association, not a causal estimate.")

/* Export the same regression table as HTML for students without LaTeX. */
esttab main using "Week02_WASDE_BBG_results.html", replace html se ///
    stats(N r2, labels("Observations" "R-squared") fmt(0 3)) ///
    mtitles("WASDE--Bloomberg") label ///
    title("WASDE revisions and Bloomberg futures surprises") ///
    addnotes("Classroom extract: 12 release events and 5 crops." ///
             "Coefficient is an association, not a causal estimate.")
	   
	   
*/
