cap log close
log using "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Logs\Race_Chow_Test$S_DATE", replace 

* Performs a Chow test to see if the results depend on race and ethnicity. 
use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Stride_AnalyticDf.dta", clear

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


global controls median_income nearby_dist_enrollment nearby_sd__virtual nearby_sd_partime_virtual nearby_sd_per_black nearby_sd_per_hispanic nearby_sd_per_other i.urbanicity
global missing missing_median_income missing_nearby_dist_enrollment missing_nearby_sd__virtual missing_nearby_sd_partime_virtua missing_nearby_sd_per_other missing_achievement
global timecontrol nearby_dist_enrollment nearby_sd__virtual nearby_sd_partime_virtual nearby_sd_per_black_lag nearby_sd_per_hispanic_lag nearby_sd_per_other_lag
global missingtimecontrol missing_nearby_dist_enrollment missing_nearby_sd__virtual missing_nearby_sd_partime_virtua missing_nearby_sd_per_other_lag

xtile mean_quint = mean_down, nq(5)

////////////////////////////////////////////////////////////////////////////////
// Stack Data
gen race = .
preserve
	replace Total_Enrollment = pct_African_American*Total_Enrollment
	replace Total_Enrollment = 0 if Total_Enrollment == .

	replace race = 1
	tempfile blackmodel
	save `blackmodel'
restore

preserve
	replace Total_Enrollment = pct_Hispanic*Total_Enrollment
	replace Total_Enrollment = 0 if Total_Enrollment == .

	replace race = 2
	tempfile hispmodel
	save `hispmodel'
restore

replace Total_Enrollment = pct_White_or_Caucasian*Total_Enrollment
replace Total_Enrollment = 0 if Total_Enrollment == .
replace race = 3

append using `blackmodel' `hispmodel'

global controls c.median_income c.nearby_dist_enrollment c.nearby_sd__virtual c.nearby_sd_partime_virtual c.nearby_sd_per_black c.nearby_sd_per_hispanic c.nearby_sd_per_other i.urbanicity

reg Total_Enrollment i.race##(i.mean_quint c.cs_mn_allmth i.year $controls c.child_pop) [aweight = child_pop], vce(cluster sch_zip)

test 	2.race 2.race#2.mean_quint 2.race#3.mean_quint 2.race#4.mean_quint	2.race#5.mean_quint			///
		2.race#c.cs_mn_allmth 2.race#2018.year 2.race#2019.year 2.race#2020.year	///
		2.race#c.median_income 2.race#c.nearby_dist_enrollment						///
		2.race#c.nearby_sd__virtual 2.race#c.nearby_sd_partime_virtual				///
		2.race#c.nearby_sd_per_black 2.race#c.nearby_sd_per_hispanic				///
		2.race#c.nearby_sd_per_other 2.race#2.urbanicity 2.race#3.urbanicity		///
		2.race#4.urbanicity 2.race#c.child_pop										///
		3.race 3.race#2.mean_quint 3.race#3.mean_quint 3.race#4.mean_quint	3.race#5.mean_quint	///
		3.race#c.cs_mn_allmth 3.race#2018.year 3.race#2019.year 3.race#2020.year	///
		3.race#c.median_income 3.race#c.nearby_dist_enrollment						///
		3.race#c.nearby_sd__virtual 3.race#c.nearby_sd_partime_virtual				///
		3.race#c.nearby_sd_per_black 3.race#c.nearby_sd_per_hispanic				///
		3.race#c.nearby_sd_per_other 3.race#2.urbanicity 3.race#3.urbanicity		///
		3.race#4.urbanicity 3.race#c.child_pop										
log close