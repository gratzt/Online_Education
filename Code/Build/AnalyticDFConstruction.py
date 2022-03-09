# -*- coding: utf-8 -*-
"""
Created on Wed Mar 17 14:49:05 2021

@author: Trevor Gratz trevormgratz@gmail.com
"""

import pandas as pd
import os
import numpy as np

#############################################################################
# Prep Data

scriptpath = os.path.abspath(os.path.dirname(__file__))
stridepath = os.path.join(scriptpath, "..\..\Data\Stride Inc. Data Pull Request for UofW.xlsx")
zippath = os.path.join(scriptpath,'..\..\Data\Intermediate\catchementzones.csv')

ctch = pd.read_csv(zippath)
ctch.rename(columns={'zip': 'Zip Code', 'NCES School ID': 'NCES School Code'},
            inplace=True)

def mergeCatchmentStride(tab):
    df= pd.read_excel(stridepath, sheet_name=tab)
        
    # Clean Some NCES IDS that were recoreded incorrectly
    namepairs = [('Florida Cyber Charter Academy@Clay', 120030008391), 
                 ('Florida Cyber Charter Academy@Duval' , 120048008228),
                 ('Florida Cyber Charter Academy@Osceola', 120147008079),
                 ('Insight San Diego', 60152813030),
                 ('Insight San Joaquin', 60217113952)]
    for i in namepairs:
        bools = (df['School Name'] == i[0])
        df.loc[df.index[bools], 'NCES School Code'] = i[1]
        
    # Collapse across NCES School ID an Zip Code
    wm = lambda x: np.average(x, weights=df.loc[x.index, "Total Enrollment"])
    f = {'TK (Transitional Kindergarten) Count': ['sum'],
         'Count K-5': ['sum'], 'Count 6-8': ['sum'], 
         'Count 9-12': ['sum'], 'Total Enrollment': ['sum'],  
         '% White or Caucasian': [wm], '% African-American': [wm], 
         '% Asian': [wm], '% American Indian': [wm], '% Hispanic': [wm],
         '% Pacific Islander': [wm], '% Multi-racial': [wm], '% Other': [wm],
         '% Undefined': [wm],
         'School Name': ['first']}
    df = df.groupby(['Zip Code', 'NCES School Code'], as_index=False).agg(f)
    df.columns = df.columns.get_level_values(0)
    df['year'] = '20' + tab[5:7]
    df['year'] = df['year'].astype(int)
    
    df = pd.merge(ctch, df, how='left', on=['NCES School Code', 'Zip Code', 'year'])
    df.drop(index=df.index[df.year != int('20' + tab[5:7])], inplace=True)
   
    df.sort_values(by=['NCES School Code', 'School Name'], inplace=True)
    df['School Name'] = df.groupby('NCES School Code')['School Name'].ffill()
    df['Total Enrollment'].replace(np.nan, 0, inplace=True)

    #Drop Schools with no obs - This is because of the left merge
    df['maxenroll'] = df.groupby('NCES School Code')['Total Enrollment'].transform('max')
    df.drop(index=df.index[df['maxenroll'] == 0], inplace=True)
    df.drop(columns=['maxenroll'], inplace=True)
    return df

# Build Stride and Catchments
stridedf = pd.DataFrame()
tabs = ['2016-17', '2017-18', '2018-19', '2019-20']
for i in tabs:
    tempdf = mergeCatchmentStride(tab=i)
    stridedf = pd.concat([stridedf, tempdf], axis=0, ignore_index=True)
    

############################################################################
# Stack FCC Data
dfpath = os.path.join(scriptpath, f'..\..\Data\FCC_National\collapsed_fcc_2016_V2_zcta.dta')

fcc = pd.read_stata(dfpath)
# fcc year and month are for documentation purpose only
fcc['fcc_year'] = 2016
fcc['fcc_month'] = 'June'
fcc['syear'] = 2016

fcclist = [(2016,'V1', 'zcta'), (2017,'V1', 'zcta'), (2017, 'V2', 'zcta'),
           (2018,'V1', 'zcta'), (2018, 'V2', 'zcta'), (2019, 'V2', 'zcta')]

