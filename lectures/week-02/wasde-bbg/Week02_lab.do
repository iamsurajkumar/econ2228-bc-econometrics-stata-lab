* =====================================================================
*  ECON 2228 - Econometrics Stata Lab
*  Week 2: Do-files, log files, data structures & joins
*
*  Author:  <your name here>
*  Section: <your section here>
*
*  HOW TO USE THIS FILE
*  --------------------
*  This is a "do-file": a script of Stata commands that run in order.
*  You can run the whole file at once, or highlight a line (or several
*  lines) and press the "Execute (do)" button to run just that part.
*
*  IMPORTANT: set your working directory BEFORE opening the log file,
*  so the log (and any saved data) land in the right folder.
* =====================================================================


/*-------------- (1) Initial commands --------------------*/

* Change to your working directory (create the folder first if needed).
* On the Apps server this is usually your Google Drive Stata folder.
*   global wd "D:\PhotonUser\My Files\Google Drive\My Drive\AppStreamFiles\Stata"
*   cd "$wd"
*   mkdir Week02
*   cd Week02

* Clear everything in memory (good practice at the start of a session)
clear all

* Don't pause for --more-- (useful with large datasets)
set more off

* Close any log file that may still be open from a previous session.
* "capture" suppresses the error if no log is open.
capture log close

* Open a log file. "text" gives a plain .log file (recommended);
* "replace" overwrites any existing file with the same name.
log using "Week2", text replace


/*------------- (2) Do-files & commenting -----------------*/

* A do-file is just a text file of commands. Comments keep it readable:
*   *        comments out a whole line
*   /* */    comments out a block (can span several lines)
*   //       comments out the rest of a line

* Example: load the Affairs data and describe it
bcuse affairs, clear
describe
correlate naffairs ratemarr


/*------------- (3) Descriptive statistics with if ---------*/

* Load the classic 1978 automobile data
sysuse auto, clear

* Detailed summary of price (adds median, percentiles, skewness, kurtosis)
summarize price, detail

* Domestic cars that cost more than 5000 dollars (AND: &)
summarize price if foreign==0 & price>5000

* Cars that are domestic OR cost more than 5000 dollars (OR: |)
summarize price if foreign==0 | price>5000

* Domestic OR price in the 5k-7k range
summarize price if foreign==0 | inrange(price, 5000, 7000)

* Table of summary statistics (whole sample, then a subsample)
tabstat price foreign mpg, stats(mean sd median var range)
tabstat price foreign mpg if price>5000, stats(mean sd median var range)

* Frequency distribution of origin
tabulate foreign

* Mileage by origin (two-way table)
tabulate mpg foreign

* Pairwise correlation between price and mpg
correlate price mpg


/*------------- (4) Data structures ------------------------*/

* 1. CROSS-SECTIONAL: many units, one point in time
bcuse wine, clear
describe, short
list in 1/6

* 2. TIME SERIES: one unit, many points in time
bcuse consump, clear
describe, short
list year rdisp rcons in 1/6

* 3. PANEL: many units, many points in time
bcuse cornwell, clear
describe, short
list county year crmrte in 1/6


/*------------- (5) Joins with merge -----------------------*/

* A join combines two datasets on a common key variable (here, id).
* The keep() option decides which rows survive:
*   keep(match)                 -> INNER join (rows in BOTH files)
*   keep(master match)          -> LEFT  join (all master rows)
*   keep(using match)           -> RIGHT join (all using rows)
*   keep(master using match)    -> OUTER join (all rows from either)

* Build a small master file: id and name
clear all
input id str10 name
1 "Alice"
2 "Bob"
3 "Carol"
4 "Dave"
end
save "join_master", replace

* Build a small using file: id and score
clear all
input id score
1 85
3 92
4 78
5 99
end
save "join_using", replace

* INNER JOIN: keep only ids in both files (1, 3, 4)
use "join_master", clear
merge 1:1 id using "join_using", keep(match) nogen
list

* LEFT JOIN: keep every master row (1, 2, 3, 4); Bob's score is missing
use "join_master", clear
merge 1:1 id using "join_using", keep(master match) nogen
list

* RIGHT JOIN: keep every using row (1, 3, 4, 5); id 5 has no name
use "join_master", clear
merge 1:1 id using "join_using", keep(using match) nogen
list

* OUTER JOIN: keep every row from either file (1, 2, 3, 4, 5)
use "join_master", clear
merge 1:1 id using "join_using", keep(master using match) nogen
list


/*------------- (6) Class assignment -----------------------*/

* Load the wage1 dataset and answer:
*   1. What is the median value of 'educ'? Which command?
*   2. What is the correlation between 'educ' and 'exper'? Which command?
* Generate a log file and upload it to Canvas.

bcuse wage1, clear

* 1. Median of educ (look at the 50th percentile)
summarize educ, detail

* 2. Correlation between educ and exper
correlate educ exper


/*------------- (7) Save your work and close the log -------*/

* Save the dataset (only if you changed it and want to keep the changes)
* save "Lab2", replace

* Close the log file
log close

* Exit Stata (optional)
* exit, clear