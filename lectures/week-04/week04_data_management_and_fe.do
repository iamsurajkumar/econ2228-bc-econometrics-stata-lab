****************************************************************************
* WEEK 4: BUILD THE SCHOOL-YEAR DATA, THEN ASK A NEW QUESTION
*
* Class plan
*   First 20 minutes: identify rows, merge school and district files, reshape.
*   Next 30 minutes: use Papke (2005) to compare schools with themselves.
*
* The toy version of Part 2 (three schools: Maple, Oak, Pine) is in
* week04_maple_pine_oak_fe.do. The original Boston College dataset is not
* changed: every file we make is saved as a new file in the working folder.
*
* This file was prepared with the help of Claude, an AI agent by Anthropic.
****************************************************************************

* Tell Stata which folder to work in. Change this to YOUR week-04 folder.
* Every file we save below (the log and the .dta files) goes in this folder.
cd "/Users/macbox/Library/CloudStorage/Dropbox/PhD/teaching/econometrics/lectures/week-04"

* Remove any data, results, and graphs left over from earlier work.
clear all

* Show all output at once, without pausing for "--more--".
set more off

* Close a log that may still be open from an earlier run (no error if none).
capture log close

* Start a log: a text file that records every command and its output.
* replace = overwrite the old log; text = save as plain text.
log using "week04_data_management_and_fe.log", replace text

****************************************************************************
* PART 1 (FIRST 20 MINUTES): REBUILD THE SCHOOL-YEAR DATA
****************************************************************************

* Load the data. Source: Boston College Wooldridge dataset school93_98,
* also used by Papke. One observation is one school in one school year.
* Codebook: http://fmwww.bc.edu/ec-p/data/wooldridge/school93_98.des
* If Stata says "command bcuse not found", run: ssc install bcuse
bcuse school93_98, clear

* List every variable with its type and description.
describe

* Count the rows (observations) in the data.
count

* How many rows in each year? missing = also count rows with no year.
tabulate year, missing

* How many values are missing in each of the variables we will use?
misstable summarize schid distid year math4 lunch lavgrexpp found

* A school appears in several years, so school ID alone is not the row key.
* The pair school ID + year should identify each row exactly once.
* isid stops with an error if any school-year appears twice.
isid schid year

****************************************************************************
* STEP 1: MAKE A SCHOOL-YEAR FILE OF SCORES AND SCHOOL CHARACTERISTICS
****************************************************************************

* preserve = take a snapshot of the data. Everything until restore changes
* only a temporary copy; restore brings the full data back.
preserve

    * Keep only the school-level variables we need (drop all others).
    keep schid distid year math4 lunch lavgrexpp lenrol

    * Give the dataset a short description, shown by describe.
    label data "School-year outcomes and school characteristics"

    * Check again that school + year still identifies each row.
    isid schid year

    * Save this smaller file in the working folder.
    save "school_year.dta", replace

* Bring back the full dataset.
restore

****************************************************************************
* STEP 2: MAKE A DISTRICT-YEAR FILE OF FOUNDATION GRANTS
****************************************************************************

* The source repeats the district foundation grant on each school row.
* We want one copy per district and year so the merge key is unique.
preserve

    * Keep only the district ID, the year, and the grant.
    keep distid year found

    * Check: within each district-year, every school row has the same grant.
    * found[1] = the value on the first row of that district-year group.
    * assert stops with an error if the statement is false on any row.
    bysort distid year: assert found == found[1]

    * Keep only the first row of each district-year (_n == 1).
    bysort distid year: keep if _n == 1

    * Check: district + year now identifies each row exactly once.
    isid distid year

    * Give the dataset a short description.
    label data "One foundation grant per school district and year"

    * Save this district-year file in the working folder.
    save "district_year_grant.dta", replace

* Bring back the full dataset.
restore

****************************************************************************
* STEP 3: MERGE DISTRICT GRANTS ONTO THE SCHOOL-YEAR FILE
****************************************************************************

* Open the school-year file from Step 1.
use "school_year.dta", clear

