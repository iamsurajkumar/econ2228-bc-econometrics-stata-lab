






***** P1: Loading the data and beginning the log


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

* Loading the data
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


***** Regression 1
twoway scatter (math4 lavgrexpp)
twoway (scatter math4 lavgrexpp) (lfit math4 lavgrexpp)
regress math4 lavgrexpp


** Lets Try - Why did it Fail
regress math4 lavgrexpp if year == 1993


regress math4 lavgrexpp if year == 1994
regress math4 lavgrexpp if year == 1995
regress math4 lavgrexpp if year == 1996
regress math4 lavgrexpp if year == 1997
regress math4 lavgrexpp if year == 1998
* What do we find, the effect is very signficant in 1994 but not much there after why?

* Lets add the Fixed Effect
regress math4 lavgrexpp i.year
** Meaning: Differetn schools in the same year

* otherway to add the Fixed effect

** Lets first check the ID of the dataset
isid schid year
xtset schid year
xtreg math4 lavgrexpp, fe
** each school with itself in other years
ssc install ftools, replace
ssc install reghdfe, replace
ssc install require, replace

** Another way to compare the Fixed effect, Schools Across Different Years

** same year ==> Different Schools
reghdfe math4 lavgrexpp, absorb(year)

** same school ==> Different years
reghdfe math4 lavgrexpp, absorb(schid)

** why so different

** same school and same year
reghdfe math4 lavgrexpp, absorb(schid year)


** Now lets add other characterictis of the school and year
reghdfe math4 lavgrexpp lenrol, absorb(schid year)

reghdfe math4 lavgrexpp lunch, absorb(schid year)



* lunch2 = free-lunch percent, squared.
generate lunch2 = lunch^2

* Describe the new variable.
label variable lunch2  "Free lunch (%), squared"

* lenrol2 = log enrollment, squared.
generate lenrol2 = lenrol^2

* Describe the new variable.
label variable lenrol2 "Log enrollment, squared"


reghdfe math4 lavgrexpp lunch lenrol, absorb(schid year)

reghdfe math4 lavgrexpp lunch lenrol lunch2 lenrol2, absorb(schid year)


** Allowing for errors to be clustred around school
reghdfe math4 lavgrexpp lunch lenrol lunch2 lenrol2, absorb(schid year) vce (clustre schid)

xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, fe vce(cluster schid)


reghdfe math4 lavgrexpp lunch lenrol lunch2 lenrol2