def buildFCC(fcclist, fcc):
    for i in fcclist:
        dfpath = os.path.join(scriptpath, f'..\..\Data\FCC_National\collapsed_fcc_{i[0]}_{i[1]}_{i[2]}.dta')
        temp = pd.read_stata(dfpath)
        temp['fcc_year'] = i[0]
        if i[1] =='V1':
            temp['fcc_month'] = 'Dec'
            temp['syear'] = i[0] + 1
        else:
            temp['fcc_month'] = 'June'
            temp['syear'] = i[0]
        fcc = pd.concat([fcc, temp], axis=0, ignore_index=True)
    
    fcc.drop(columns=['fcc_year', 'fcc_month'], inplace=True)    
    fcc = fcc.groupby(['zcta5a', 'syear'], as_index=False).mean()
    fcc['mergeYear'] = fcc['syear'] + 1
    return fcc

fcc_zcta = buildFCC(fcclist=fcclist, fcc=fcc)

##############################################################################
# Merge Stride and FCC data
stridedf['year'] = stridedf['year'].astype(int)
analyticdf = pd.merge(stridedf, fcc_zcta, how='inner',
                      left_on=['Zip Code', 'year'],
                      right_on=['zcta5a', 'mergeYear'])

renamedict = {i: i.replace('% ', 'pct_') for i in analyticdf.columns if i[0:2] == '% '}
analyticdf.rename(columns=renamedict, inplace=True)

##############################################################################
# Restrict Analytic file to Zips with more than 0 children from ACS data

def cleanChildPop():
    # Get race percents by zip code to estimate counts of children by race
    racepath = os.path.join(scriptpath, r'..\..\Data/ACS\nhgis0009_csv\nhgis0009_ds244_20195_2019_zcta.csv')
    racedf = pd.read_csv(racepath)
    # Drop zips with zero people
    todrop = racedf['ALUKE001'] == 0
    racedf.drop(index=racedf.index[todrop], inplace=True)
    
    racedf['ALUKE001'] = racedf['ALUKE001'].astype('float')
    racedf['ALUKE012'] = racedf['ALUKE012'].astype('float')
    
    racedf['zip_per_hisp'] = racedf['ALUKE012']/racedf['ALUKE001']
    racedf['zip_per_black'] = racedf['ALUKE004']/racedf['ALUKE001']
    racedf['zip_per_white'] = racedf['ALUKE003']/racedf['ALUKE001']
    racedf['zip_per_other'] = 1 - racedf['zip_per_hisp'] - racedf['zip_per_black'] - racedf['zip_per_white']
    todrop = [i for i in racedf.columns if i not in ['zip_per_hisp', 'zip_per_black',
                                                     'zip_per_white', 'zip_per_other',
                                                     'ZCTA5A']]
    racedf.drop(columns=todrop, inplace=True)
    racedf.rename(columns={'ZCTA5A': 'Zip Code'}, inplace=True)
    
    # Get total number of children
    childpath = os.path.join(scriptpath, r'..\..\Data/ACS\nhgis0007_csv\nhgis0007_ds244_20195_2019_zcta.csv')
    childdf = pd.read_csv(childpath)
    childdf['child_pop'] = 0
    childvars = ['ALT0E003', 'ALT0E004', 'ALT0E005', 'ALT0E006', 'ALT0E027',
                 'ALT0E028', 'ALT0E029', 'ALT0E030']
    for i in childvars:
        childdf['child_pop'] += childdf[i]
    
    tokeep = ['ZCTA5A', 'child_pop']
    todrop = [i for i in childdf.columns if i not in tokeep]
    childdf.drop(columns=todrop, inplace=True)
    childdf.rename(columns={'ZCTA5A': 'Zip Code'}, inplace=True)
    
    todrop = childdf.index[childdf['child_pop'] == 0]
    childdf.drop(index=todrop, inplace=True)
    
    # Calculate race specific counts
    
    childdf = pd.merge(childdf, racedf, how='inner', on='Zip Code')
    childdf['child_pop_black'] = (childdf['child_pop'] * childdf['zip_per_black']).round()
    childdf['child_pop_hisp'] = (childdf['child_pop'] * childdf['zip_per_hisp']).round()
    childdf['child_pop_white'] = (childdf['child_pop'] * childdf['zip_per_white']).round()
    childdf['child_pop_other'] = (childdf['child_pop'] * childdf['zip_per_other']).round()
    return childdf

