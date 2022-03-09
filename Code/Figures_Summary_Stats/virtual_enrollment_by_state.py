# -*- coding: utf-8 -*-
"""
Created on Fri Apr  9 13:34:09 2021

@author: Trevor Gratz trevormgratz@gmail.com

"""
from matplotlib.colors import Normalize
from matplotlib import cm
from matplotlib.cm import ScalarMappable
from matplotlib import pyplot as plt
from matplotlib import colors as cols
import matplotlib as mpl
import geopandas as gpd
import os
import pandas as pd 
import numpy as np
import imageio
import math

scriptpath = os.path.abspath(os.path.dirname(__file__))
shppath = os.path.join(scriptpath, '..\..\Data\cb_2018_us_state_500k\cb_2018_us_state_500k.shp')
virschpath = os.path.join(scriptpath, '..\..\Data\Intermediate\statelevel_enrollments.dta')

# Virtual School Enrollments
virschdf = pd.read_stata(virschpath)
virschdf['% Virtual Enrollment'] = (100*(virschdf['virtual_enroll']/  virschdf['totalenrollment'])).round(2)
virschdf['% Stride Enrollment'] = (100*virschdf['stride_enroll']/  virschdf['totalenrollment']).round(2)

# Shape Files
statesdf = gpd.read_file(shppath)
todrop = ['MP', 'GU', 'PR', 'AS', 'VI', 'AK', 'HI']
statesdf.drop(index=statesdf.index[statesdf['STUSPS'].isin(todrop)], inplace=True)
statesdf.rename(columns={'STUSPS': 'ST'}, inplace=True)

# Calculate Growth
virschdf2017 = virschdf.loc[virschdf['year'] == 2017, :].copy()
virschdf2020 = virschdf.loc[virschdf['year'] == 2020, :].copy()

temp = virschdf2017[['ST', '% Virtual Enrollment']].copy()
temp = temp.rename(columns={'% Virtual Enrollment': '2017 % Virtual Enrollment'})
growth = pd.merge(virschdf2020, temp, how='left', on='ST')
growth['% Change'] = ((growth['% Virtual Enrollment'] / growth['2017 % Virtual Enrollment']) - 1)*100
growth = pd.merge(statesdf, growth, how='inner', on='ST')
growth['% Change'] = growth['% Change'].fillna(0)
growth['% Change'] = growth['% Change'].replace([np.inf, -np.inf], 0)

# Merge 
states2017 = pd.merge(statesdf, virschdf2017, how='inner', on='ST')
states2020 = pd.merge(statesdf, virschdf2020, how='inner', on='ST')

def mapyears(year, df, var, lowbound, uppbound, axm, figcolorbar=False,):
    fte_cmap = plt.cm.get_cmap('OrRd')
    # Plot Map
    vmin, vmax = lowbound, uppbound
    p1 = df.plot( column = var, cmap = fte_cmap, vmin=vmin, vmax=vmax,  
                     linewidth = 0.1, edgecolor = 'black', ax = axm)
    
    maskcol = df[var] == 0
    greyplot = df[maskcol]
    greyplot.plot( color = '0.7', linewidth = 0.1, edgecolor = 'black', ax = axm)

    # Axes options
    axm.spines['top'].set_visible(False)
    axm.spines['right'].set_visible(False)
    axm.spines['bottom'].set_visible(False)
    axm.spines['left'].set_visible(False)
    axm.ticklabel_format(axis ='both', style ='plain')
    
    label = axm.xaxis.get_label()
    x_lab_pos, y_lab_pos = label.get_position()
    label.set_position([1.0, y_lab_pos])
    label.set_horizontalalignment('right')
    axm.xaxis.set_label(label)
    
    axm.tick_params(
        axis='both',         
        which='both',      
        bottom=False,      
        top=False,
        left = False,
        labelleft=False,
        labelbottom=False)
    
    if figcolorbar == True:
    # Plot Color Bar
        sm = ScalarMappable(cmap=fte_cmap, norm=plt.Normalize(lowbound, uppbound))
        tickmarks = list(np.linspace(lowbound, uppbound, 5))
        tickmarks = [round(i,1) for i in tickmarks]
        cbar = plt.colorbar(sm, ticks = tickmarks, ax = axm)
        cbar.set_label(var, rotation=270, labelpad=25, fontsize = 12 )
        axm.set_xlabel('*Grey indicates zero virtual schools', fontsize=8)


##############################################################################
## 2020 Virtual School Enrollement by State
virtual_uppbound = round(states2020['% Virtual Enrollment'].max(), 3)
virtual_lowbound = states2020['% Virtual Enrollment'].min()

fig, ax1 = plt.subplots(figsize=(20,15))
mapyears(2020, states2020, '% Virtual Enrollment', virtual_lowbound, virtual_uppbound, figcolorbar=False, axm=ax1)

# Colorbar
fte_cmap = plt.cm.get_cmap('OrRd')
lowbound = virtual_lowbound
uppbound = virtual_uppbound
sm = ScalarMappable(cmap=fte_cmap, norm=plt.Normalize(lowbound, uppbound))
tickmarks = list(np.linspace(lowbound, uppbound, 5))
# rounding the highest tickmark up takes it off the colorbar. Round it down.
lasttick = tickmarks[-1]
tickmarks = [round(i,1) for i in tickmarks[0:-1]]
tickmarks.append(lasttick)
tickmarks[-1] = math.floor(tickmarks[-1]*10)/10

cbar = fig.colorbar(sm, ax=[ax1], shrink=0.80, ticks = tickmarks)
cbar.ax.tick_params(labelsize=18)
cbar.set_label('% Virtual Enrollment', rotation=270, labelpad=25, fontsize = 24,
               fontname = "Times New Roman")
fig.suptitle('2020 Virtual School Enrollment as a Percent of Total Public School Enrollment',
             x=0.44, y=0.95, fontname = "Times New Roman", fontsize=20)
fig.text(x=.70, y=0.1, s='*Grey indicates no virtual schools in the state', 
         fontname = "Times New Roman", fontsize=10)


##############################################################################
## Growth in virtual school enrollment between 2017-2020.
virtual_uppbound = 100 
virtual_lowbound = -50
fig, ax1 = plt.subplots(figsize=(20,15))
mapyears(2020, growth, '% Change', virtual_lowbound, virtual_uppbound, figcolorbar=False, axm=ax1)

# Colorbar
fte_cmap = plt.cm.get_cmap('OrRd')
lowbound = virtual_lowbound
uppbound = virtual_uppbound
sm = ScalarMappable(cmap=fte_cmap, norm=plt.Normalize(lowbound, uppbound))
tickmarks = list(np.linspace(lowbound, uppbound, 4))
# rounding the highest tickmark up takes it off the colorbar. Round it down.
lasttick = tickmarks[-1]
tickmarks = [round(i,1) for i in tickmarks[0:-1]]
tickmarks.append(lasttick)
tickmarks[-1] = math.floor(tickmarks[-1]*10)/10

cbar = fig.colorbar(sm, ax=[ax1], shrink=0.80, ticks = tickmarks)
cbar.ax.tick_params(labelsize=18)
cbar.set_label('Change % Virtual Enrollment', rotation=270, labelpad=25, fontsize = 24,
               fontname = "Times New Roman")
fig.suptitle('2017 to 2020 % Change Virtual School Enrollment',
             x=0.44, y=0.95, fontname = "Times New Roman", fontsize=20)
fig.text(x=.70, y=0.1, s='*Grey indicates no virtual schools\n in the state in 2020 and/or in 2017', 
         fontname = "Times New Roman", fontsize=10)
