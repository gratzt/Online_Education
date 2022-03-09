# -*- coding: utf-8 -*-
"""
Created on Tue Mar 23 15:41:03 2021

@author: Trevor Gratz trevormgratz@gmail.com
"""
import os
import pandas as pd
import numpy as np

scriptpath = os.path.abspath(os.path.dirname(__file__))

##############################################################################
## Clean FRPL

def cleanFRPL(path, year):
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\FRPL\{path}")
    df = pd.read_csv(dfpath, encoding='latin1')
    df['year'] = year
    # Total FRPL - Note Delaware, Tennessee, and Massachusetts
    # only report direct certification, not FRPL.
    todrop = df.index[df['LUNCH_PROGRAM'] != "No Category Codes"]
    df.drop(index=todrop, inplace=True)
    tokeep = ['NCESSCH' ,'year', 'STUDENT_COUNT']
    todrop = [i for i in df.columns if i not in tokeep]
    df.drop(columns=todrop, inplace=True)
    return df

def cleanFRPL_before2017(path, year):
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\FRPL\{path}")
    if yr == 2015:
        df = pd.read_csv(dfpath, encoding='latin1', sep='\t')    
    else:
        df = pd.read_csv(dfpath, encoding='latin1')    
    df['year'] = year
    # Total FRPL - Note Delaware, Tennessee, and Massachusetts
    # only report direct certification, not FRPL.
    df.replace([-1, -2, -3, -4, -5, -6, -7,-8, -9], np.nan, inplace=True)

    df.rename(columns={'TOTFRL': 'STUDENT_COUNT'}, inplace=True)
    tokeep = ['NCESSCH' ,'year', 'STUDENT_COUNT']
    todrop = [i for i in df.columns if i not in tokeep]
    df.drop(columns=todrop, inplace=True)
    df['STUDENT_COUNT'] = df['STUDENT_COUNT'].replace(-1, np.nan)
    return df


##############################################################################
## Clean School Characteristics - Get Virtual School Data

def cleanSch(path, year):
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\SchoolCharacteristics\{path}")
    df = pd.read_csv(dfpath, encoding='latin1')
    df['year'] = year
    
    df['virtual'] = df['VIRTUAL_TEXT'].isin(['Exclusively virtual',
                                             'Full Virtual',
                                             ]).astype(int)
    df['partime_virtual'] = df['VIRTUAL_TEXT'].isin(['Supplemental Virtual',
                                                     'Virtual with face to face options',
                                                     'Primarily virtual'
                                                     ]).astype(int)
    df['not_virtual'] = df['VIRTUAL_TEXT'].isin(['Not Virtual',
                                                 'No virtual instruction'
                                                 ]).astype(int)
    df['missing_virtual'] = df['VIRTUAL_TEXT'].isin(['Missing',
                                                     'Not reported'
                                                     ]).astype(int) 
    tokeep = ['LEAID', 'NCESSCH', 'year', 'virtual', 'partime_virtual',
              'not_virtual', 'missing_virtual', 'ST', 'VIRTUAL_TEXT', 
              'SCH_NAME', 'ST_SCHID']
    todrop = [i for i in df.columns if i not in tokeep]
    df.drop(columns=todrop, inplace=True)
    return df


def cleanSch_before2017(path, year):
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\Directory\{path}")
    if yr == 2015:
        df = pd.read_csv(dfpath, encoding='latin1', sep='\t')
    else:
        df = pd.read_csv(dfpath, encoding='latin1')
    df['year'] = year
    df.replace([-1, -2, -3, -4, -5, -6, -7,-8, -9], np.nan, inplace=True)

    df['virtual'] = df['VIRTUAL'].isin(['Yes']).astype(int)
    df['partime_virtual'] = np.nan
    df['not_virtual'] = df['VIRTUAL'].isin(['No']).astype(int)
    df['missing_virtual'] = df['VIRTUAL'].isin(['Missing']).astype(int)
    df['VIRTUAL_TEXT'] = np.nan
    df.rename(columns={'STABR': 'ST'}, inplace=True)
    tokeep = ['LEAID', 'NCESSCH', 'year', 'virtual', 'partime_virtual',
              'not_virtual', 'missing_virtual', 'ST', 'VIRTUAL_TEXT',
              'SCH_NAME', 'ST_SCHID']
    todrop = [i for i in df.columns if i not in tokeep]
    df.drop(columns=todrop, inplace=True)
    return df

##############################################################################
## Clean Gender Data