childdf = cleanChildPop()
analyticdf = pd.merge(analyticdf, childdf, how='outer', on='Zip Code', indicator=True)

##############################################################################
# Add Urbanicity
def rucadata():
    rucapath = os.path.join(scriptpath, r'..\..\Data/RUCA2010zipcode.xlsx')
    rucadf = pd.read_excel(rucapath, sheet_name='Data')
    rucadf.drop(columns=['STATE', 'ZIP_TYPE', 'RUCA2'], inplace=True)
    rucadf.rename(columns = {'ZIP_CODE': 'Zip Code'}, inplace=True)
    return rucadf

rucadf = rucadata()
analyticdf = pd.merge(analyticdf, rucadf, how='inner', on='Zip Code')

mergebool = analyticdf.index[analyticdf['_merge']=='both']
##############################################################################
# Add Income and Race
def incomerace():
    icpath = os.path.join(scriptpath, r'..\..\Data/ACS/nhgis0009_csv\nhgis0009_ds244_20195_2019_zcta.csv')
    icdf = pd.read_csv(icpath)
    icdf['per_white'] = icdf['ALUKE003']/icdf['ALUKE001']    
    icdf['per_black'] = icdf['ALUKE004']/icdf['ALUKE001']    
    icdf['per_aian'] = icdf['ALUKE005']/icdf['ALUKE001']    
    icdf['per_asian'] = icdf['ALUKE006']/icdf['ALUKE001']    
    icdf['per_nhpi'] = icdf['ALUKE007']/icdf['ALUKE001']    
    icdf['per_other'] = icdf['ALUKE008']/icdf['ALUKE001']    
    icdf['per_multi'] = icdf['ALUKE009']/icdf['ALUKE001']    
    icdf['per_hisp'] = icdf['ALUKE012']/icdf['ALUKE001']    
    icdf.rename(columns={'ALW1E001': 'median_income'}, inplace=True)
    icdf['laborParticipation'] = icdf['ALY3E002']/icdf['ALY3E001'] 
    tokeep = ['per_white', 'per_black', 'per_aian', 'per_asian', 'per_nhpi',
              'per_other', 'per_multi', 'per_hisp', 'median_income',
              'laborParticipation', 'ZCTA5A']
    todrop = [i for i in icdf.columns if i not in tokeep]
    icdf.drop(columns=todrop, inplace=True)
    icdf.rename(columns={'ZCTA5A': 'Zip Code'}, inplace=True)
    return icdf

icdf = incomerace()
analyticdf = pd.merge(analyticdf, icdf, how='inner', on='Zip Code')

##############################################################################
# Add Tribal Land Indicator
def addTribal():
    #https://lehd.ces.census.gov/data/lodes/LODES7/LODESTechDoc7.4.pdf
    #https://acsdatacommunity.prb.org/discussion-forum/f/forum/524/getting-a-list-of-zip-codes-in-federally-recognized-native-american-american-indian-reservations
    tribepath = os.path.join(scriptpath, r'..\..\Data/us_xwalk.csv.gz')
    tribedf = pd.read_csv(tribepath, compression='gzip')
    tokeep = ['zcta', 'trib', 'tribname', 'tsub', 'tsubname']
    todrop = [i for i in tribedf.columns if i not in tokeep]
    tribedf.drop(columns=todrop, inplace=True)
    tribedf['zcta'] = tribedf['zcta'].astype(int)
    tribedf['trib'] = tribedf['trib'].str.strip()
    booldrop = tribedf.index[((tribedf['trib']=='99999') |
                             (tribedf['trib'].isna()) |
                             (tribedf['zcta']==99999))]
    tribedf.drop(index=booldrop, inplace=True)
    tribedf.drop(columns=['trib', 'tribname', 'tsub', 'tsubname'], inplace=True)
    tribedf.rename(columns={'zcta': 'Zip Code'}, inplace=True)
    return tribedf.drop_duplicates()
