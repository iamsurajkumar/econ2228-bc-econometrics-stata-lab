*****************************************************************************
* Week 3: Combining data in Stata
* Based on: https://stats.oarc.ucla.edu/stata/modules/combining-data/
*****************************************************************************
* Remove any data and stored results left from an earlier Stata session.
clear all

* Let the do-file run to the end without pausing the Results window.
set more off

*****************************************************************************
* Create the four small data files used in the examples
*****************************************************************************
clear
* Type the dads data directly into Stata. str4 allows names up to 4 characters.
input famid str4 name inc
2 "Art"  22000
1 "Bill" 30000
3 "Paul" 25000
end

* Record which parent file each observation came from before appending.
generate str3 parent = "dad"

* Save the dads data so another dataset can later be appended or merged with it.
* replace makes the do-file safe to run again when dads.dta already exists.
save dads.dta, replace

* Empty memory before typing a different dataset.
clear

* Create the corresponding moms data with the same variable names and types.
input famid str4 name inc
1 "Bess" 15000
3 "Pat"  50000
2 "Amy"  18000
end

* Give every observation in this file the source label "mom".
generate str3 parent = "mom"

* Save the moms data for the append example below.
save moms.dta, replace

* Empty memory before creating the family-income file.
clear

* Create one family-income row per family; famid will be the merge key.
input famid faminc96 faminc97 faminc98
3 75000 76000 77000
1 40000 40500 41000
2 45000 45400 45800
end

* Save the family-income data for the one-to-one merge.
save faminc.dta, replace

* Empty memory before creating the children file.
clear

* Create several child rows per family for the one-to-many merge.
* str4 and str1 tell Stata that kidname and sex contain text.
input famid str4 kidname birth age wt str1 sex
1 "Beth" 1 9 60 "f"
2 "Andy" 1 8 40 "m"
3 "Pete" 1 6 20 "f"
1 "Bob"  2 6 80 "m"
1 "Barb" 3 3 50 "m"
2 "Al"   2 6 20 "f"
2 "Ann"  3 2 60 "m"
3 "Pam"  2 4 40 "f"
3 "Phil" 3 2 20 "m"
end

* Save the children data for the one-to-many merge.
save kids.dta, replace

*****************************************************************************
* 1. Append: stack observations from two files
*****************************************************************************

* Load dads as the starting, or master, dataset; clear replaces data in memory.
use dads.dta, clear



* Before merging if the mom dataset is also very similar to 
desc 
desc using moms.dta

* Stack the moms rows underneath the dads rows because both files share columns.
append using moms.dta

* Arrange dads and moms together within family so the result is easy to inspect.
sort famid parent

* Display the appended data, drawing a separator between families.
list, sepby(famid)

*****************************************************************************
* 2. One-to-one merge: add family income to each dad
*****************************************************************************

* Reload dads because the append example changed the data currently in memory.
use dads.dta, clear

* Desc the faminc.dta before merging to check it contains unique family ID
desc using faminc.dta

* Match exactly one dad row to one income row using the unique family ID.
merge 1:1 famid using faminc.dta

* Put families in numerical order for readable output.
sort famid

* Display the variables brought together by the merge.
list

* Summarize _merge: 1=master only, 2=using only, and 3=matched in both.
tabulate _merge

*****************************************************************************
* 3. One-to-many merge: match several children to each dad
*****************************************************************************

* Start again from the dads file, which has one observation per family.
use dads.dta, clear
desc
desc using kids.dta

// // // * Lets look at Kids.dta again
// use kids.dta, clear


* Match each one dad row to the many child rows that share its famid.
merge 1:m famid using kids.dta


use kids.dta, clear
merge m:1 famid using dads.dta

* Order children first by family and then by birth order.
sort famid birth

* Show only the most useful variables and separate the families visually.
list famid name kidname birth age _merge, sepby(famid)

* Check whether all children and dads matched as expected.
tabulate _merge
