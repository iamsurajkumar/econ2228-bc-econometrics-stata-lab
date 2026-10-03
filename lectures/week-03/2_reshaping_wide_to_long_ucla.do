*****************************************************************************
* Week 3: Reshaping data from wide to long
* Based on: https://stats.oarc.ucla.edu/stata/modules/reshaping-data-wide-to-long/
* Assisted by: Open AI - GPT 5.6 Sol
*****************************************************************************

* Remove data and stored results left from an earlier Stata session.
clear all

* Run the whole do-file without pausing the Results window.
set more off

*****************************************************************************
* How to read the reshape long syntax
*****************************************************************************

* General syntax:
*
* reshape long stubname(s), i(id_variable(s)) j(suffix_variable) [string]
*
* reshape long
*     tells Stata to change data from WIDE form to LONG form.
*
* stubname(s)
*     are the shared beginnings, or stems, of the wide variable names.
*     For example, faminc96 faminc97 faminc98 share the stem faminc.
*     More than one stem may be listed, as in: reshape long ht wt, ...
*
* i(id_variable(s))
*     gives the variable or variables that uniquely identify one row in the
*     ORIGINAL WIDE data. Before reshaping, isid id_variable(s) should work.
*     The values in i() are repeated across the new long observations.
*
* j(suffix_variable)
*     names the new variable that receives the suffixes taken from the wide
*     variable names. For faminc96-faminc98, j(year) creates year=96,97,98.
*
* string
*     is added only when the suffixes contain text rather than numbers.
*     For example, named and namem require j(dadmom) string.
*
* After reshape long, i() together with j() should normally be the new key:
*     isid id_variable(s) suffix_variable
*
* Example:
*     reshape long faminc, i(famid) j(year)
* Meaning:
*     Stack faminc96-faminc98 into one variable named faminc, repeat famid
*     for each new row, and store 96, 97, and 98 in a new variable named year.

*****************************************************************************
* Example 1: One variable stem and numeric suffixes
*****************************************************************************

* Enter one row per family, with a separate income variable for each year.
* The shared stem is faminc; the numeric suffixes are 96, 97, and 98.
clear 
input famid faminc96 faminc97 faminc98
3 75000 76000 77000
1 40000 40500 41000
2 45000 45400 45800
end

* Put families in numerical order so the before-and-after output is easy to read.
sort famid

* Confirm that one variable, famid, uniquely identifies every wide row.
isid famid

* Display the original wide data before changing its shape.
list

* Stack faminc96-faminc98 into one faminc column. i() identifies families,
* while j() creates year from the old variable-name suffixes.
reshape long faminc, i(famid) j(year)

// * Purposefull Messed Up Example 
// * but suppose if we have messed up then 
// reshape long faminc, i(year) j(famid)
// * why do you get an error with yeear what's wrong?


* Now what is the id of this dataset?
* After reshaping, family and year together must identify each observation.
isid famid year

* Sort by the new two-variable key so years appear in order within each family.
sort famid year

* Display the long data and visually separate one family from the next.
list, sepby(famid)

* The 3 families and 3 years should produce 9 observations.
* Stop with an error if the reshape did not produce the expected row count.
assert _N == 9

* Check that year contains exactly the suffix values used in the wide data.
assert inlist(year, 96, 97, 98)

*****************************************************************************
* Example 2: More than one identifying variable
*****************************************************************************

* Remove Example 1 from memory before entering the next dataset.
clear

* Enter height and weight measured at ages 1 and 2. A child is identified by
* the combination of family ID and birth order. ht1 denotes the height at age 1 and ht2 denotes the height at age2. And similarly the birth weight
input famid birth ht1 ht2 wt1 wt2
1 1 2.8 3.4 19 28
1 2 2.9 3.8 21 28
1 3 2.2 2.9 20 23
2 1 2.0 3.2 25 30
2 2 1.8 2.8 20 33
2 3 1.9 2.4 22 33
3 1 2.2 3.3 22 28
3 2 2.3 3.4 20 30
3 3 2.1 2.9 22 31
end

* Save the original wide data because Example 3 will reuse all its variables.
save kids_wide.dta, replace

* Show only the ID variables and the two height columns used in this example.
list famid birth ht1 ht2

* Stack ht1 and ht2 into ht. Because famid alone repeats, i() needs both
* famid and birth; j() stores the age suffix 1 or 2.
reshape long ht, i(famid birth) j(age)


* Did you notice something funny with wt1 and wt2 columns now, 
* don't worry, we will fix it later in example 3

* Put the two ages beside each other within each child.
sort famid birth age

* Verify that family, birth order, and age form the new unique key.
isid famid birth age

* Display the variables that make the change in structure clearest.
list famid birth age ht, sepby(famid birth)

* Nine children observed at two ages should produce 18 rows.
assert _N == 18

*****************************************************************************
* Example 3: More than one variable stem
*****************************************************************************

* Reshape height and weight at the same time.
* Reload the untouched wide data saved before Example 2.
use kids_wide.dta, clear

* Display both pairs of repeated-measure variables before reshaping.
list famid birth ht1 ht2 wt1 wt2

* List both stems so height and weight are stacked in a single operation.
reshape long ht wt, i(famid birth) j(age)

* Arrange observations by the full long-data key.
sort famid birth age

* Confirm that the key still uniquely identifies every child-age row.
isid famid birth age

* Display the paired height and weight measurement at each age.
list famid birth age ht wt, sepby(famid birth)

* Nine children observed twice should again produce 18 rows.
assert _N == 18

*****************************************************************************
* Example 4: Character suffixes
*****************************************************************************

* Remove the children data before entering a different example.
clear

* Enter one family per row. The suffixes d and m identify dads and moms.
input famid str4 named incd str4 namem incm
1 "Bill" 30000 "Bess" 15000
2 "Art"  22000 "Amy"  18000
3 "Paul" 25000 "Pat"  50000
end

* Here named means dad name, namem means mom name, and similarly incd means dad income, and incm means mom income. 

* Display the wide data with separate name and income columns for each parent.
list

* Stack both name and income. The string option is required because the
* suffixes d and m are letters rather than numbers.
reshape long name inc, i(famid) j(dadmom) string

* Place dad and mom next to each other within family.
sort famid dadmom

* Verify that family ID and parent type uniquely identify each long row.
isid famid dadmom

* Display the resulting one-parent-per-row data.
list, sepby(famid)

* Three families with two parents each should produce six rows.
assert _N == 6