tribedf = addTribal()

analyticdf = pd.merge(analyticdf, tribedf, how='left', on='Zip Code',
                      indicator=True)
analyticdf['triballand'] = analyticdf['_merge'] == 'both'
analyticdf['triballand'] = analyticdf['triballand'].astype(int)
analyticdf.drop(columns=['_merge'], inplace=True)

##############################################################################
# Add Broadband and Computer Access at Home
def addCompInt():
    comppath = os.path.join(scriptpath, r'..\..\Data/ACS/nhgis0010_csv\nhgis0010_ds244_20195_2019_zcta.csv')
    compdf = pd.read_csv(comppath)
    compdf['per_comp'] = compdf['AL1ZE002']/ compdf['AL1ZE001'] 
    compdf['per_broadband'] = compdf['AL1ZE004']/ compdf['AL1ZE001']
    tokeep = ['per_comp', 'per_broadband', 'ZCTA5A']
    todrop = [i for i in compdf.columns if i not in tokeep]
    compdf.drop(columns=todrop, inplace=True)
    compdf.rename(columns={'ZCTA5A': 'Zip Code'}, inplace=True)
    return compdf

compdf = addCompInt()
analyticdf = pd.merge(analyticdf, compdf, how='inner', on='Zip Code')

#############################################################################
## Some NCES School IDs appear to change across the years in the CCD, but
## these schools are the same schools. Create a NCES ID variable that
## will be used to merge to CCD. For sanity, check the names between the Stride
## data and the CCD using these two different NCES IDs. Names are the same.
## These pairings are base off of an email sent on Thomas Norris on March 29,
## 2021.

# Tuples are builT as follows. NCESSID from Stride, the year, NCES ID in CCD for
# that year.

def cleanNCESIDS():
    toreplace = [(60188411996, 2017, 60318011996), (60188411996, 2018, 60318011996),
                 (60171612034, 2017, 64200012034), (60171612034, 2018, 64200012034),
                 (60245114255, 2017, 62382013132), (60245114255, 2018, 62382013132),
                 (60180510641, 2017, 63768010641), (60180510641, 2018, 63768010641),
                 (60199013191, 2017, 62703013191), (60199013191, 2018, 62703013191),
                 (60180211787, 2017, 61887011787), (60180211787, 2018, 61887011787),
                 (60231611478, 2017, 62154011478), (60231611478, 2018, 62154011478),
                 (60181013698, 2017, 62469013698), (60181013698, 2018, 62469013698),
                 (60161614251, 2017, 62853013125), (60161614251, 2018, 62853013125),
                 (80028206752, 2017, 80028206600), (80028206752, 2018, 80028206600),
                 (80028206764, 2017, 80028206600), (80028206764, 2018, 80028206600),
                 (450390901616, 2017, 450390101616), (450390901616, 2018, 450390101616),
                 (60152813030, 2017, 63768013030), (60217113952, 2017, 62703013952),
                 (60174513167, 2017, 62382013167), (60174513167, 2018, 62382013167),
                 (60196412477, 2017, 63375012477), (60196412477, 2018, 63375012477),
                 (450390901513, 2017, 450390101513), (450390901513, 2018, 450390101513)
    ]
    
    analyticdf['ccdMergeID'] = analyticdf['NCES School Code']
    for i in toreplace:
        bools = ((analyticdf['NCES School Code'] == i[0]) &
                 (analyticdf['year'] == i[1]))
        analyticdf.loc[analyticdf.index[bools], 'ccdMergeID'] = i[2]
         
    return analyticdf

