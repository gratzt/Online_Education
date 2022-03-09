cap log close
log using "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Logs\Race_Enrollment_Poisson_$S_DATE", replace 

do "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Code\Modules\poissonbootstrap"

use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Stride_AnalyticDf.dta", clear

* Create Fixed Effects
egen sch_zip = group(NCES_School_Code Zip_Code)
egen ST_num=group(ST)
egen stridefe = group(NCES_School_Code)
egen stride_neigh_fe = group(NCES_School_Code Nearby_LEAID)

* Fix missing values with mean imputation instead of dummies
replace nearby_sd_per_black_lag = . if missing_nearby_sd_per_black_lag == 1 
replace nearby_sd_per_hispanic_l = . if missing_nearby_sd_per_hispanic_l == 1
replace nearby_sd_per_other_lag = . if missing_nearby_sd_per_other_lag == 1

tsset sch_zip year
local vars "black hispanic"
foreach y of local vars{
	* Contemporaneous
	replace nearby_sd_per_`y' = . if missing_nearby_sd_per_`y' == 1 
	gen `y'_plusone =  F.nearby_sd_per_`y'
	gen `y'_minusone =  L.nearby_sd_per_`y'
	egen `y'_avg = rowmean(`y'_plusone `y'_minusone)
	replace nearby_sd_per_`y' = `y'_avg if nearby_sd_per_`y' == .
	summ nearby_sd_per_`y'
	replace nearby_sd_per_`y' = r(mean) if nearby_sd_per_`y' == .
	cap drop `y'_plusone `y'_minusone `y'_avg	
	
	*Lag
	replace nearby_sd_per_`y'_l = . if missing_nearby_sd_per_`y'_l == 1 
	gen `y'_plusone =  F.nearby_sd_per_`y'_l
	gen `y'_minusone =  L.nearby_sd_per_`y'_l
	egen `y'_avg = rowmean(`y'_plusone `y'_minusone)
	replace nearby_sd_per_`y'_l = `y'_avg if nearby_sd_per_`y'_l == .
	summ nearby_sd_per_`y'_l
	replace nearby_sd_per_`y'_l = r(mean) if nearby_sd_per_`y'_l == .
	cap drop `y'_plusone `y'_minusone `y'_avg
}

tsset, clear

* Scale Vars
replace median_incom = median_incom/1000
replace nearby_dist_enrollment = nearby_dist_enrollment/1000
replace mean_down = mean_down/10

* Prep reg vars	
gen mean_down_2 = mean_down * mean_down
gen mean_down_3 = mean_down * mean_down * mean_down

label define urb 1 "Metropolitan" 2 "Micropolitan" 3 "Town" 4 "Rural"

* Create Reace Specific Enrollments
gen OnlineBlackEnrollment = pct_African_American*Total_Enrollment
replace OnlineBlackEnrollment = 0 if OnlineBlackEnrollment == .

gen OnlineHispEnrollment = pct_Hispanic*Total_Enrollment
replace OnlineHispEnrollment = 0 if OnlineHispEnrollment == .

gen OnlineWhiteEnrollment = pct_White_or_Caucasian*Total_Enrollment
replace OnlineWhiteEnrollment = 0 if OnlineWhiteEnrollment == .

xtile mean_quint = mean_down, nq(5)

////////////////////////////////////////////////////////////////////////////////
* Prep Vars

global controls median_income nearby_sd__virtual nearby_sd_partime_virtual nearby_sd_per_black nearby_sd_per_hispanic nearby_sd_per_other i.urbanicity
global missing missing_median_income missing_nearby_sd__virtual missing_nearby_sd_partime_virtua missing_nearby_sd_per_other missing_achievement

global timecontrol nearby_sd__virtual nearby_sd_partime_virtual nearby_sd_per_black_lag nearby_sd_per_hispanic_lag nearby_sd_per_other_lag
global missingtimecontrol missing_nearby_sd__virtual missing_nearby_sd_partime_virtua missing_nearby_sd_per_other_lag