* Many schools can belong to the same district in one year; each district-year
* appears once in the grant file. Therefore this is a many-to-one (m:1) merge,
* matched on distid and year.
merge m:1 distid year using "district_year_grant.dta"

* merge creates _merge: 1 = only in school file, 2 = only in grant file,
* 3 = matched in both. Count how many rows fall in each group.
tabulate _merge

* Check that every row matched (stops with an error if not).
assert _merge == 3

* We no longer need _merge, so remove it.
drop _merge

* The merge should add information without duplicating school-year rows.
isid schid year

* Put the variables in a readable order (this does not change any values).
order schid distid year math4 lavgrexpp lunch lenrol found

* Save the merged file in the working folder.
save "school_year_merged.dta", replace

****************************************************************************
* STEP 4: RESHAPE LONG TO WIDE, THEN BACK TO LONG
****************************************************************************

* The regression data are long: one row per school-year.
* First put each school's math pass rates in separate year columns.
preserve

    * Keep only the school ID, the year, and the pass rate.
    keep schid year math4

    * Long to wide: one row per school, one math4 column per year
    * (math41993, math41994, ...). i() = the row ID, j() = the column suffix.
    reshape wide math4, i(schid) j(year)

    * List the new year columns. math4* means "every variable starting
    * with math4".
    describe math4*

    * Show the first 5 schools (in 1/5 = rows 1 to 5).
    list schid math41993 math41994 math41995 math41996 math41997 math41998 in 1/5

    * Wide back to long: one row per school-year again.
    reshape long math4, i(schid) j(year)

    * Check that the school-year pair is the row key again.
    isid schid year

* Bring back the full dataset.
restore

****************************************************************************
* PART 2 (NEXT 30 MINUTES): PAPKE'S QUESTION AND THE TWO COMPARISONS
****************************************************************************

* Open the merged file from Step 3.
use "school_year_merged.dta", clear

* Papke asks whether higher real spending per pupil raises the 4th-grade math
* pass rate. Tell Stata this is panel data: schid is the school (the unit),
* year is the time.
xtset schid year

* Add the nonlinear controls used in the article's Table 7 columns 1 and 2.
* lunch2 = the lunch share squared.
generate lunch2 = lunch^2

* lenrol2 = log enrollment squared.
generate lenrol2 = lenrol^2

* i.year adds "year indicators": they absorb changes that hit every school
* in the same year, such as a test becoming easier or harder. (We look at
* how i. works in Week 5; for now read it as "control for the year".)
*
* vce(cluster schid) = "clustered standard errors": the same school's rows
* in different years are likely related, and this lets the errors be
* correlated within a school.

* Pooled OLS: one regression through every school-year observation.
* Like the grey line for Maple, Oak and Pine, it mixes comparisons between
* different schools with comparisons of a school with itself.
regress math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, vce(cluster schid)

* WHAT IS A FIXED-EFFECTS REGRESSION?
* Every school has its own "usual level" of scores: neighbourhood,
* parents, teachers, building. These things barely change over the years.
* That usual level is the school's FIXED EFFECT. We cannot measure it, but
* because it does not change over time we can remove it.
*
* A fixed-effects regression compares each school only with ITSELF:
* "in years when this school spent more than usual, did it score more
* than usual?" It never compares one school with another.
*
* xtreg ..., fe does this in one command: for each school it subtracts the
* school's own average from every year (as we did by hand for Maple, Oak
* and Pine), then runs OLS on what is left.
xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, fe vce(cluster schid)

****************************************************************************
* TEACHER NOTES
*
* In Papke's published Table 7, the lavgrexpp coefficients are 8.442 (pooled)
* and 7.179 (school FE). Dividing by 10 gives his approximate percentage-point
* change in math pass rate for a 10% spending increase: 0.84 and 0.72.
*
* The bcuse school93_98 classroom file is a close teaching version, not the
* article's exact estimation sample. It has 7,274 complete observations in
* 1,773 schools; Papke reports 7,242 in 1,771 schools. Expect the coefficients
* above to differ slightly. The lesson is what each comparison uses.
****************************************************************************

* Stop recording and save the log file.
log close