analyticdf = cleanNCESIDS()
#############################################################################
## Merge in Seda Data
def sedaclean():
    sedapath = os.path.join(scriptpath, r'..\..\Data\Intermediate\cleanedSeda.dta')
    sedadf = pd.read_stata(sedapath)
    sedadf.rename(columns={'Zip_Code': 'Zip Code'}, inplace=True)
    return sedadf

sedadf = sedaclean()
analyticdf = pd.merge(analyticdf, sedadf, how='left', on='Zip Code')

#############################################################################
## Merge in nearby race/ethnicity of the school district

def add_nearbySD_race():
    ccdpath = os.path.join(scriptpath, '..\..\Data\stacked_ccd.dta')
    zippath = os.path.join(scriptpath, '..\..\Data\Intermediate\SD_Zip_Crosswalk.dta')
    zipdf = pd.read_stata(zippath)
    zipdf.drop(columns=['index', 'ELSDLEA', 'SCSDLEA', 'UNSDLEA', 'NAME'],
               inplace=True)
    zipdf['GEOID'] = zipdf['GEOID'].astype(int)
    zipdf['ZCTA5CE10'] = zipdf['ZCTA5CE10'].astype(int)
    
    ccd = pd.read_stata(ccdpath)
    bools = ((ccd['School_Total_Enrollment'].isna()) |
            (ccd['School_Total_Enrollment'] == 0))
    ccd.drop(index=ccd.index[bools], inplace=True)
    
    w_ave = lambda x: np.average(x, weights=ccd.loc[x.index, 'School_Total_Enrollment'])
    
    aggdict = {'per_female': [w_ave], 'per_male': [w_ave],
               'per_nativeamerican': [w_ave], 'per_asian': [w_ave],
               'per_black': [w_ave], 'per_hispanic': [w_ave], 'per_nhpi': [w_ave],
               'per_multiracial': [w_ave],'per_white': [w_ave],
               'per_frpl': [w_ave],
               '_virtual': 'max', 'partime_virtual': 'max',
               'School_Total_Enrollment': 'sum'}
    
    distdf = ccd.groupby(['LEAID', 'ST', 'year']).agg(aggdict)
    distdf.columns = distdf.columns.get_level_values(0)
    renamedict = {i: "nearby_sd_" + i for i in distdf.columns[:-1]}
    renamedict['School_Total_Enrollment'] = 'nearby_dist_enrollment'
    distdf.rename(columns=renamedict, inplace=True)
    distdf.reset_index(inplace=True)
    
    nearbydf = pd.merge(zipdf, distdf, how='inner',
                    left_on='GEOID', right_on='LEAID')
    nearbydf.rename(columns={'LEAID': 'Nearby_LEAID', 'ZCTA5CE10': 'Zip Code'}
                    , inplace=True)
    nearbydf.drop(columns='GEOID', inplace=True)
    return nearbydf

nearbydf = add_nearbySD_race()
nearbydf_lag = nearbydf.copy()
nearbydf_lag['year'] += 1
nearbydf_lag.drop(columns=['Nearby_LEAID', 'ST'], inplace=True)
renamedict = {i: i+"_lag" for i in nearbydf_lag.columns if i not in ['Zip Code', 'year']}
nearbydf_lag.rename(columns=renamedict, inplace=True)

analyticdf = pd.merge(analyticdf, nearbydf, how = 'left', on = ['Zip Code', 'year'])
analyticdf = pd.merge(analyticdf, nearbydf_lag, how = 'left', on = ['Zip Code', 'year'])

##############################################################################
# Varialbe creation and dummy Variables with missing

# first create a few more vars used in the regressions
analyticdf['nearby_sd_per_other']  = analyticdf[['nearby_sd_per_nativeamerican',
                                                 'nearby_sd_per_asian',
                                                 'nearby_sd_per_nhpi',
                                                 'nearby_sd_per_multiracial']].sum(axis=1)
							 
analyticdf['nearby_sd_per_other_lag']  = analyticdf[['nearby_sd_per_nativeamerican_lag',
                                                 'nearby_sd_per_asian_lag',
                                                 'nearby_sd_per_nhpi_lag',
                                                 'nearby_sd_per_multiracial_lag']].sum(axis=1)

