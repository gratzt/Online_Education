cd "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021"
cap log close
log using ".\Logs\CCD_Stride_SummaryStatistics_$S_DATE"

////////////////////////////////////////////////////////////////////////////////
// Notes:
//
// This file conducted a large amount of exploratory data analysis. It has
// been reduced to help display the most important results. On that point here
// is a useful map:
// 
// Line 84 saves a state-level enrollment file used for figure 1.
// Line 193 outputs table 1
// Line 385 outputs figure 2. 


////////////////////////////////////////////////////////////////////////////////
// Pull and Prep CCD
use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\stacked_ccd.dta", clear
rename NCESSCH ccdMergeID
keep if inlist(year, 2017, 2018, 2019, 2020)
tempfile ccdata
save `ccdata'

///////////////////////////////////////////////////////////////////////////////
// Create Virtual Enrollments by State used for Figure 1

use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Stride_AnalyticDf.dta", clear
egen stridefe = group(NCES_School_Code)
egen tag ny_tag= tag(Nearby_LEAID syear)
egen tag syz_tag= tag( stridefe syear Zip_Code )
total nearby_dist_enrollment if ny_tag
replace nearby_dist_enrollment = nearby_dist_enrollment/1000
total Total_Enrollment if syz_tag

* Get number of zips per neighborhood sd
preserve
	egen ztag = tag(Nearby_LEAID year Zip_Code)
	bys Nearby_LEAID year : egen ztot = total(ztag)
	keep Nearby_LEAID year ztot
	duplicates drop
	summ ztot
restore

keep NCES_School_Code year ccdMergeID
duplicates drop ccdMergeID year, force

merge 1:1 ccdMergeID year using  `ccdata', update

replace ST = "AL" if inlist(NCES_School_Code, 10141002439) & _merge == 1
replace ST = "CA" if inlist(NCES_School_Code, 60188411996, 60171612034, 60245114255, 60180510641, 60199013191, 60180211787, 60231611478, 60181013698, 60161614251) & _merge == 1
replace ST = "CO" if inlist(NCES_School_Code, 80028206752, 80028206764) & _merge == 1
replace ST = "SC" if inlist(NCES_School_Code, 450390901616, 450390901513) & _merge == 1
replace ST = "CA" if inlist(NCES_School_Code, 60152813030, 60217113952, 60174513167, 60196412477) & _merge == 1
replace ST = "WA" if inlist(NCES_School_Code, 530702003665) & _merge == 1

gen stride = _merge == 1 | _merge == 3
drop _merge
gen stride_enroll = race_totalenrollment if  stride == 1
gen virtual_enroll = race_totalenrollment if _virtual==1
gen partime_enroll = race_totalenrollment if partime_virtual == 1
gen not_enroll = race_totalenrollment if not_virtual == 1

foreach y of var per_nativeamerican per_asian per_black per_hispanic per_nhpi per_white {
	gen num_`y' = `y'/100 * race_totalenrollment
	gen str_num_`y' = num_`y' if stride==1	
	gen vir_num_`y' = num_`y' if _virtual==1
	gen ptvir_num_`y' = num_`y' if partime_virtual==1
	gen notvir_num_`y' = num_`y' if not_virtual==1
		
}

collapse (sum) stride_enroll virtual_enroll partime_enroll not_enroll totalenrollment=race_totalenrollment num_per_nativeamerican-notvir_num_per_white, by(year ST)

total virtual_enroll if year == 2017
total virtual_enroll if year == 2020

bys ST : egen tempvenroll2017 = max(virtual_enroll) if year == 2017
bys ST : egen venroll2017 =  max(tempvenroll2017)
gen perchange = virtual_enroll/venroll2017
count if year == 2020 & virtual_enroll != . & virtual_enroll != 0 & perchange> 1 & perchange != .
 count if year == 2020 & virtual_enroll != . & virtual_enroll != 0  & perchange != .
 
save "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\statelevel_enrollments.dta", replace