def cleanGender(path, year):
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\StudentCharacteristics\{path}")
    df = pd.read_csv(dfpath, encoding='latin1')
    df['year'] = year
    if 'RACE_ETHNICITY' in df.columns:
        df.rename(columns={'RACE_ETHNICITY': 'RACE'}, inplace=True)
    
    # Grab Total Enrollment 
    tedf = df.copy()
    todrop = ~((tedf['GRADE'] == 'No Category Codes') &
               (tedf['RACE'] == 'No Category Codes') &
               (tedf['SEX'] == 'No Category Codes') &
               (tedf['TOTAL_INDICATOR'] == 'Derived - Education Unit Total minus Adult Education Count'))
    tedf.drop(index=tedf.index[todrop], inplace=True)
    tedf.rename(columns={'STUDENT_COUNT': 'School_Total_Enrollment'}, inplace=True)
    todrop = [ i for i in tedf.columns if i not in ['NCESSCH', 'School_Total_Enrollment']]
    tedf.drop(columns=todrop, inplace=True)
    
    # Get Gender Specific Enrollment           
    todrop = ((df['GRADE'] == 'No Category Codes')  | 
              (df['GRADE'] == 'Adult Education')    |
              (df['GRADE'] == 'Ungraded')           |
              (df['RACE'] == 'No Category Codes')   |
              (df['SEX'] == 'No Category Codes')    |    
              (df['SEX'] == 'Not Specified'))
    df.drop(index=df.index[todrop], inplace=True)
    df = df[['NCESSCH', 'year', 'SEX', 'STUDENT_COUNT']].groupby(['NCESSCH', 'year', 'SEX']).sum()
    df = df.unstack('SEX')            
    df.columns = df.columns.get_level_values(1) + '_count'
    df.reset_index(inplace=True)
    # Check Gender_totalenrollment against other enrollment counts
    df['gender_totalenrollment'] = df['Female_count'] + df['Male_count']
    df['per_female'] = 100 * (df['Female_count'] / df['gender_totalenrollment'])
    df['per_male'] = 100 * (df['Male_count'] / df['gender_totalenrollment'])
    df.drop(columns=['Female_count', 'Male_count'], inplace=True)
    df = pd.merge(df, tedf, on='NCESSCH', how='inner')
    return df


def cleanGender_before2017(path, year):
    #-2 = not applicable, -1 = missing
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\StudentCharacteristics\{path}")
    if yr == 2015:
        df = pd.read_csv(dfpath, encoding='latin1', sep='\t')    
    else:
        df = pd.read_csv(dfpath, encoding='latin1')
    df['year'] = year
   
    df.replace([-1, -2, -3, -4, -5, -6, -7,-8, -9], np.nan, inplace=True)
    # Grab Total Enrollment 

    flist = ['AMALF', 'ASALF', 'HIALF', 'BLALF', 'WHALF', 'HPALF', 'TRALF']
    mlist = ['AMALM', 'ASALM', 'HIALM', 'BLALM', 'WHALM', 'HPALM', 'TRALM']

    df['numfemale'] = df[flist].sum(axis=1)
    df['per_female'] = 100*(df['numfemale']/df['MEMBER'])
    
    df['nummale'] = df[mlist].sum(axis=1)
    df['per_male'] =100*(df['nummale']/df['MEMBER']) 
    
    df['gender_totalenrollment'] = df['numfemale'] + df['nummale']
    
    df.rename(columns={'MEMBER': 'School_Total_Enrollment'}, inplace=True)
    tokeep = ['NCESSCH', 'year', 'gender_totalenrollment', 'per_female',
              'per_male', 'School_Total_Enrollment']
    todrop = [i for i in df.columns if i not in tokeep]
    df.drop(columns=todrop, inplace=True)
    
    return df
##############################################################################
## Clean Race and Ethnicity 
def cleanRace(path, year):
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\StudentCharacteristics\{path}")
    df = pd.read_csv(dfpath, encoding='latin1')
    df['year'] = year
    
    if 'RACE_ETHNICITY' in df.columns:
        df.rename(columns={'RACE_ETHNICITY': 'RACE'}, inplace=True)  
        
    todrop = ((df['GRADE'] != 'No Category Codes')  | 
              (df['RACE'] == 'No Category Codes')   |
              (df['RACE'] == 'Not Specified')       |
              (df['SEX'] == 'No Category Codes'))

    df.drop(index=df.index[todrop], inplace=True)
    df = df[['NCESSCH', 'year', 'RACE', 'STUDENT_COUNT']].groupby(['NCESSCH', 'year', 'RACE']).sum()
    df = df.unstack('RACE')
    df.columns = df.columns.get_level_values(1) + '_count'
    df.reset_index(inplace=True)
    df['race_totalenrollment'] = df[['American Indian or Alaska Native_count',
                                     'Asian_count', 'Black or African American_count',
                                     'Hispanic/Latino_count',
                                     'Native Hawaiian or Other Pacific Islander_count',
                                     'Two or more races_count', 'White_count']].sum(axis=1) 
    
    df['per_nativeamerican'] = 100*(df['American Indian or Alaska Native_count']/ df['race_totalenrollment'])
    df['per_asian'] = 100*(df['Asian_count']/ df['race_totalenrollment'])
    df['per_black'] = 100*(df['Black or African American_count']/ df['race_totalenrollment'])
    df['per_hispanic'] = 100*(df['Hispanic/Latino_count']/ df['race_totalenrollment'])
    df['per_nhpi'] = 100*(df['Native Hawaiian or Other Pacific Islander_count']/ df['race_totalenrollment'])
    df['per_multiracial'] = 100*(df['Two or more races_count']/ df['race_totalenrollment'])
    df['per_white'] = 100*(df['White_count']/ df['race_totalenrollment'])
    
    df.drop(columns=['American Indian or Alaska Native_count',
                     'Asian_count', 'Black or African American_count',
                     'Hispanic/Latino_count',
                     'Native Hawaiian or Other Pacific Islander_count',
                     'Two or more races_count', 'White_count',], inplace=True)
    return df