xtile achievement_quint = achievement, nq(5)
xtile achievement_quint_black = achievement_blk, nq(5)
xtile achievement_quint_hisp  = achievement_hsp, nq(5)
xtile achievement_quint_white = achievement_wht, nq(5)

////////////////////////////////////////////////////////////////////////////////
* Iniatiate matrices size
////////////////////////////////////////////////////////////////////////////////

* Stride School Fixed Effects - Linear Achievement
cap drop pop_weight
cap xtclear, clear
xtset stridefe
bys stridefe : egen pop_weight = mean(child_pop)

xtpoisson OnlineBlackEnrollment i.mean_quint achievement i.year $controls $missing if child_pop_black > 0.5, fe exposure(child_pop_black) irr 
mat coefs_black_stridefe = e(b)'

xtpoisson OnlineHispEnrollment i.mean_quint achievement i.year $controls $missing if child_pop_hisp > 0.5, fe exposure(child_pop_hisp) irr 
mat coefs_hisp_stridefe =  e(b)'

xtpoisson OnlineWhiteEnrollment i.mean_quint achievement i.year $controls $missing if child_pop_white > 0.5, fe exposure(child_pop_white) irr 
mat coefs_white_stridefe = e(b)'

* Stride School Fixed Effects - Quintile Achievement
xtpoisson OnlineBlackEnrollment i.mean_quint  i.achievement_quint_black i.year $controls $missing if child_pop_black > 0.5, fe exposure(child_pop_black) irr 
mat coefs_black_stridefe_quint = e(b)'

xtpoisson OnlineHispEnrollment i.mean_quint  i.achievement_quint_hisp   i.year $controls $missing if child_pop_hisp > 0.5, fe exposure(child_pop_hisp) irr 
mat coefs_hisp_stridefe_quint =  e(b)'

xtpoisson OnlineWhiteEnrollment i.mean_quint  i.achievement_quint_white i.year $controls $missing if child_pop_white > 0.5, fe exposure(child_pop_white) irr 
mat coefs_white_stridefe_quint = e(b)'
		
* Stride School By Neighborhood SD Fixed Effects
cap drop pop_weight
cap xtclear, clear
xtset stride_neigh_fe
bys stride_neigh_fe : egen pop_weight = mean(child_pop)

xtpoisson OnlineBlackEnrollment i.mean_quint i.year $controls $missing if child_pop_black > 0.5, fe exposure(child_pop_black) irr 
mat coefs_black_stride_neigh_fe = e(b)'

xtpoisson OnlineHispEnrollment i.mean_quint i.year $controls $missing if child_pop_hisp > 0.5, fe exposure(child_pop_hisp) irr 
mat coefs_hisp_stride_neigh_fe =  e(b)'

xtpoisson OnlineWhiteEnrollment i.mean_quint i.year $controls $missing if child_pop_white > 0.5, fe exposure(child_pop_white) irr 
mat coefs_white_stride_neigh_fe =  e(b)'

* Stride School By Zip Code Fixed Effects
cap drop pop_weight
cap xtclear, clear
xtset sch_zip
bys sch_zip : egen pop_weight = mean(child_pop)

xtpoisson OnlineBlackEnrollment i.mean_quint i.year  $timecontrol  $missingtimecontrol if child_pop_black > 0.5 , fe exposure(child_pop_black) irr 
mat coefs_black_stride_zip_fe =  e(b)'

xtpoisson OnlineHispEnrollment i.mean_quint i.year  $timecontrol  $missingtimecontrol  if child_pop_hisp > 0.5, fe exposure(child_pop_hisp) irr 
mat coefs_hisp_stride_zip_fe =  e(b)'

xtpoisson OnlineWhiteEnrollment i.mean_quint i.year  $timecontrol  $missingtimecontrol  if child_pop_white > 0.5, fe exposure(child_pop_white) irr 
mat coefs_white_stride_zip_fe =  e(b)'


