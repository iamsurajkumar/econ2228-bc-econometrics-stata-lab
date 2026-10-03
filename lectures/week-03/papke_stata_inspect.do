clear all
set more off

capture log close
log using "lectures/week-03/papke_stata_inspect.log", replace text

* Load Papke's school panel and declare the panel structure.
bcuse school93_98, clear
xtset schid year

* Controls used in columns (1) and (2) of Table 7.
generate lunch2  = lunch^2
generate lenrol2 = lenrol^2

* Estimate one pooled OLS model and one school fixed-effects model.
eststo clear
eststo pooled: regress math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, ///
    vce(cluster schid)
eststo fixed: xtreg math4 lavgrexpp lunch lunch2 lenrol lenrol2 i.year, ///
    fe vce(cluster schid)

* Display the two regressions in the log.
esttab pooled fixed, ///
    keep(lavgrexpp lunch lunch2 lenrol lenrol2) ///
    mtitles("Pooled OLS" "Fixed Effects") ///
    b(3) se(3) nostar stats(N, labels("Observations"))

* Export the same two-column table as HTML.
esttab pooled fixed using "lectures/week-03/table7_cols1_2_comparison.html", ///
    replace html ///
    keep(lavgrexpp lunch lunch2 lenrol lenrol2) ///
    mtitles("Pooled OLS" "Fixed Effects") ///
    b(3) se(3) nostar ///
    stats(N, labels("Observations")) ///
    title("Papke Table 7: Pooled OLS and Fixed Effects") ///
    note("School-clustered standard errors in parentheses. Year indicators included but not shown.")

log close