def cleanRace_before2017(path, year):
    #-2 = not applicable, -1 = missing
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\StudentCharacteristics\{path}")
    if yr == 2015:
        df = pd.read_csv(dfpath, encoding='latin1', sep='\t')    
    else:
        df = pd.read_csv(dfpath, encoding='latin1')
    df['year'] = year
   
    df.replace([-1, -2, -3, -4, -5, -6, -7,-8, -9], np.nan, inplace=True)
    # Grab Total Enrollment 

    df['per_nativeamerican'] = 100*(df['AM']/df['MEMBER'])
    df['per_asian'] = 100*(df['AS']/df['MEMBER'])
    df['per_hispanic'] = 100*(df['HI']/df['MEMBER'])
    df['per_black'] = 100*(df['BL']/df['MEMBER'])
    df['per_white'] = 100*(df['WH']/df['MEMBER'])
    df['per_nhpi'] = 100*(df['HP']/df['MEMBER'])
    df['per_multiracial'] = 100*(df['TR']/df['MEMBER'])
    
    df['race_totalenrollment'] = df[['AM', 'AS', 'HI', 'BL', 'WH', 'HP', 'TR']
                                    ].sum(axis=1)

    tokeep = ['NCESSCH', 'year', 'race_totalenrollment', 'per_nativeamerican',
              'per_asian', 'per_black', 'per_hispanic', 'per_nhpi',
              'per_multiracial', 'per_white']
    todrop = [i for i in df.columns if i not in tokeep]
    df.drop(columns=todrop, inplace=True)
    
    return df

##############################################################################
## Clean PSU

def cleanPSU(path, year):
    #-2 = not applicable, -1 = missing
    dfpath = os.path.join(scriptpath, f"..\..\Data\CCD\PSU\{path}")
    df = pd.read_csv(dfpath, encoding='latin1', sep='\t')
    df['year'] = year
    df.replace([-1, -2], np.nan, inplace=True)
    
    df['per_nativeamerican'] = 100*(df['AM']/df['MEMBER'])
    df['per_asian'] = 100*(df['ASIAN']/df['MEMBER'])
    df['per_hispanic'] = 100*(df['HISP']/df['MEMBER'])
    df['per_black'] = 100*(df['BLACK']/df['MEMBER'])
    df['per_white'] = 100*(df['WHITE']/df['MEMBER'])
    df['per_nhpi'] = 100*(df['PACIFIC']/df['MEMBER'])
    df['per_multiracial'] = 100*(df['TR']/df['MEMBER'])
    
    df['race_totalenrollment'] = df[['AM', 'ASIAN', 'HISP', 'BLACK', 'WHITE', 
                                     'PACIFIC', 'TR']].sum(axis=1)
    
    flist = ['AMALF', 'ASALF', 'HIALF', 'BLALF', 'WHALF', 'HPALF', 'TRALF']
    mlist = ['AMALM', 'ASALM', 'HIALM', 'BLALM', 'WHALM', 'HPALM', 'TRALM']

    df['numfemale'] = df[flist].sum(axis=1)
    df['per_female'] = 100*(df['numfemale']/df['MEMBER'])
    
    df['nummale'] = df[mlist].sum(axis=1)
    df['per_male'] =100*(df['nummale']/df['MEMBER']) 
    
    df['gender_totalenrollment'] = df['numfemale'] + df['nummale']
    
    df['virtual'] = df['VIRTUALSTAT'].isin(['VIRTUALYES']).astype(int)
    df['partime_virtual'] = np.nan
    df['not_virtual'] = df['VIRTUALSTAT'].isin(['VIRTUALNO']).astype(int)
    df['missing_virtual'] = df['VIRTUALSTAT'].isin(['N']).astype(int)
    df['VIRTUAL_TEXT'] = np.nan
    
    df.rename(columns={'MEMBER': 'School_Total_Enrollment'}, inplace=True)
    df.rename(columns={'TOTFRL': 'STUDENT_COUNT'}, inplace=True)
    df.rename(columns={'MSTATE': 'ST'}, inplace=True)
    df.rename(columns={'SEASCH': 'ST_SCHID'}, inplace=True)
    df.rename(columns={'SCHNAM': 'SCH_NAME'}, inplace=True)
    
    temp1=df[['NCESSCH' ,'year', 'STUDENT_COUNT']].copy()
    temp2=df[['LEAID', 'NCESSCH', 'year', 'virtual', 'partime_virtual',
              'not_virtual', 'missing_virtual', 'ST', 'VIRTUAL_TEXT',
              'ST_SCHID', 'SCH_NAME']].copy()
    temp3=df[['NCESSCH', 'year', 'gender_totalenrollment', 'per_female',
              'per_male', 'School_Total_Enrollment']].copy()
    temp4=df[['NCESSCH', 'year', 'race_totalenrollment', 'per_nativeamerican',
              'per_asian', 'per_black', 'per_hispanic', 'per_nhpi',
              'per_multiracial', 'per_white']].copy()
    
    return (temp1, temp2, temp3, temp4)
