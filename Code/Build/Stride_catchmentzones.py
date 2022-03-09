# -*- coding: utf-8 -*-
"""
Created on Wed Mar 17 10:30:17 2021

@author: Trevor Gratz trevormgratz@gmail.com
"""

import pandas as pd
import os

#############################################################################
# Prep Data

scriptpath = os.path.abspath(os.path.dirname(__file__))
stridepath = os.path.join(scriptpath, "..\..\Data\Stride Inc. Data Pull Request for UofW.xlsx")
zippath = os.path.join(scriptpath,'..\..\Data\zip_code_database.csv')

df= pd.read_excel(stridepath,sheet_name='Catchement')
df.rename(columns={'State': 'state'}, inplace=True)

# Downloaded from https://www.unitedstateszipcodes.org/
zips = pd.read_csv(zippath)


def buildcatchment():
    zipstate = zips[['zip', 'state']].copy()
    catchement = pd.merge(zipstate, df, how='inner', on='state', validate="m:m")
    todrop = [i for i in catchement.columns if i not in ['zip', 'NCES School ID']]
    catchement.drop(columns=todrop, inplace=True)
    return catchement 

catchement = buildcatchment()

# California schools have catchement zones for contiguous counties.
def schoolcountycombo():
    zipcounty = zips[['zip', 'state', 'county']].copy()
    #####################################################
    # Get all combinations of CAVA Schools and counties
    
    county_sch_dict = {60188411996: ['Fresno', 'Kern', 'Kings', 'Monterey',
                                     'San Luis Obispo','Tulare'],
                       60171612034: ['Kern', 'Los Angeles', 'Orange',
                                     'San Bernardino', 'Ventura'],
                       60245114255: ['Inyo', 'Kern', 'Kings',  'Los Angeles',
                                     'San Bernardino', 'San Luis Obispo',
                                     'Santa Barbara', 'Tulare', 'Ventura'],
                       60180510641: ['Imperial', 'Orange', 'Riverside',
                                     'San Diego'],
                       60199013191: ['Alameda', 'Amador', 'Calaveras',
                                     'Contra Costa', 'Sacramento', 'San Joaquin',
                                     'Santa Clara', 'Solano', 'Stanislaus'],
                       60180211787: ['Alameda', 'Contra Costa', 'San Francisco',
                                     'San Mateo', 'Santa Clara', 'Santa Cruz'],
                       60231611478: ['Lake', 'Marin', 'Mendocino', 'Napa',
                                     'Solano',	'Sonoma'],
                       60181013698: ['Butte', 'Colusa', 'Placer', 'Sacramento',
                                     'Sutter', 'Yolo', 'Yuba'],
                       60161614251: ['Fresno', 'Inyo', 'Kings', 'Madera',
                                     'Merced', 'Mono',	'Monterey',
                                     'San Benito', 'Tulare']}

    cadf = []
    for i in county_sch_dict:
       for j in county_sch_dict[i]:
            cadf.append({'NCES School ID': i, 'county': j, 'state': 'CA'})
            
    
    ##################################
    # Add Insight Schools of California

    county_sch_dict = {60174513167: ['Los Angeles', 'Kern', 'San Bernardino',
                                     'Ventura', 'Imperial', 'Inyo', 'Tulare',
                                     'Kings', 'San Luis Obispo', 'Santa Barbara',
                                     'Orange', 'Riverside', 'San Diego',
                                     'Alameda', 'Amador', 'Calaveras',
                                     'Contra Costa', 'San Joaquin',
                                     'Stanislaus', 'Sacramento',
                                     'Santa Clara'],
                       60152813030:['Imperial', 'Orange', 'Riverside',
                                    'San Diego'],
                       60217113952:['Alameda', 'Amador', 'Contra Costa',
                                    'Sacramento', 'San Joaquin',
                                    'Santa Clara', 'Stanislaus']}
    for i in county_sch_dict:
       for j in county_sch_dict[i]:
            cadf.append({'NCES School ID': i, 'county': j, 'state': 'CA'})
    
    ###########################
    # Add CA iQ Academy
    cadf.append({'NCES School ID': 60196412477, 'county': 'Los Angeles', 'state': 'CA'})    
    cadf.append({'NCES School ID': 60196412477, 'county': 'Ventura', 'state': 'CA'})   
    cadf.append({'NCES School ID': 60196412477, 'county': 'San Bernardino', 'state': 'CA'})    
    cadf.append({'NCES School ID': 60196412477, 'county': 'Kern', 'state': 'CA'})    
    cadf.append({'NCES School ID': 60196412477, 'county': 'Orange', 'state': 'CA'})    
    
    
    cadf = pd.DataFrame(cadf)
    cadf['county'] += ' County'
    
    calzips = pd.merge(zipcounty, cadf, on=['state', 'county'], how='inner')
    return calzips.drop(columns=['state', 'county'])

