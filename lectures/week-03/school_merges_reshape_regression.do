*****************************************************************************
* WEEK 3: ONE APPEND, ONE MERGE, TWO REGRESSIONS, AND ONE RESHAPE
*
* DATA FLOW
*
* school_year_main.dta
*       |---> school_1993_1995.dta ---\
*       |                               APPEND ---> school_year.dta
*       |---> school_1996_1998.dta ---/
*       |
*       |---> school_profile.dta (school-to-district lookup)
*                                         |
* school_year.dta + school_profile.dta --- MERGE ---> school_year_merged.dta
*                                                        |
*                                             TABLE 7 COLUMNS 1 AND 2
*                                                        |
*                                                     RESHAPE
*                                                        |
*                                              school_year_wide.dta
*
* HOW TO USE THIS FILE IN CLASS
* Select one Stata command at a time and run it from the Do-file Editor.
* Run the numbered steps in order because each step creates a file used later.
* Every executable command is on one line so students can run it separately.
*****************************************************************************

* Remove all data and stored results from Stata's memory.
clear all

* Prevent Stata from pausing when it produces long output.
set more off

* Close an old log if one is already open.
capture log close

* Record all commands and results in a text log.
log using "lectures/week-03/school_merges_reshape_regression.log", replace text

* Create a separate output folder for the simplified lesson.
capture mkdir "lectures/week-03/teaching-data-simple"

*****************************************************************************
* STEP 1: CREATE AND SAVE THE MAIN SCHOOL-YEAR DATASET
*****************************************************************************

* Download the original Wooldridge school-year dataset.
bcuse school93_98, clear

* Keep only the identifiers and variables needed for the lesson.
keep distid schid year lunch enrol math4 rexpp lenrol lavgrexpp

* Describe what one row in the main dataset represents.
label data "Main Michigan school-year dataset, 1993-1998"

* Explain the district identifier.
label variable distid "School district identifier"

* Explain the school identifier.
label variable schid "School identifier"

* Explain that 1993 refers to the 1992/93 school year.
label variable year "Ending year of school year (1993 = 1992/93)"

* Explain the poverty proxy and its unit.
label variable lunch "Students eligible for free/reduced lunch (%)"

* Explain the enrollment variable.
label variable enrol "Number of students enrolled"

* Explain the outcome and its unit.
label variable math4 "Fourth-grade students passing math test (%)"

* Explain the real-spending variable and its price year.
label variable rexpp "Real expenditure per pupil (1997 dollars)"

* Explain the transformed enrollment variable.
label variable lenrol "Log of school enrollment"

* Explain Papke's current-and-prior-year spending variable.
label variable lavgrexpp "Log average real spending: current and prior year"

* Verify that each school-year combination appears only once.
isid schid year

* Save the main dataset to disk; no temporary file is used.
save "lectures/week-03/teaching-data-simple/school_year_main.dta", replace

*****************************************************************************
* STEP 2: CREATE ONE SCHOOL PROFILE FOR THE LATER MERGE
*****************************************************************************

* Open the saved main dataset.
use "lectures/week-03/teaching-data-simple/school_year_main.dta", clear

* Keep 1993 so that the profile contains one row per school.
keep if year == 1993

* Keep only the school key and its district membership.
keep schid distid

* Describe what one row in the school profile represents.
label data "School profile: one district identifier for each school"

* Label the unique school key.
label variable schid "School identifier"

* Label the district to which the school belongs.
label variable distid "School district identifier"

* Verify that the school key is unique in the profile.
isid schid

* Save the one-row-per-school profile used by the merge.
save "lectures/week-03/teaching-data-simple/school_profile.dta", replace

*****************************************************************************
* STEP 3: SPLIT THE MAIN DATASET INTO TWO TIME BLOCKS
*****************************************************************************

* Reopen the main school-year dataset.
use "lectures/week-03/teaching-data-simple/school_year_main.dta", clear

