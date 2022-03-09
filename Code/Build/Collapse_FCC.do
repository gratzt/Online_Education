////////////////////////////////////////////////////////////////////////////////
// ZCTA Level
* NOTE: V1 and V2 did not perfectly line up with months. Changed V1 and V2 in the
* names of these data files to line up with the months.
local years " 2016 2017 2018 2019 2020"
local versions "V2 V1"

foreach x of local versions {
	foreach y of local years {
		
		if "`x'" == "V1" {
			local month "Dec"
		}
		if "`x'" == "V2" {
			local month "June"			
		}
		
		display "`x'"
		display "`y'"
		display "`month'"
		
		import delimited "G:\Personal\Broadband\Fixed_Broadband_Deployment_Data__`month'__`y'_Status_`x'.csv", clear 

		
		keep if consumer == 1
	
		cap rename (maxadvertisedupstreamspeedmbps) (maxadup)
		cap rename (maxadvertiseddownstreamspeedmbps) (maxaddown)

		cap rename (censusblockfipscode) (blockcode)
		cap destring maxaddown maxadup, replace

		keep blockcode providerid maxaddown maxadup
		
				
		tostring blockcode , gen(ids) format("%015.0f")
		replace ids = trim(ids)
		gen TRACT = substr(ids, 1, 11)
	
		* COLLAPSE TO THE TRACT LEVEL - i.e. across providers and blocks.
		egen ptag = tag(TRACT providerid)

		collapse (min) min_down=maxaddown min_up=maxadup (max) max_down=maxaddown max_up=maxadup (mean) mean_down=maxaddown mean_up=maxadup (sum) n_providers = ptag, by(TRACT)
				 
		merge 1:m TRACT using "G:\Personal\Broadband\ZCTA_crosswalk.dta"
		keep if _merge == 3
		drop _merge
		

		 collapse (p25) p25_down=mean_down p25_up=mean_up (p75) p75_down=mean_down p75_up=mean_up (mean) mean_down=mean_down mean_up=mean_up min_down=min_down min_up=min_up  max_down=max_down max_up=max_up n_providers [aweight=RES_RATIO], by(zcta5a)

		compress
		save "G:\Personal\Broadband\Cleaned_data\collapsed_fcc_`y'_`x'_zcta.dta", replace
	}
}
	