##############################################################################
## Stack CCD
##############################################################################


ccd = pd.DataFrame()

years = [2014, 2015, 2016, 2017, 2018, 2019, 2020]
frplpath = ['sc132a.txt',
            'ccd_sch_033_1415_w_0216161a.txt',
            'ccd_sch_033_1516_w_2a_011717.csv',
            'ccd_sch_033_1617_l_2a_11212017.csv',
            'ccd_sch_033_1718_l_1a_083118.csv',
            'ccd_sch_033_1819_l_1a_091019.csv',
            'ccd_sch_033_1920_l_1a_082120.csv']
schpath = ['sc132a.txt',
           'ccd_sch_029_1415_w_0216601a.txt',
           'ccd_sch_029_1516_w_2a_011717.csv',
           'ccd_sch_129_1617_w_1a_11212017.csv',
           'ccd_sch_129_1718_w_1a_083118.csv',
           'ccd_sch_129_1819_w_1a_091019.csv',
           'ccd_sch_129_1920_w_1a_082120.csv']
stupath = ['sc132a.txt',
           'ccd_sch_052_1415_w_0216161a.txt',
           'ccd_sch_052_1516_w_2a_011717.csv',
           'ccd_sch_052_1617_l_2a_11212017.csv',
           'ccd_SCH_052_1718_l_1a_083118.csv',
           'ccd_SCH_052_1819_l_1a_091019.csv',
           'ccd_SCH_052_1920_l_1a_082120.csv']

for yr, frpl, sch, stu in zip(years, frplpath, schpath, stupath):
    if yr in [2017, 2018, 2019, 2020]:
        temp1 = cleanFRPL(frpl, yr)
        temp2 = cleanSch(sch, yr)
        temp3 = cleanGender(stu, yr)
        temp4 = cleanRace(stu, yr)
    elif yr in [2015, 2016]:
        temp1 = cleanFRPL_before2017(frpl, yr)
        temp2 = cleanSch_before2017(sch, yr)
        temp3 = cleanGender_before2017(stu, yr)
        temp4 = cleanRace_before2017(stu, yr)
    else:
        temp1, temp2, temp3, temp4 = cleanPSU(frpl, yr)
        
    for i in [temp2, temp3, temp4]:
        temp1 = pd.merge(temp1, i, how='outer', on=['NCESSCH', 'year'])
    

    ccd = pd.concat([ccd, temp1], axis=0, ignore_index=True)

ccd['per_frpl'] = ccd['STUDENT_COUNT'] / ccd['School_Total_Enrollment']
ccd['per_frpl'].replace(np.inf, np.nan, inplace=True)
ccd['per_frpl'].replace(-np.inf, np.nan, inplace=True)
largeval = ccd['per_frpl'] > 1
ccd.loc[ccd.index[largeval],'per_frpl'] = 1
ccd['per_frpl'] = 100*ccd['per_frpl']

ccd.drop(columns='STUDENT_COUNT', inplace=True)
ccd.drop(index=ccd.index[ccd['ST'].isin(["BI", "DA", "GU", "PR", "VI", "AS",
                                         "AE", "AP", "DD", "MP"])],
         inplace=True)   

ccd.drop(columns = ['SCH_NAME', 'ST_SCHID'], inplace=True)
outpath = os.path.join(scriptpath, '..\..\Data\stacked_ccd.dta')
ccd.to_stata(outpath)