////////////////////////////////////////////////////////////////////////////////
// Summary Statistics 
////////////////////////////////////////////////////////////////////////////////
cd "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021"

////////////////////////////
// Get Stride School Codes
use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Stride_AnalyticDf.dta", clear
total Total_Enrollment
codebook Zip_Code
keep NCES_School_Code ccdMergeID year Total_Enrollment
rename Total_Enrollment stride_Total_Enrollment
collapse (firstnm) NCES_School_Code (sum) stride_Total_Enrollment, by(ccdMergeID year)
gen stride = 1
tempfile stride
save `stride'

////////////////////////////////////////////////////
// Use Common Core as base data - Merge in Stride
use "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\stacked_ccd.dta", clear
rename NCESSCH ccdMergeID
replace per_frpl = 1 if per_frpl > 1 & per_frpl != .
keep if inlist(year, 2017, 2018, 2019, 2020)
merge 1:1  ccdMergeID year using  `stride'
replace stride = 0 if _merge == 1
drop _merge

* Get School Level Average Enrollment
summ School_Total_Enrollment
summ School_Total_Enrollment if partime_virtual == 1
summ School_Total_Enrollment if _virtual==1
summ stride_Total_Enrollment if  stride == 1
summ School_Total_Enrollment if  _virtual == 1 | partime_virtual == 1

* Get Number of schools
codebook ccdMergeID
codebook ccdMergeID if  _virtual == 1 | partime_virtual == 1
codebook ccdMergeID if _virtual==1
codebook NCES_School_Code if  stride == 1 
total School_Total_Enrollment if _virtual == 1
total School_Total_Enrollment if _virtual == 1 &  stride == 1

// Some schools change CCD IDs hence the need to create ccdMergeID, but they 
// are the same schools.

gen stride_enroll = School_Total_Enrollment if  stride == 1
gen virtual_enroll = School_Total_Enrollment if _virtual==1
gen partime_enroll = School_Total_Enrollment if partime_virtual == 1
gen not_enroll = School_Total_Enrollment if not_virtual == 1
gen virnostr_enroll = School_Total_Enrollment if _virtual==1 &  stride == 0


count if School_Total_Enrollment == . &  per_female != .
/////////////////////////////////////////////////////////
// Summary by year
preserve
	drop if per_female == .
	forvalues y = 2017/2020{
		eststo m1`y': estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl if year == `y'
	}

	forvalues y = 2017/2020{
		eststo m2`y': estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl if year == `y' & _virtual==1
	}

	forvalues y = 2017/2020{
		eststo m3`y': estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl if year == `y' & stride == 1
	}

	forvalues y = 2017/2020{
		eststo m4`y': estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl if year == `y' & _virtual==1  & stride == 0
	}
	
	forvalues y = 2017/2020{
		eststo m5`y': estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl if year == `y' & partime_virtual==1  
	}
restore

count if per_female !=.
local denum = r(N)
count if per_frpl == .
local numer = r(N)