* Remove profile variables so that the later merge visibly restores them.
drop distid

* Keep the first three years.
keep if inrange(year, 1993, 1995)

* Describe the observations in the early-period file.
label data "Michigan school-year observations, 1993-1995"

* Verify the school-year key before saving.
isid schid year

* Save the early-period observations.
save "lectures/week-03/teaching-data-simple/school_1993_1995.dta", replace

* Reopen the main school-year dataset again.
use "lectures/week-03/teaching-data-simple/school_year_main.dta", clear

* Remove profile variables so that the later merge visibly restores them.
drop distid

* Keep the final three years.
keep if inrange(year, 1996, 1998)

* Describe the observations in the late-period file.
label data "Michigan school-year observations, 1996-1998"

* Verify the school-year key before saving.
isid schid year

* Save the late-period observations.
save "lectures/week-03/teaching-data-simple/school_1996_1998.dta", replace

*****************************************************************************
* STEP 4: USE ONE APPEND TO RECONSTRUCT THE SCHOOL-YEAR PANEL
*****************************************************************************

* Open the early-period observations as the starting dataset.
use "lectures/week-03/teaching-data-simple/school_1993_1995.dta", clear

* Stack the late-period observations below the early observations.
append using "lectures/week-03/teaching-data-simple/school_1996_1998.dta"

* Describe the dataset reconstructed by the append.
label data "School-year panel reconstructed with one append"

* Confirm that every school-year combination remains unique.
isid schid year

* Count the observations reconstructed by the append.
count

* Stop with an error if the append did not recover all source rows.
assert r(N) == 10668

* Save the reconstructed school-year dataset.
save "lectures/week-03/teaching-data-simple/school_year.dta", replace

*****************************************************************************
* STEP 5: USE ONE m:1 MERGE TO ADD THE SCHOOL PROFILE
*****************************************************************************

* Open the reconstructed panel, which has many years for each school.
use "lectures/week-03/teaching-data-simple/school_year.dta", clear

* Match the many school-year rows to one profile row for each school.
merge m:1 schid using "lectures/week-03/teaching-data-simple/school_profile.dta"

* Display how many observations matched or failed to match.
tabulate _merge

* Stop with an error unless every school-year observation matched.
assert _merge == 3

* Remove the merge-status variable after validating the merge.
drop _merge

* Describe the reconstructed and enriched school-year panel.
label data "School-year panel merged with school profile"

* Confirm that the merge did not duplicate school-year observations.
isid schid year

* Save the merged panel that will be used for the regressions.
save "lectures/week-03/teaching-data-simple/school_year_merged.dta", replace

*****************************************************************************
* STEP 6: ESTIMATE PAPKE TABLE 7, COLUMNS 1 AND 2
*****************************************************************************

* WHY RUN POOLED OLS?
* Pooled OLS places every available school-year observation in one regression.
* It asks whether observations with higher spending also tend to have higher
* math pass rates, after accounting for poverty, enrollment, and common year
* effects. It uses two kinds of comparisons at the same time:
*   1. comparisons between different schools; and
*   2. comparisons within the same school in different years.
* A limitation is that high- and low-spending schools may differ in lasting
* ways that we cannot observe, such as neighborhood history or school culture.

* WHY RUN SCHOOL FIXED EFFECTS?
* Fixed effects gives every school its own starting level. A simple way to
* explain this is: "compare each school with itself." The regression asks:
* when spending at the same school rises or falls, does its math pass rate also
* rise or fall? Lasting school characteristics are removed because they do not
* change from year to year. Fixed effects cannot remove omitted factors that
* do change over time, so this alone does not prove that spending causes scores.

* WHY INCLUDE YEAR INDICATORS?
* Year indicators absorb statewide changes affecting all schools in a year,
* such as a test becoming easier or harder or a statewide policy change.