analyticdf['achievement'] = analyticdf[['cs_mn_allmth', 'cs_mn_allrla']].mean(axis=1)
analyticdf['achievement_blk'] = analyticdf[['cs_mn_blkmth', 'cs_mn_blkrla']].mean(axis=1)
analyticdf['achievement_hsp'] = analyticdf[['cs_mn_hspmth', 'cs_mn_hsprla']].mean(axis=1)
analyticdf['achievement_wht'] = analyticdf[['cs_mn_whtmth', 'cs_mn_whtrla']].mean(axis=1)

urbanbool = analyticdf['RUCA1'].isin([1, 2, 3])
micropolbool = analyticdf['RUCA1'].isin([4, 5, 6]) 
townbool = analyticdf['RUCA1'].isin([ 7, 8, 9])
ruralbool = analyticdf['RUCA1'].isin([10])

analyticdf.loc[analyticdf.index[urbanbool], 'urbanicity'] = 1 
analyticdf.loc[analyticdf.index[micropolbool], 'urbanicity'] = 2 
analyticdf.loc[analyticdf.index[townbool], 'urbanicity'] = 3 
analyticdf.loc[analyticdf.index[ruralbool], 'urbanicity'] = 4 


def mis_dummy(df, var, categorical=False):
    if categorical == False:
        bools = df[var].isna()
        df['missing_' + str(var)] = bools
        df['missing_' + str(var)] = df['missing_' + str(var)].astype(int)
        df.loc[df.index[bools],var] = 0
    else:
        newcat = df[var].max() + 1
        df[var] = df[var].replace(np.nan, newcat)
        print(f'The missing category for {var} is {newcat}')
    return df


dummyvars = [ 'median_income', 'nearby_dist_enrollment', 'nearby_sd__virtual',
             'nearby_sd_partime_virtual', 'nearby_sd_per_black',
             'nearby_sd_per_hispanic', 'nearby_sd_per_other',
             'nearby_dist_enrollment_lag', 'nearby_sd__virtual_lag',
             'nearby_sd_partime_virtual_lag', 'nearby_sd_per_black_lag',
             'nearby_sd_per_hispanic_lag', 'nearby_sd_per_other_lag',
             'achievement', 'achievement_blk', 'achievement_hsp',
             'achievement_wht']
for i in dummyvars:
    analyticdf = mis_dummy(analyticdf, i)

analyticdf = mis_dummy(analyticdf, 'urbanicity', categorical=True)

##############################################################################
## Create School Type Flags
analyticdf['elemcount'] = analyticdf[['NCES School Code', 'year', 'Count K-5']].groupby(['NCES School Code', 'year']).transform(sum)
analyticdf['elem_flag'] = (analyticdf['elemcount'] >=10).astype(int)

analyticdf['mscount'] = analyticdf[['NCES School Code', 'year', 'Count 6-8']].groupby(['NCES School Code', 'year']).transform(sum)
analyticdf['ms_flag'] = (analyticdf['mscount'] >=10).astype(int)

analyticdf['highcount'] = analyticdf[['NCES School Code', 'year', 'Count 9-12']].groupby(['NCES School Code', 'year']).transform(sum)
analyticdf['high_flag'] = (analyticdf['highcount'] >=10).astype(int)

analyticdf.drop(columns=['elemcount', 'mscount', 'highcount'], inplace=True)

# ~ 500 zip codes were linked to school districts in the EDGE data that 
# had not corresponding data in the CCD. Drop these since we use CCD in most
# of our analyses.
analyticdf.drop(index=analyticdf.index[analyticdf['Nearby_LEAID'].isna()],
                inplace=True)

# Standardized achiement on this dataset.
for i in ['achievement', 'achievement_blk', 'achievement_hsp','achievement_wht'] :
    analyticdf[i] = (analyticdf[i] - analyticdf[i].mean())/analyticdf[i].std() 

##############################################################################
# Final Dataset
dfout = os.path.join(scriptpath,'..\..\Data\Stride_AnalyticDf.dta')
analyticdf.to_stata(dfout)
