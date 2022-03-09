* This code implements a conditional Poisson model for the Online Ed paper, with
* Bootstrapping. It runs the main models when arguement 5 is "N", and calculates
* coeff differences across models when 5 is "Y". To do this latter part, the coeffs
* must appear in the exact same order in both models.

// Arguements
* 1) The number of bootstraps
* 2) The fixed effect variable.
* 3) Dependent Varibale 1
* 4) Independent variables 1
* 5) Difference model Y/N
* 6) Dependent Varibale 2
* 7) Independent variables 2
* 8) File name for Coef matrix 1
* 9) File name for Coef matrix 2
* 10) File name for diff matrix 


cap program drop pois_boot
program define pois_boot

		cap xtclear, clear
		xtset `2'
		forvalues y = 1/`1'{
			preserve
				set seed `y'
				bsample, cluster(sch_zip)
				* Weights need to be constant within fixed effects
				* Fixed effects can be unbalanced since schools can have
				* a different number of years, and/or a different number of
				* zips nested under them. Thus, average the childpop variable
				* at the fixed effect level. 
				cap drop pop_weight
				bys `2' : egen pop_weight = mean(child_pop)
				xtpoisson `3' `4' , fe exposure(child_pop) irr 

				if `y' == 1{
					mat coefs = e(b)'
				}
				else{
					mat coefs = coefs, e(b)'
				}
				
				if "`5'" == "Y"{
					xtpoisson `6' `7' , fe exposure(child_pop) irr
					if `y' == 1{
						mat coefs2 = e(b)'
						mat diffs = coefs - coefs2
					}
					else{
						mat coefs2 = coefs2, e(b)'
						mat diffs = coefs - coefs2
					}
				}
				
			restore
		}
	
	
	mat2txt, matrix(coefs) saving(`8') replace
	if "`5'" == "Y"{
		mat2txt, matrix(coefs2) saving(`9') replace
		mat2txt, matrix(diffs) saving(`10') replace

	}
	cap xtclear, clear
	cap drop pop_weight
end
