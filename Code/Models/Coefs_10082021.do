do "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Code\Modules\formatcoefs"


////////////////////////////////////////////////////////////////////////////////
// Main models
formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coef_stride_neigh_fe.txt" "stride_neigh" 
tempfile stride_neigh
save `stride_neigh'


formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coef_sch_zip.txt" "sch_zip" 
tempfile sch_zip
save `sch_zip'

formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coef_stridefe.txt" "" 


merge 1:1 coef_labels using `stride_neigh'
rename _merge strid_neigh_merge

merge 1:1 coef_labels using `sch_zip'
rename _merge sch_zip_merge

order coef_label
*outsheet str_coefs se_transform using "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\", comma

do "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Code\Modules\formatcoefs"

///////////////////////////////////////////////////////////////////////////////
// Race Models


///////////
* White
formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_white_stridefe.txt" "wht_stride" 
tempfile wht_stride
save `wht_stride'

formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_white_stride_neigh_fe.txt" "wht_strideneigh" 
tempfile wht_strideneigh
save `wht_strideneigh'

formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_white_stride_zip_fe.txt" "wht_stridezip" 
tempfile wht_stridezip
save `wht_stridezip'



///////////
* Hispanic
formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_hisp_stridefe.txt" "hisp_stride" 
tempfile hisp_stride
save `hisp_stride'

formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_hisp_stride_neigh_fe.txt" "hisp_strideneigh" 
tempfile hisp_strideneigh
save `hisp_strideneigh'

formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_hisp_stride_zip_fe.txt" "hisp_stridezip" 
tempfile hisp_stridezip
save `hisp_stridezip'



///////
* Black

formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_black_stride_neigh_fe.txt" "blck_strideneigh" 
tempfile blck_strideneigh
save `blck_strideneigh'

formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_black_stride_zip_fe.txt" "blck_stridezip" 
tempfile blck_stridezip
save `blck_stridezip'

formatcoefs "C:\Users\trevo\OneDrive - UW\Broadband project Fall 2021\Data\Intermediate\coefs_black_stridefe.txt" "blck_stride" 


////////////////////
// Bring them all together
merge 1:1 coef_labels using `blck_strideneigh'
drop _merge 

merge 1:1 coef_labels using `blck_stridezip'
drop _merge 


merge 1:1 coef_labels using `hisp_stride'
drop _merge 

merge 1:1 coef_labels using `hisp_strideneigh'
drop _merge 

merge 1:1 coef_labels using `hisp_stridezip'
drop _merge 

merge 1:1 coef_labels using `wht_stride'
drop _merge 

merge 1:1 coef_labels using `wht_strideneigh'
drop _merge 

merge 1:1 coef_labels using `wht_stridezip'
drop _merge 

order coef_label