cd "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021"

cap log close
log using ".\Logs\Stride_VS_Neighborhood_$S_DATE", replace


//////////////////////////////////////////////////////////////////////////////
// Program for calcuating differences in summary statistics with frequency weights
*1st arg = Name of matrix to store values
*2nd arg = Frequency weights variable
*3rd arg = Cluster var

cap program drop get_pvals
program get_pvals
	local num : list sizeof global(stride_race)
	matrix `1' = J(`num', 3, .)
	matrix colnames `1' = Diff SE PVAL
	matrix rownames `1' = $stride_race
	forvalues x=1/`num'{
		local depvar_str : word `x' of $stride_race
		local depvar_nsd : word `x' of $neighborhood_sd_race
		local weight : word `x' of $weights

		mean  `depvar_str' `depvar_nsd' [fw=`2'], vce(cluster `3')
		lincom ( `depvar_str')-(`depvar_nsd')
		
		matrix `1'[`x', 1] = r(estimate)
		matrix `1'[`x', 2] = r(se)
		matrix `1'[`x', 3] = r(p)

	}
end 

* Calculates standard errors and p-values for clustering on two vars.
* Calls the get_pval prog
* Follows EQ 2.11 from:
* Cameron, A. C., Gelbach, J. B., & Miller, D. L. (2011). Robust inference with multiway clustering. Journal of Business & Economic Statistics, 29(2), 238-249.

*1st arg = Name of matrix to store values
*2nd arg = Frequency weights variable1
*3rd arg = Cluster var 1
*4rd arg = Cluster var 2

cap program drop multicluster
program multicluster
	cap drop clustvar
	egen clustvar = group(`3' `4') 
	local num : list sizeof global(stride_race)
	
	qui get_pvals `1'_1 `2' `3'
	qui get_pvals `1'_2 `2' `4'
	qui get_pvals `1'_3 `2' clustvar
	
	matrix colnames `1'_1 = Diff SE PVAL
	matrix rownames `1'_1 = $stride_race
	matrix colnames `1'_2 = Diff SE PVAL
	matrix rownames `1'_2 = $stride_race
	matrix colnames `1'_3 = Diff SE PVAL
	matrix rownames `1'_3 = $stride_race
	
	* Square the SEs
	mat var_1 = diag(`1'_1[1..4,2])*`1'_1[1..4,2]
	mat var_2 = diag(`1'_2[1..4,2])*`1'_2[1..4,2]
	mat var_3 = diag(`1'_3[1..4,2])*`1'_3[1..4,2]
	
	* mat sum
	mat summat = var_1 + var_2 - var_3

	* Take SQRT
	mat B = summat 
	forval i = 1/`= rowsof(summat)' { 
		forval j = 1/`= colsof(summat)' { 
			mat B[`i', `j'] = sqrt(summat[`i', `j']) 
		}
	}
	
	* Replace SEs with B, compute and replace p-values
	matrix `1' = `1'_3
	forvalues i=1/4{
	    *https://www.bmj.com/content/343/bmj.d2304
	    * Update SEs
	    matrix `1'[`i', 2] = B[`i', 1]
		* Update Pvalue
		local zval = `1'[`i', 1]/`1'[`i', 2]
		matrix `1'[`i', 3] = 2*(1-normal(abs(`zval'))) 
		
	}

end 
///////////////////////////////////////////////////////////////////////////////
// Summary Statistics on residential zip codes

use ".\Data\Stride_AnalyticDf.dta", clear

gen whtenroll = Total_Enrollment* pct_White_or_Caucasian
gen blckenroll = Total_Enrollment* pct_African_American
gen hispenroll = pct_Hispanic* Total_Enrollment

bys NCES_School_Code syear : egen stride_sch_tot = total(Total_Enrollment)
bys NCES_School_Code syear : egen stride_sch_wht = total(whtenroll)
bys NCES_School_Code syear : egen stride_sch_black = total(blckenroll)
bys NCES_School_Code syear : egen stride_sch_hisp = total(hispenroll)

gen stride_pct_white = 100*(stride_sch_wht / stride_sch_tot)
gen stride_pct_black = 100*(stride_sch_black / stride_sch_tot)
gen stride_pct_hispanic = 100*(stride_sch_hisp / stride_sch_tot)
gen stride_pct_other = 100 - stride_pct_white - stride_pct_black - stride_pct_hispanic

gen nearby_sd_per_other = 100 - nearby_sd_per_hispanic - nearby_sd_per_black - nearby_sd_per_white

* Race vars need to line up by postition in globals.
global stride_race stride_pct_black stride_pct_hispanic stride_pct_white stride_pct_other
global neighborhood_sd_race nearby_sd_per_black nearby_sd_per_hispanic nearby_sd_per_white nearby_sd_per_other
global weights Total_Enrollment blckenroll hispenroll whtenroll


///////////////////////////////////////////////////////////////////////////////
// Panel A
///////////////////////////////////////////////////////////////////////////////
estpost summ $stride_race [fw=Total_Enrollment]
eststo c1_pa
total Total_Enrollment

estpost summ $neighborhood_sd_race [fw=Total_Enrollment]
eststo c2_pa

multicluster mymat Total_Enrollment Nearby_LEAID NCES_School_Code


///////////////////////////////////////////////////////////////////////////////
// Panel B
///////////////////////////////////////////////////////////////////////////////
estpost summ $stride_race [fw=blckenroll]
eststo c1_pb
total blckenroll

estpost summ $neighborhood_sd_race [fw=blckenroll]
eststo c2_pb

multicluster mymat_black blckenroll Nearby_LEAID NCES_School_Code

///////////////////////////////////////////////////////////////////////////////
// Panel C
///////////////////////////////////////////////////////////////////////////////
estpost summ $stride_race [fw=hispenroll]
eststo c1_pc
total hispenroll

estpost summ $neighborhood_sd_race [fw=hispenroll]
eststo c2_pc

multicluster mymat_hisp hispenroll Nearby_LEAID NCES_School_Code


///////////////////////////////////////////////////////////////////////////////
// Panel D
///////////////////////////////////////////////////////////////////////////////
estpost summ $stride_race [fw=whtenroll]
eststo c1_pd
total whtenroll

estpost summ $neighborhood_sd_race [fw=whtenroll]
eststo c2_pd

multicluster mymat_white whtenroll Nearby_LEAID NCES_School_Code

///////////////////////////////////////////////////////////////////////////////
// Output

* Get SEs and pvalues from the matrices
mat list mymat
mat list mymat_black
mat list mymat_hisp
mat list mymat_white

esttab 	c1_pa c2_pa	///
		c1_pb c2_pb	///
		c1_pc c2_pc	///
		c1_pd c2_pd	///
		using ".\Output\Tables\Stride_VS_Neighborhood_06282021.csv", replace cells("mean(fmt(4))" "sd(fmt(4))")
		

cap log close