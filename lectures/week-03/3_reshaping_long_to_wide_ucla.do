*****************************************************************************
* Week 3: Reshaping data from long to wide
* Based on: https://stats.oarc.ucla.edu/stata/modules/reshaping-data-long-to-wide/
*****************************************************************************

* Remove data and stored results left from an earlier Stata session.
clear all

* Run the whole do-file without pausing the Results window.
set more off

*****************************************************************************
* How to read the reshape wide syntax
*****************************************************************************

* General syntax:
*
* reshape wide stubname(s), i(id_variable(s)) j(suffix_variable) [string]
*
* reshape wide
*     tells Stata to change data from LONG form to WIDE form.
*
* stubname(s)
*     are the long variables whose values will be spread across new columns.
*     For example, age becomes age1, age2, and age3. More than one variable
*     may be listed, as in: reshape wide kidname age wt sex, ...
*
* i(id_variable(s))
*     gives the variable or variables that should uniquely identify one row
*     in the RESULTING WIDE data. Their values remain as ordinary columns.
*
* j(suffix_variable)
*     identifies the existing long-data variable whose values become suffixes
*     on the new wide variable names. If birth is 1, 2, or 3, age becomes
*     age1, age2, and age3.
*
* string
*     is added only when j() contains text values. If dadmom contains dad and
*     mom, the string option allows name to become namedad and namemom.
*
* Before reshape wide, i() and j() together must uniquely identify each row:
*     isid id_variable(s) suffix_variable
* If two rows have the same i() and j() values, Stata cannot decide which
* value belongs in the corresponding wide cell and stops with an error.
*
* Example:
*     reshape wide age, i(famid) j(birth)
* Meaning:
*     Create one row per famid and spread age into age1, age2, and age3 using
*     the values 1, 2, and 3 found in birth as the variable-name suffixes.

*****************************************************************************
* Example 1: Reshape one variable
*****************************************************************************

* Enter the UCLA data in long form: each row represents one child.
* famid identifies the family and birth gives the child's birth order.
input famid birth age
1 1 9
1 2 6
1 3 3
2 1 8
2 2 6
2 3 2
3 1 6
3 2 4
3 3 2
end

* Arrange children by family and birth order to make the long structure clear.
sort famid birth

* Display the long data with a visual separator between families.
list, sepby(famid)

* Make one row per family. The values of birth become suffixes, so the single
* age column becomes age1, age2, and age3.
reshape wide age, i(famid) j(birth)

* Display the resulting family-level wide data.
list

* Confirm that famid alone now uniquely identifies each wide observation.
isid famid

* Three families should produce exactly three wide rows.
assert _N == 3

*****************************************************************************
* Example 2: Reshape more than one variable
*****************************************************************************

* Remove Example 1 from memory before entering the full children dataset.
clear

* Enter four child characteristics. str4 and str1 indicate text variables.
input famid str4 kidname birth age wt str1 sex
1 "Beth" 1 9 60 "f"
1 "Bob"  2 6 40 "m"
1 "Barb" 3 3 20 "f"
2 "Andy" 1 8 80 "m"
2 "Al"   2 6 50 "m"
2 "Ann"  3 2 20 "f"
3 "Pete" 1 6 60 "m"
3 "Pam"  2 4 40 "f"
3 "Phil" 3 2 20 "m"
end

* Put children in birth order within each family.
sort famid birth

* Confirm that family and birth order uniquely identify every child row.
isid famid birth

* Display the original long dataset before reshaping it.
list, sepby(famid)

* Reshape all four characteristics together. Each variable will receive the
* birth-order suffixes 1, 2, and 3.
reshape wide kidname age wt sex, i(famid) j(birth)

* Display the new family-level columns, such as age1, age2, and age3.
list

* Check that one family ID now identifies each row.
isid famid

* Verify that the nine child rows collapsed into three family rows.
assert _N == 3

*****************************************************************************
* Example 3: Character suffixes
*****************************************************************************

* Remove the children data before entering the parents example.
clear

* Enter one row per parent. dadmom contains text values used as suffixes.
input famid str4 name inc str3 dadmom
2 "Art"  22000 "dad"
1 "Bill" 30000 "dad"
3 "Paul" 25000 "dad"
1 "Bess" 15000 "mom"
3 "Pat"  50000 "mom"
2 "Amy"  18000 "mom"
end

* Group the dad and mom rows within each family.
sort famid dadmom

* Confirm that family and parent type form a unique key in long form.
isid famid dadmom

* Display the one-parent-per-row structure before reshaping.
list, sepby(famid)

* Make one row per family. The string option allows the text values dad and
* mom to become suffixes in namedad, namemom, incdad, and incmom.
reshape wide name inc, i(famid) j(dadmom) string

* Display the resulting one-family-per-row dataset.
list

* Verify that famid uniquely identifies every wide row.
isid famid

* Confirm that six parent rows became three family rows.
assert _N == 3