def cleanFlorida():
    #####################
    # Add Florida Schools
    # COUNTY LEVEL
    zipcounty = zips[['zip', 'state', 'county']].copy()
    fldf = []
    fldf.append({'NCES School ID': 120030008391, 'county': 'Clay', 'state': 'FL', 'year': 2017})    
    fldf.append({'NCES School ID': 120048008228, 'county': 'Duval', 'state': 'FL', 'year': 2017}) 
    fldf.append({'NCES School ID': 120048008228, 'county': 'Duval', 'state': 'FL', 'year': 2018})    
    fldf.append({'NCES School ID': 120147008079, 'county': 'Osceola', 'state': 'FL', 'year': 2017})    
    fldf = pd.DataFrame(fldf)
    fldf['county'] += ' County'
     
    flzips1 = pd.merge(zipcounty, fldf, on=['state', 'county'], how='inner')
    
    # STATE LEVEL
    fldf = []
    fldf.append({'NCES School ID': 120030008391, 'state': 'FL', 'year': 2018})   
    fldf.append({'NCES School ID': 120030008391, 'state': 'FL', 'year': 2019})   
    fldf.append({'NCES School ID': 120030008391, 'state': 'FL', 'year': 2020})   
    fldf.append({'NCES School ID': 120048008228, 'state': 'FL', 'year': 2019}) 
    fldf.append({'NCES School ID': 120048008228, 'state': 'FL', 'year': 2020}) 
    fldf.append({'NCES School ID': 120147008079, 'state': 'FL', 'year': 2018})    
    fldf.append({'NCES School ID': 120147008079, 'state': 'FL', 'year': 2019})    
    fldf.append({'NCES School ID': 120147008079, 'state': 'FL', 'year': 2020})    
    
    fldf = pd.DataFrame(fldf)
    flzips2 = pd.merge(zipcounty, fldf, on=['state'], how='inner')

    flzips = pd.concat([flzips1, flzips2], axis=0, ignore_index=True)
    
    return flzips.drop(columns=['state', 'county'])

#############################################################################
    
caschools = schoolcountycombo()
catchement = pd.concat([catchement, caschools], axis=0, ignore_index=True)

# Build a long dataset with year obs
def addyears():
    c2017  = catchement.copy()
    c2017['year'] = 2017
    c2018  = catchement.copy()
    c2018['year'] = 2018
    c2019  = catchement.copy()
    c2019['year'] = 2019
    c2020  = catchement.copy()
    c2020['year'] = 2020
    
    okay = pd.concat([c2017, c2018, c2019, c2020],
                     axis=0, ignore_index=True)
    
    return okay

catchement = addyears()

# Drop Insight schools with missing years
dropbool = (((catchement['year'].isin([2018, 2019, 2020])) &
             (catchement['NCES School ID'].isin([60152813030, 60217113952]))) |
            ((catchement['year'] == 2020) &
             (catchement['NCES School ID'] == 60174513167)))
catchement.drop(index=catchement.index[dropbool], inplace=True)

# Add Florida Data
fldf = cleanFlorida()

catchement = pd.concat([catchement, fldf], axis=0, ignore_index = True) 

outpath = os.path.join(scriptpath, '..\..\Data\Intermediate\catchementzones.csv')
catchement.to_csv(outpath, index=False)