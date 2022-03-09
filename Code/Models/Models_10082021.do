cap log close
log using "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Logs\Total_Enrollment_Poisson_$S_DATE", replace 

* This code implements a conditional Poisson model for the Online Ed paper, with
* Bootstrapping. 
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
replace child_pop = child_pop/1000
replace nearby_dist_enrollment = nearby_dist_enrollment/1000
replace mean_down = mean_down/10

* Prep reg vars	
gen mean_down_2 = mean_down * mean_down
gen mean_down_3 = mean_down * mean_down * mean_down

label define urb 1 "Metropolitan" 2 "Micropolitan" 3 "Town" 4 "Rural"

global controls median_income nearby_sd__virtual nearby_sd_partime_virtual nearby_sd_per_black nearby_sd_per_hispanic nearby_sd_per_other i.urbanicity
global missing missing_median_income missing_nearby_sd__virtual missing_nearby_sd_partime_virtua missing_nearby_sd_per_other missing_achievement
global timecontrol nearby_sd__virtual nearby_sd_partime_virtual nearby_sd_per_black_lag nearby_sd_per_hispanic_lag nearby_sd_per_other_lag
global missingtimecontrol missing_nearby_sd__virtual missing_nearby_sd_partime_virtua missing_nearby_sd_per_other_lag

/////////////////////////////////////////////////////////////////////////////////////////////
// Run Models

xtile mean_quint = mean_down, nq(5)

pois_boot 1000 stridefe Total_Enrollment "i.mean_quint achievement i.year $controls $missing" "N" "" "" "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coef_stridefe.txt"  "" "" ""

pois_boot 1000 stride_neigh_fe Total_Enrollment "i.mean_quint i.year $controls $missing" "N" "" "" "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coef_stride_neigh_fe.txt" "" "" ""

pois_boot 1000 sch_zip Total_Enrollment "i.mean_quint i.year  $timecontrol  $missingtimecontrol" "N" "" "" "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coef_sch_zip.txt" "" "" ""


log close
