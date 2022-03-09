# -*- coding: utf-8 -*-
"""
Created on Wed Apr  7 16:15:09 2021

@author: Trevor Gratz trevormgratz@gmail.com
"""

import geopandas as gpd
import os
import pandas as pd
import numpy as np

scriptpath = os.path.abspath(os.path.dirname(__file__))
tlpath = os.path.join(scriptpath, r'..\..\Data\TigerLines\tl_2019_us_zcta510.shp')

# Data from: https://nces.ed.gov/programs/edge/Geographic/DistrictBoundaries
# Note in the user notes that there is no 2016-17 school year file. Use the
# 2017-18 file.
sdpath = os.path.join(scriptpath, r'..\..\Data\SchoolDistrict_Shape\2018\schooldistrict_sy1718_tl18.shp')

tldf = gpd.read_file(tlpath)
tldf['zip_area'] = tldf.area

sddf = gpd.read_file(sdpath)
sddf['GEOID'] = sddf['GEOID'].astype(int)
sddf['geometry'] = sddf.buffer(0)

##############################################################################
# Merge
# Both are EPSG:4269
test = gpd.sjoin(tldf, sddf, how='inner', op = 'intersects')

# Get the number of unique school districts per zip code.
test['n_sd_perzip'] = test[['ZCTA5CE10', 'GEOID']].groupby('ZCTA5CE10').transform('nunique')

##########################################################################
## For Zip codes that intersect multiple School Districts select the school
## district with the most overlap.
test=test.reset_index()
def get_size_of_intersection(row, sddf):
    return row['geometry'].intersection(sddf['geometry'].iloc[int(row['index_right'])]).area

test['intersection_size'] = test.apply(lambda row : 
                                       get_size_of_intersection(row, sddf), axis=1)

        
test['max_intersection_size'] = test.groupby('ZCTA5CE10')['intersection_size'].transform(max)
test.reset_index(inplace=True)
bools = (test['intersection_size'] != test['max_intersection_size'])
test.drop(index=test.index[bools], inplace=True)

##############################################################################
# 626 Zip codes share the same area overlap. Randomly select a district to
# assign them to.
test['random'] = np.random.uniform(0,1, len(test))
test.sort_values(by=['ZCTA5CE10' ,'random'], inplace=True)
test.drop_duplicates(subset='ZCTA5CE10', keep='first', inplace=True)
test['sd_area_percent'] = test['intersection_size']/test['zip_area']
                                                         
todrop = [i for i in test.columns if i not in ['ZCTA5CE10', 'ELSDLEA',
                                               'SCSDLEA', 'UNSDLEA', 'GEOID',
                                               'NAME', 'n_sd_perzip',
                                               'intersection_size', 'zip_area',
                                               'sd_area_percent']]

test.drop(columns=todrop, inplace = True)
dfout = os.path.join(scriptpath, r'..\..\Data\Intermediate\SD_Zip_Crosswalk.dta')
test.to_stata(dfout)