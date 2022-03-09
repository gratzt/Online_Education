cd "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021"

cap log close
log using ".\Logs\ZCTA_Tract_Crosswalk_$S_Date", replace


////////////////////////////////////////////////////////////////////////////////
// This file builds a crosswalk between Zip Code Tabulation areas and
// census tracts. FCC data is at the tract level and will need to be aggregated
// to the zip code level. However, tracts can span multiple zip codes, and zip 
// codes can span multiple tracts. HUD created (see file below) a crosswalk to
// go from zip codes to tracts, but not the other way around. The HUD data 
// contains the proportion of residential addresses from 1 zip code contained 
// in different tracts. Instead to go from tract to zip code, for a given tract,
// we need to calculate the number of people living in different zip codes. Then
// select the zip code - tract combination that has the most number of people 
// living in them.

// ACS Data
// Get the population under 18 by zip code. 
import delimited ".\Data\ACS\nhgis0007_csv\nhgis0007_ds244_20195_2019_zcta.csv", clear

egen child_pop = rowtotal(alt0e003 alt0e004 alt0e005 alt0e006 alt0e027 alt0e028 alt0e029 alt0e030)
keep zcta5a child_pop
tempfile zcta_pops
save `zcta_pops'

// HUD Data
// https://www.huduser.gov/portal/datasets/usps_crosswalk.html
import excel ".\Data\ZIP_TRACT_122020.xlsx", sheet("ZIP_TRACT_122020") firstrow clear
drop BUS_RATIO OTH_RATIO TOT_RATIO
destring ZIP, replace
rename ZIP zcta5a

merge m:1 zcta5a using `zcta_pops' 
keep if _merge == 3 | _merge == 1
drop _merge

gen nchild = RES_RATIO*child_pop

bys TRACT : egen maxpop = max(nchild)
keep if nchild == maxpop

* All duplicates (except 1) are because the RES_RATIO is set to 0. Select the 
* zip code with the most number of children regardless of the residential ratio.

duplicates tag TRACT, gen(look)
bys TRACT : egen mpop = max(child_pop)
drop if child_pop != mpop & look != 0
drop nchild maxpop look mpop RES_RATIO child_pop

save ".\Data\Intermediate\ZCTA_Tract_Crosswalk.dta", replace

log close