cd "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021"
cap log close
log using ".\Logs\SchoolSeg_$S_DATE", replace

use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Stride_AnalyticDf.dta", clear

egen sch_zip = group(NCES_School_Code Zip_Code)
egen ST_num=group(ST)

* Scale Vars
replace median_incom = median_incom/1000
replace child_pop = child_pop/1000
replace nearby_dist_enrollment = nearby_dist_enrollment/1000
replace mean_down = mean_down/10

* Prep reg vars	
global controls median_income nearby_dist_enrollment nearby_sd_per_black nearby_sd_per_hispanic nearby_sd_per_other i.urbanicity

replace pct_African_American = pct_African_American * 100 
replace pct_Hispanic = pct_Hispanic * 100 
replace pct_White_or_Caucasian = pct_White_or_Caucasian * 100 

* Collapse to the Neighborhood School District level and weight by total enrollment
collapse	(sum) Total_Enrollment (firstnm) nearby_sd_per_white	  			///
			 nearby_sd_per_black nearby_sd_per_hispanic nearby_dist_enrollment	///
			ST_num																///
			(mean) pct_White_or_Caucasian pct_African_American pct_Hispanic		///
			median_income urbanicity mean_down	achievement						///
			[aweight = Total_Enrollment], by(Nearby_LEAID year)

gen mean_down_2 = mean_down * mean_down
gen mean_down_3 = mean_down * mean_down * mean_down

* Urbanicity is at the zip code level. Bin at district level depending on the
* average urbanicity			
replace urbanicity = 1 if urbanicity >= 0.5 & urbanicity < 1.5	
replace urbanicity = 2 if urbanicity >= 1.5 &urbanicity < 2.5	
replace urbanicity = 3 if urbanicity >= 2.5 &urbanicity < 3.5	
replace urbanicity = 4 if urbanicity >= 3.5 &urbanicity < 4.5	

/////////////////////////////////////////////////////////////////////////////
// Percent Black
/////////////////////////////////////////////////////////////////////////////
areg pct_African_American c.nearby_sd_per_black##c.nearby_sd_per_black##c.nearby_sd_per_black i.year i.urbanicity nearby_dist_enrollment median_income i.urbanicity achievement mean_down mean_down_2 mean_down_3, absorb(ST_num)

cap drop xs*
cap drop stfe*

margins, at(nearby_sd_per_black = (1(1)100))
mat stfe = r(table)
mat stfe = stfe'
svmat stfe

matrix xs = J(100,1,.)
local counter = 0
forvalues x=1(1)100{
	local counter = `counter' + 1
	mat xs[`counter',1] = `x'
}
svmat xs

* The plot it is too difficult to read with all of the data. Create percentage
* point bins between 0 and 100 on the x - axis variable. In this case, percent
* Black. 


cap drop bins
gen bins = 0 if nearby_sd_per_black < 0.5
forvalues y = 1/100{
	replace bins = `y' if nearby_sd_per_black >= (`y'-0.5) & nearby_sd_per_black < `y'
}
bys bins : egen mean_blck = mean(pct_African_American)
sort xs1

graph twoway 	(scatter mean_blck bins)										|| 	///
				(line stfe1 xs1)							|| 	///
				(function y=x, range(0 100)),										///
				xtitle("Percent Black: Neighborhood School District", size(small)) ///
				ytitle("Percent Black: Stride Schools", size(small)) ///
				graphregion(color(white)) legend(order(2 "O" 3 "A")) ylabel(0(20)100, nogrid)
				
graph export ".\Output\Figures\SchoolSeg_Black.png", replace


/////////////////////////////////////////////////////////////////////////////
// Percent Hispanic
/////////////////////////////////////////////////////////////////////////////
areg pct_Hispanic c.nearby_sd_per_hispanic##c.nearby_sd_per_hispanic##c.nearby_sd_per_hispanic i.year i.urbanicity nearby_dist_enrollment median_income i.urbanicity achievement mean_down mean_down_2 mean_down_3, absorb(ST_num)

cap drop xs*
cap drop stfe*

margins, at(nearby_sd_per_hispanic = (1(1)100))
mat stfe = r(table)
mat stfe = stfe'
svmat stfe

matrix xs = J(100,1,.)
local counter = 0
forvalues x=1(1)100{
	local counter = `counter' + 1
	mat xs[`counter',1] = `x'
}
svmat xs
* Binning
cap drop bins
gen bins = 0 if nearby_sd_per_hispanic < 0.5
forvalues y = 1/100{
	replace bins = `y' if nearby_sd_per_hispanic >= (`y'-0.5) & nearby_sd_per_hispanic < `y'
}
bys bins : egen mean_hisp = mean(pct_Hispanic)
sort xs1

graph twoway 	(scatter mean_hisp bins)										|| 	///
				(line stfe1 xs1)							|| 	///
				(function y=x, range(0 100)),										///
				xtitle("Percent Hispanic: Neighborhood School District", size(small)) ///
				ytitle("Percent Hispanic: Stride Schools", size(small)) ///
				graphregion(color(white)) legend(off) ylabel(0(20)100, nogrid)
				
graph export ".\Output\Figures\SchoolSeg_Hisp.png", replace


/////////////////////////////////////////////////////////////////////////////
// Percent White
/////////////////////////////////////////////////////////////////////////////
areg pct_White_or_Caucasian c.nearby_sd_per_white##c.nearby_sd_per_white##c.nearby_sd_per_white i.year i.urbanicity nearby_dist_enrollment median_income i.urbanicity achievement mean_down mean_down_2 mean_down_3, absorb(ST_num)

cap drop xs*
cap drop stfe*

margins, at(nearby_sd_per_white = (1(1)100))
mat stfe = r(table)
mat stfe = stfe'
svmat stfe

matrix xs = J(100,1,.)
local counter = 0
forvalues x=1(1)100{
	local counter = `counter' + 1
	mat xs[`counter',1] = `x'
}
svmat xs

* Binning
cap drop bins
gen bins = 0 if nearby_sd_per_white < 0.5
forvalues y = 1/100{
	replace bins = `y' if nearby_sd_per_white >= (`y'-0.5) & nearby_sd_per_white < `y'
}
bys bins : egen mean_wht = mean(pct_White_or_Caucasian)
sort xs1

graph twoway 	(scatter mean_wht bins)											|| 	///
				(line stfe1 xs1)							|| 	///
				(function y=x, range(0 100)),										///
				xtitle("Percent White: Neighborhood School District", size(small)) ///
				ytitle("Percent White: Stride Schools", size(small)) ///
				graphregion(color(white)) legend(off) ylabel(0(20)100, nogrid)
				
graph export ".\Output\Figures\SchoolSeg_White.png", replace

log close