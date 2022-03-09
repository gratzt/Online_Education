cap log close
cd "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021"
log using ".\Logs\CleanSeda", replace

////////////////////////////////////////////////////////////////////////////////
// Will need the zip code to school district crosswalk so that the output
// is compatible for merging to the analytic dataset.
use ".\Data\Intermediate\SD_Zip_Crosswalk.dta", clear
keep GEOID NAME ZCTA5CE10 NAME
destring GEOID, replace
rename GEOID sedalea
tempfile crosswalk
save `crosswalk'

///////////////////////////////////////////////////////////////////////////////
// Black Students
use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\seda_geodist_long_cs_4.0.dta", clear
drop if inlist(stateabb, "PR")
drop if cs_mn_blk == .

* Select most recent year of data before the start of the the study for each school district.
drop if year > 2016
bys sedalea : egen myear = max(year)
keep if myear == year

keep sedalea sedaleaname stateabb subject grade year cs_mn_blk cs_mnse_blk totgyb_blk 
collapse (firstnm) year sedaleaname stateabb (mean) cs_mn_blk cs_mnse_blk [aweight=totgyb_blk], by(sedalea subject)
reshape wide cs_mn_blk cs_mnse_blk, i(sedalea) j(subject) string

merge 1:m sedalea using `crosswalk'
keep if _merge == 2 | _merge == 3
drop _merge

rename (ZCTA5CE10 sedalea) (Zip_Code nearby_district) 
destring Zip_Code, replace

keep Zip_Code cs_mn_blkmth cs_mnse_blkmth cs_mn_blkrla cs_mnse_blkrla
tempfile black
save `black'

///////////////////////////////////////////////////////////////////////////////
// Hispanic Students
use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\seda_geodist_long_cs_4.0.dta", clear
drop if inlist(stateabb, "PR")
drop if cs_mn_hsp == .

* Select most recent year of data before the start of the the study for each school district.
drop if year > 2016
bys sedalea : egen myear = max(year)
keep if myear == year

keep sedalea sedaleaname stateabb subject grade year cs_mn_hsp cs_mnse_hsp totgyb_hsp 
collapse (firstnm) year sedaleaname stateabb (mean) cs_mn_hsp cs_mnse_hsp [aweight=totgyb_hsp], by(sedalea subject)
reshape wide cs_mn_hsp cs_mnse_hsp, i(sedalea) j(subject) string

merge 1:m sedalea using `crosswalk'
keep if _merge == 2 | _merge == 3
drop _merge

rename (ZCTA5CE10 sedalea) (Zip_Code nearby_district) 
destring Zip_Code, replace

keep Zip_Code cs_mn_hspmth cs_mnse_hspmth cs_mn_hsprla cs_mnse_hsprla
tempfile hisp
save `hisp'

///////////////////////////////////////////////////////////////////////////////
// White Students
use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\seda_geodist_long_cs_4.0.dta", clear
drop if inlist(stateabb, "PR")
drop if cs_mn_wht == .

* Select most recent year of data before the start of the the study for each school district.
drop if year > 2016
bys sedalea : egen myear = max(year)
keep if myear == year

keep sedalea sedaleaname stateabb subject grade year cs_mn_wht cs_mnse_wht totgyb_wht 
collapse (firstnm) year sedaleaname stateabb (mean) cs_mn_wht cs_mnse_wht [aweight=totgyb_wht], by(sedalea subject)
reshape wide cs_mn_wht cs_mnse_wht, i(sedalea) j(subject) string

merge 1:m sedalea using `crosswalk'
keep if _merge == 2 | _merge == 3
drop _merge

rename (ZCTA5CE10 sedalea) (Zip_Code nearby_district) 
destring Zip_Code, replace

keep Zip_Code cs_mn_whtmth cs_mnse_whtmth cs_mn_whtrla cs_mnse_whtrla
tempfile white
save `white'

///////////////////////////////////////////////////////////////////////////////
// All Students
use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\seda_geodist_long_cs_4.0.dta", clear
drop if inlist(stateabb, "PR")
drop if cs_mn_all == .

* Select most recent year of data before the start of the the study for each school district.
drop if year > 2016
bys sedalea : egen myear = max(year)
keep if myear == year

keep sedalea sedaleaname stateabb subject grade year cs_mn_all cs_mnse_all totgyb_all cs_mn_blk cs_mn_hsp cs_mn_wht
collapse (firstnm) year sedaleaname stateabb (mean) cs_mn_all cs_mnse_all [aweight=totgyb_all], by(sedalea subject)
reshape wide cs_mn_all cs_mnse_all, i(sedalea) j(subject) string

merge 1:m sedalea using `crosswalk'
keep if _merge == 3
drop _merge

rename (ZCTA5CE10 sedalea) (Zip_Code nearby_district) 
destring Zip_Code, replace

keep Zip_Code cs_mn_allmth cs_mnse_allmth cs_mn_allrla cs_mnse_allrla

merge 1:1 Zip_Code using `black'
keep if _merge == 1 | _merge == 3
drop _merge 

merge 1:1 Zip_Code using `hisp'
keep if _merge == 1 | _merge == 3
drop _merge 

merge 1:1 Zip_Code using `white'
keep if _merge == 1 | _merge == 3
drop _merge 

save ".\Data\Intermediate\cleanedSeda.dta", replace

cap log close