/////////////////////////////////////////////////////////////////////////
* Models

* Note that this is an implementation of the poissonbootstrap module, but 
* importantly allows the race specific models to be estimated on the same 
* bootstrapped sample, which can faccilitate comparisons across models.

* Unfortunatly, differnt fixed effects need to be handled by hand, ran out of 
* time to do this programmatically. 

display "$S_TIME"
local starttime = "$S_TIME"

forvalues y = 1/1000{
	preserve
		quietly {
			set seed `y'
			bsample, cluster(sch_zip)
			* Weights need to be constant within fixed effects
			* Fixed effects can be unbalanced since schools can have
			* a different number of years, and/or a different number of
			* zips nested under them. Thus, average the childpop variable
			* at the fixed effect level. 
			
			
			* Stride School Fixed Effects - Linear Achivement
			
			cap drop pop_weight
			cap xtclear, clear
			xtset stridefe
			bys stridefe : egen pop_weight = mean(child_pop)
			
			xtpoisson OnlineBlackEnrollment i.mean_quint achievement_blk i.year $controls $missing if child_pop_black > 0.5, fe exposure(child_pop_black) irr 
			mat coefs_black_stridefe = coefs_black_stridefe, e(b)'
			
			xtpoisson OnlineHispEnrollment i.mean_quint achievement_hsp i.year $controls $missing if child_pop_hisp > 0.5, fe exposure(child_pop_hisp) irr 
			mat coefs_hisp_stridefe = coefs_hisp_stridefe, e(b)'
			
			xtpoisson OnlineWhiteEnrollment i.mean_quint achievement_wht i.year $controls $missing if child_pop_white > 0.5, fe exposure(child_pop_white) irr 
			mat coefs_white_stridefe = coefs_white_stridefe, e(b)'
			
		}
		display `y'
	restore
}


* Drop the first column that was added soley for var names
local ncol =  colsof(coefs_white_stride_zip_fe)

mat coefs_black_stridefe = coefs_black_stridefe[., 2..`ncol']
mat coefs_hisp_stridefe  = coefs_hisp_stridefe[., 2..`ncol']
mat coefs_white_stridefe = coefs_white_stridefe[., 2..`ncol']

cd "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate"

mat2txt, matrix(coefs_black_stridefe) saving(".\coefs_black_stridefe.txt") replace
mat2txt, matrix(coefs_hisp_stridefe)  saving(".\coefs_hisp_stridefe.txt") replace
mat2txt, matrix(coefs_white_stridefe) saving(".\coefs_white_stridefe.txt") replace

/*
mat2txt, matrix(coefs_black_stridefe_quint) saving(".\coefs_black_stridefe_quint.txt") replace
mat2txt, matrix(coefs_hisp_stridefe_quint)  saving(".\coefs_hisp_stridefe_quint.txt") replace
mat2txt, matrix(coefs_white_stridefe_quint) saving(".\coefs_white_stridefe_quint.txt") replace

mat2txt, matrix(coefs_black_stride_neigh_fe) saving(".\coefs_black_stride_neigh_fe.txt") replace
mat2txt, matrix(coefs_hisp_stride_neigh_fe)  saving(".\coefs_hisp_stride_neigh_fe.txt") replace
mat2txt, matrix(coefs_white_stride_neigh_fe) saving(".\coefs_white_stride_neigh_fe.txt") replace

mat2txt, matrix(coefs_black_stride_zip_fe) saving(".\coefs_black_stride_zip_fe.txt") replace
mat2txt, matrix(coefs_hisp_stride_zip_fe) saving(".\coefs_hisp_stride_zip_fe.txt") replace
mat2txt, matrix(coefs_white_stride_zip_fe) saving(".\coefs_white_stride_zip_fe.txt") replace
*/

log close