* WHY CLUSTER STANDARD ERRORS BY SCHOOL?
* Repeated observations from the same school are likely related. Clustering
* allows errors for one school to be correlated across its different years.

* Declare that observations are organized by school and year.
xtset schid year

* Create the squared lunch variable reported in Table 7.
generate lunch2 = lunch^2

* Explain the squared poverty control.
label variable lunch2 "Squared free/reduced lunch eligibility"

* Create the squared log-enrollment variable reported in Table 7.
generate lenrol2 = lenrol^2

* Explain the squared school-size control.
label variable lenrol2 "Squared log school enrollment"

* Remove any estimates left in memory from an earlier Stata session.
eststo clear

* Estimate Table 7 column 1: pooled OLS with year indicators.
eststo pooled: regress math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, vce(cluster schid)

* Estimate Table 7 column 2: school fixed effects with year indicators.
eststo fixed: xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, fe vce(cluster schid)

* Display only the two requested regression columns in the Stata log.
esttab pooled fixed, keep(lavgrexpp lunch lunch2 lenrol lenrol2) mtitles("Pooled OLS" "School fixed effects") b(3) se(3) nostar stats(N, labels("Observations"))

* Export the same two regression columns to an easily viewed HTML table.
esttab pooled fixed using "lectures/week-03/table7_after_data_management.html", replace html keep(lavgrexpp lunch lunch2 lenrol lenrol2) mtitles("Pooled OLS" "School fixed effects") b(3) se(3) nostar stats(N, labels("Observations")) title("Papke Table 7 after append and merge") note("School-clustered standard errors. Year indicators included but not shown.")

*****************************************************************************
* STEP 7: PERFORM ONE FINAL RESHAPE FROM LONG TO WIDE
*****************************************************************************

* Keep a small set of variables so the reshape is easy to understand.
keep distid schid year math4 rexpp

* Confirm the long-data school-year key before reshaping.
isid schid year

* Put each year's math score and real spending into separate columns.
reshape wide math4 rexpp, i(schid) j(year)

* Describe the final one-row-per-school dataset.
label data "Wide school dataset created after the Table 7 regressions"

* Label the 1993 math outcome and its percentage unit.
label variable math41993 "Fourth-grade math pass rate in 1993 (%)"

* Label the 1994 math outcome and its percentage unit.
label variable math41994 "Fourth-grade math pass rate in 1994 (%)"

* Label the 1995 math outcome and its percentage unit.
label variable math41995 "Fourth-grade math pass rate in 1995 (%)"

* Label the 1996 math outcome and its percentage unit.
label variable math41996 "Fourth-grade math pass rate in 1996 (%)"

* Label the 1997 math outcome and its percentage unit.
label variable math41997 "Fourth-grade math pass rate in 1997 (%)"

* Label the 1998 math outcome and its percentage unit.
label variable math41998 "Fourth-grade math pass rate in 1998 (%)"

* Label real spending in 1993 and state the price year.
label variable rexpp1993 "Real expenditure per pupil in 1993 (1997 dollars)"

* Label real spending in 1994 and state the price year.
label variable rexpp1994 "Real expenditure per pupil in 1994 (1997 dollars)"

* Label real spending in 1995 and state the price year.
label variable rexpp1995 "Real expenditure per pupil in 1995 (1997 dollars)"

* Label real spending in 1996 and state the price year.
label variable rexpp1996 "Real expenditure per pupil in 1996 (1997 dollars)"

* Label real spending in 1997 and state the price year.
label variable rexpp1997 "Real expenditure per pupil in 1997 (1997 dollars)"

* Label real spending in 1998 and state the price year.
label variable rexpp1998 "Real expenditure per pupil in 1998 (1997 dollars)"

* Verify that the reshaped dataset contains one row per school.
isid schid

* Save the final wide teaching dataset.
save "lectures/week-03/teaching-data-simple/school_year_wide.dta", replace

* Close and save the lesson log.
log close