local allmissingfrpl = round(100*(`numer'/`denum'),0.1)

count if per_female !=. &  _virtual==1
local denum = r(N)
count if per_frpl == . &  _virtual==1
local numer = r(N)

local virmissingfrpl = round(100*(`numer'/`denum'),0.1)

////////////////////////////////////////////////////////////////////////////////
// Summary Statistics Across Years - Table 1
////////////////////////////////////////////////////////////////////////////////

* Across years
eststo m1: estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl
eststo m2: estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl if _virtual==1
eststo m3: estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl if stride == 1
eststo m4: estpost summ  School_Total_Enrollment per_female per_male per_nativeamerican per_asian per_black per_hispanic per_nhpi per_multiracial per_white per_frpl if partime_virtual == 1

total School_Total_Enrollment if per_female != . 
total School_Total_Enrollment if per_female != . & _virtual==1
total School_Total_Enrollment if per_female != . & stride == 1
total School_Total_Enrollment if per_female != . & partime_virtual == 1
	
esttab m1 m2 m3 m4 ///
		using "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Output\Tables\Stide_vs_CCDALLYEARS.csv", replace cells("mean(fmt(4))" "sd(fmt(4))") ///
		addnote("Percent of Schools missing FRPL data, All: `allmissingfrpl', Virtual: `virmissingfrpl'")
		
		
		
//////////////////////////////////////////////////////////////
// Get Percents at Year Level - not at school and year level
//////////////////////////////////////////////////////////////
foreach y of var per_nativeamerican per_asian per_black per_hispanic per_nhpi per_white per_female per_multiracial per_male {
	gen num_`y' = `y' * race_totalenrollment
	gen str_num_`y' = num_`y' if stride==1
	gen prt_num_`y' = num_`y' if  partime_virtual == 1
	gen vir_num_`y' = num_`y' if _virtual==1
	gen vir_nostr_`y' = num_`y' if _virtual==1 & stride==0

}


collapse (sum) virnostr_enroll stride_enroll virtual_enroll partime_enroll not_enroll totalenrollment=race_totalenrollment num_per_nativeamerican-vir_nostr_per_male, by(year)

gen per_white 	= num_per_white / totalenrollment
gen per_black 	= num_per_black / totalenrollment
gen per_hisp	= num_per_hispanic / totalenrollment
gen per_asian	= num_per_asian / totalenrollment
gen per_nhpi	= num_per_nhpi/ totalenrollment
gen per_aian 	= num_per_nativeamerican / totalenrollment
gen per_male 	= num_per_male / totalenrollment
gen per_female 	= num_per_female / totalenrollment
gen per_multi	= num_per_multiracial / totalenrollment

gen str_per_white 	= str_num_per_white / stride_enroll
gen str_per_black 	= str_num_per_black / stride_enroll
gen str_per_hisp	= str_num_per_hispanic / stride_enroll
gen str_per_asian	= str_num_per_asian / stride_enroll
gen str_per_nhpi	= str_num_per_nhpi / stride_enroll
gen str_per_aian 	= str_num_per_nativeamerican / stride_enroll
gen str_per_male 	= str_num_per_male / stride_enroll
gen str_per_female 	= str_num_per_female / stride_enroll
gen str_per_multi	= str_num_per_multiracial / stride_enroll

gen vir_per_white 	= vir_num_per_white / virtual_enroll
gen vir_per_black 	= vir_num_per_black / virtual_enroll
gen vir_per_hisp	= vir_num_per_hispanic / virtual_enroll
gen vir_per_asian	= vir_num_per_asian / virtual_enroll
gen vir_per_nhpi	= vir_num_per_nhpi / virtual_enroll
gen vir_per_aian 	= vir_num_per_nativeamerican / virtual_enroll
gen vir_per_male 	= vir_num_per_male / virtual_enroll
gen vir_per_female 	= vir_num_per_female / virtual_enroll
gen vir_per_multi	= vir_num_per_multiracial / virtual_enroll

gen virnostr_per_white 	= vir_nostr_per_white / virnostr_enroll
gen virnostr_per_black 	= vir_nostr_per_black / virnostr_enroll
gen virnostr_per_hisp	= vir_nostr_per_hispanic / virnostr_enroll
gen virnostr_per_asian	= vir_nostr_per_asian / virnostr_enroll
gen virnostr_per_nhpi	= vir_nostr_per_nhpi / virnostr_enroll
gen virnostr_per_aian 	= vir_nostr_per_nativeamerican / virnostr_enroll
gen virnostr_per_male 	= vir_nostr_per_male / virnostr_enroll
gen virnostr_per_female = vir_nostr_per_female / virnostr_enroll
gen virnostr_per_multi	= vir_nostr_per_multiracial / virnostr_enroll


gen prt_per_white 	= prt_num_per_white / partime_enroll
gen prt_per_black 	= prt_num_per_black / partime_enroll
gen prt_per_hisp	= prt_num_per_hispanic / partime_enroll
gen prt_per_asian	= prt_num_per_asian / partime_enroll
gen prt_per_nhpi	= prt_num_per_nhpi / partime_enroll
gen prt_per_aian 	= prt_num_per_nativeamerican / partime_enroll
gen prt_per_male 	= prt_num_per_male / partime_enroll
gen prt_per_female = prt_num_per_female / partime_enroll
gen prt_per_multi	= prt_num_per_multiracial / partime_enroll

gen anyvir_enroll = partime_enroll + virtual_enroll
gen anyv_per_white 	= (vir_num_per_white + prt_num_per_white) / (anyvir_enroll)
gen anyv_per_black 	= (vir_num_per_black + prt_num_per_black) / (anyvir_enroll)
gen anyv_per_hisp	= (vir_num_per_hispanic + prt_num_per_hispanic) / (anyvir_enroll)
gen anyv_per_asian	= (vir_num_per_asian + prt_num_per_asian) / (anyvir_enroll)
gen anyv_per_nhpi	= (vir_num_per_nhpi + prt_num_per_nhpi) / (anyvir_enroll)
gen anyv_per_aian 	= (vir_num_per_nativeamerican + prt_num_per_nativeamerican) / (anyvir_enroll)
gen anyv_per_male 	= (vir_num_per_male + prt_num_per_male) / (anyvir_enroll)
gen anyv_per_female = (vir_num_per_female + prt_num_per_female) / (anyvir_enroll)
gen anyv_per_multi	= (vir_num_per_multiracial + prt_num_per_multiracial) / (anyvir_enroll)


forvalues y = 2017/2020{
	eststo m1`y': estpost summ  per_white per_black per_hisp per_asian per_nhpi per_aian per_multi per_male per_female totalenrollment if year == `y'
}

forvalues y = 2017/2020{
	eststo m2`y': estpost summ  vir_per_white vir_per_black vir_per_hisp vir_per_asian vir_per_nhpi vir_per_aian vir_per_multi vir_per_male vir_per_female virtual_enroll if year == `y'
}

forvalues y = 2017/2020{
	eststo m3`y': estpost summ  str_per_white str_per_black str_per_hisp str_per_asian str_per_nhpi str_per_aian str_per_multi str_per_male str_per_female stride_enroll if year == `y'
}

forvalues y = 2017/2020{
	eststo m4`y': estpost summ  virnostr_per_white virnostr_per_black virnostr_per_hisp virnostr_per_asian virnostr_per_nhpi virnostr_per_aian virnostr_per_multi virnostr_per_male virnostr_per_female virnostr_enroll if year == `y'
}

forvalues y = 2017/2020{
	eststo m5`y': estpost summ  prt_per_white prt_per_black prt_per_hisp prt_per_asian prt_per_nhpi prt_per_aian prt_per_multi prt_per_male prt_per_female partime_enroll if year == `y'
}


esttab 	m12017 m12018 m12019 m12020 ///
		m22017 m22018 m22019 m22020 ///
		m32017 m32018 m32019 m32020 ///
		m42017 m42018 m42019 m42020 ///	
		m52017 m52018 m52019 m52020 ///	
		using "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Output\Tables\Stide_vs_CCD.csv", replace cells("mean(fmt(2))")


* Across all years
eststo m1: estpost summ  per_white per_black per_hisp per_asian per_nhpi per_aian per_multi per_male per_female totalenrollment 	
eststo m2: estpost summ  anyv_per_white anyv_per_black anyv_per_hisp anyv_per_asian anyv_per_nhpi anyv_per_aian anyv_per_multi anyv_per_male anyv_per_female anyvir_enroll 
eststo m3: estpost summ  vir_per_white vir_per_black vir_per_hisp vir_per_asian vir_per_nhpi vir_per_aian vir_per_multi vir_per_male vir_per_female virtual_enroll 
eststo m4: estpost summ  str_per_white str_per_black str_per_hisp str_per_asian str_per_nhpi str_per_aian str_per_multi str_per_male str_per_female stride_enroll
*eststo m4: estpost summ  prt_per_white prt_per_black prt_per_hisp prt_per_asian prt_per_nhpi prt_per_aian prt_per_multi prt_per_male prt_per_female partime_enroll

total totalenrollment
total virtual_enroll
total stride_enroll
total partime_enroll
total anyvir_enroll
 
esttab 	m1 m2 m3 m4 ///	
		using "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Output\Tables\Stide_vs_CCD_Allyears.csv", replace cells("mean(fmt(4))")
		
* Plot Changes in Virtual School Demographics from baseline year of 2017
gen tempblack2017 = vir_per_black if year == 2017
egen black2017 = max(tempblack2017)
gen perchange_black = 100*(vir_per_black - black2017)/black2017

gen temphisp2017 = vir_per_hisp if year == 2017
egen hisp2017 = max(temphisp2017)
gen perchange_hisp = 100*(vir_per_hisp - hisp2017)/hisp2017

gen tempwhite2017 = vir_per_white if year == 2017
egen white2017 = max(tempwhite2017)
gen perchange_white = 100*(vir_per_white - white2017)/white2017

gen tempasian2017 = vir_per_asian if year == 2017
egen asian2017 = max(tempasian2017)
gen perchange_asian = 100*(vir_per_asian - asian2017)/asian2017

graph set window fontface "Times New Roman"
graph twoway 	(line perchange_asian year) || (line perchange_black year) 		///
				(line perchange_hisp year) || (line perchange_white year), 		///
				xtitle("Year", size(small))										///
				ytitle("Percent Change", size(small))							///
				graphregion(color(white))										///
				ylabel(-10(10)20, nogrid)										///
				yline(0, lcolor(black))											///
				title("Compositional Changes in Virtual School Enrollment" "Baseline: 2017", color(Black) size(medsmall)) ///
				legend(order(1 "Asian" 2 "Black" 3 "Hispanic" 4 "White") nobox region(lstyle(none)) cols(1) ring(0) bplacement(nw)) 

graph export ".\Output\Figures\RaceCompositionalChanges.png", replace

		
* Plot Changes in Enrollment from baseline year of 2017
gen tempenroll = totalenrollment if year == 2017
egen enroll2017 = max(tempenroll)
gen perchange_enroll = 100*(totalenrollment - enroll2017)/enroll2017

gen virtempenroll = virtual_enroll if year == 2017
egen virenroll2017 = max(virtempenroll)
gen perchange_virenroll = 100*(virtual_enroll - virenroll2017)/virenroll2017

gen strtempenroll = stride_enroll if year == 2017
egen strenroll2017 = max(strtempenroll)
gen perchange_strenroll = 100*(stride_enroll - strenroll2017)/strenroll2017

gen pttempenroll = partime_enroll if year == 2017
egen ptenroll2017 = max(pttempenroll)
gen perchange_ptenroll = 100*(partime_enroll - ptenroll2017)/ptenroll2017

/////////////
* FIGURE 2
/////////////

graph set window fontface "Times New Roman"
graph twoway 	(line perchange_enroll year) || (line perchange_virenroll year) 		///
				(line perchange_ptenroll year) || (line perchange_strenroll year), 		///
				xtitle("Year", size(small))										///
				ytitle("Percent Change", size(small))							///
				graphregion(color(white))										///
				ylabel(-10(10)40, nogrid)										///
				yline(0, lcolor(black))											///
				title("Percent Changes in School Enrollment" "Baseline: 2017", color(Black) size(medsmall)) ///
				legend(order(1 "All" 2 "Fully Virtual" 3 "Partially Virtual" 4 "Stride") nobox region(lstyle(none)) cols(1) ring(0) bplacement(nw) symys(*.5) symxs(*.5) size(3) bm(tiny)) 

graph export ".\Output\Figures\PercentEnrollmentChanges.png", replace
		
log close
