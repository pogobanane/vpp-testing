#!/usr/bin/env python
# needs python-pmw package
# coding: utf-8

# In[ ]:


from __future__ import print_function

#get_ipython().run_line_magic('matplotlib', 'inline')

import os
import codecs
import numpy as np
import pandas as pd
import seaborn as sns
from tqdm import tqdm
from tabulate import tabulate
import matplotlib.pyplot as plt
from matplotlib2tikz import get_tikz_code
import csv
import re


# In[2]:


sns.set(style="ticks")


# In[ ]:


hmac = ''
DIRS = ['/home/peter/dev/ba/ba-okelmann/statistics/data/2019-01-03_12-51-30_758111/nida/']

#hmac = 'hmac_'
#DIRS = ['/Users/gallenmu/mkdir/2018-07-29_18-13-41/rapla']

flatency = []
fthroughput = []


for d in DIRS:
    files = os.listdir(d)
    flatency_ = filter(lambda x: x.endswith('histogram.csv'), files)
    flatency.extend(map(lambda x: os.path.join(d, x), flatency_))
    fthroughput_ = filter(lambda x: x.endswith('throughput.csv'), files)
    fthroughput.extend(map(lambda x: os.path.join(d, x), fthroughput_))

# In[3]:

"""
hmac = ''
flatency = ['~/dev/ba/ba-okelmann/statistics/aaaa.csv']
fthroughput = []
"""

# In[4]:


tikz_header = r"""
\documentclass[beamer,multi=true,preview,tikz]{standalone}

\usepackage[utf8]{inputenc}
\usepackage{tumcolor}
\usepackage{tikz}
%\usepackage{times}
\usepackage{pgfplots}
\pgfplotsset{compat=1.13}

\begin{document}%
"""

tikz_footer = r"""
\end{document}
"""

"""
# ## Throughput

# In[9]:


dfthr = []
for fname in tqdm(fthroughput, ncols=0, desc='Parsing'):
    s = fname.split('.')
    t = s[0].split('/')
    u = t[len(t)-1].split('-')
    for e in u:
        if 'rate' in e:
            rate = int(e.replace('rate', ''))
        elif 'pktsz' in e:
            psize = int(e.replace('pktsz', ''))
                
    df = pd.read_csv(fname)       
    df['psize'] = psize
    df['rate'] = rate
    
    dfthr.append(df)
    
#dfthr = pd.concat(dfthr)
dfthr.reset_index(drop=True, inplace=True)


# In[6]:


dfthr['PacketRate'] = dfthr['PacketRate'].astype(float)
dfthr.head()


# In[7]:


def max_packet_rate_mpps(psize):
    return (10000000000 / ((psize +24) * 8)) / 1000000 


# In[8]:


dfthr_ = dfthr.groupby(['psize', 'rate', 'Direction'])['PacketRate'].median().reset_index()
dfthr_ = dfthr.groupby(['psize', 'rate', 'Direction'])['PacketRate'].max().reset_index()
dfthr_ = pd.pivot_table(dfthr_, index=['psize', 'rate'], columns="Direction", values="PacketRate").reset_index()

dfthr_.to_csv("~/dev/ba/ba-okelmann/statistics/throughput_mpps.csv", index=False)


# In[ ]:


dfg = dfthr_.groupby(['psize'])["RX"].max().reset_index()
print(dfg)


# In[ ]:


fig = plt.figure()

xes = []
ys = []

dfg = dfthr_.groupby(['psize'])["RX"].max().reset_index()
print(dfg)
for index, row in dfg.iterrows():
    psize = row['psize']
    rx = row["RX"]
    maxr = max_packet_rate_mpps(psize)
    
    xes.append(psize)
    ys.append(rx/maxr)

fig = plt.figure()

plt.legend(loc='upper center', ncol=4, bbox_to_anchor=(0.5, 1.21))

    
plt.ylabel("Relative transfer rate")
plt.xlabel("Packet size (Byte)")
fig.tight_layout()
plt.grid(True)

plt.plot(xes, ys, markersize=10, marker='o', label=psize)
plt.title('Relative transfer rates for different packets sizes')
axes = plt.gca()
axes.set_ylim(ymin=0)
axes.set_ylim(ymax=1.1)

outf = '~/dev/ba/ba-okelmann/statistics/'+hmac+'relative_throughput__all_sizes.tex'.format(psize)
with codecs.open(outf, "w", encoding="utf8") as f:
    f.write(tikz_header)
    f.write(get_tikz_code(outf, show_info=False, figurewidth="12cm", figureheight="7cm"))
    f.write(tikz_footer)


plt.show()
    
print(ys)


# In[ ]:


fig = plt.figure()
for psize, dfg in dfthr_.groupby(["psize"]):
    #print(dfg["TX"].tolist())
    
    plt.plot(dfg["TX"].tolist(), dfg["RX"].tolist(), markersize=10, marker='o', label=psize)
    plt.legend(loc='upper center', ncol=4, bbox_to_anchor=(0.5, 1.21))

    
    plt.xlabel("Transmitted Framerate (Mpps)")
    plt.ylabel("Received Framerate (Mpps)")
    fig.tight_layout()
    plt.grid(True)
    
    axes = plt.gca()
    axes.set_ylim(ymin=0)
    #axes.set_ylim(ymax=16)
    
    outf = '~/dev/ba/ba-okelmann/statistics/'+hmac+'throughput__{}.tex'.format(psize)
    with codecs.open(outf, "w", encoding="utf8") as f:
        f.write(tikz_header)
        f.write(get_tikz_code(outf, show_info=False, figurewidth="12cm", figureheight="7cm"))
        f.write(tikz_footer)
    
    plt.title('Packet size: {}B'.format(psize))

    plt.show()


# In[ ]:

"""


# pasted from https://stackoverflow.com/questions/16259923/how-can-i-escape-latex-special-characters-inside-django-templates
def tex_escape(text):
    """
        :param text: a plain text message
        :return: the message escaped to appear correctly in LaTeX
    """
    conv = {
        '&': r'\&',
        '%': r'\%',
        '$': r'\$',
        '#': r'\#',
        '_': r'\_',
        '{': r'\{',
        '}': r'\}',
        '~': r'\textasciitilde{}',
        '^': r'\^{}',
        '\\': r'\textbackslash{}',
        '<': r'\textless{}',
        '>': r'\textgreater{}',
    }
    regex = re.compile('|'.join(re.escape(str(key)) for key in sorted(conv.keys(), key = lambda item: - len(item))))
    return regex.sub(lambda match: conv[match.group()], text)

def parse_throughput(csvfile):
    print("penis")
    with open(csvfile, ) as f:
        reader = csv.reader(f)
        next(reader) # skip header line
        tx = next(reader)
        rx = next(reader)
        print("{0:.2f}".format(float(rx[2])))
        ret = "tx: %.2fmpps, %.2fstdDev; rx: %.2fmpps, %.2fstdDev" % (float(tx[1]), float(tx[2]), float(rx[1]), float(rx[2]))
        print(ret)
        return ret
    return "err"


def latency_csv2tex(latfile, throughfile):

    # ## Latency

    # In[13]:

    flatency = [latfile]
    dflat = []
    for fname in tqdm(flatency, ncols=0):
       
        s = fname.split('.')
        t = s[0].split('/')
        u = t[len(t)-1].split('-')
        for e in u:
            if 'rate' in e:
                rate = int(e.replace('rate', ''))
            elif 'pktsz' in e:
                psize = int(e.replace('pktsz', ''))
                    
        df = pd.read_csv(fname, names=["latency", "weight"])
        #df['rate'] = rate
        #df['psize'] = psize
          
        dflat.append(df)
        
    dflat = pd.concat(dflat)
    dflat.reset_index(drop=True, inplace=True)


    # In[14]:


    dflat.head()


    # In[42]:


    #for (psize, rate), dfg in dflat.groupby(["psize", "rate"]):
        
        #print(rate)
        #print(psize)
        #print(dfg)
        
        #latencies = dfg['latency'].tolist()
        #weights = dfg['weight'].tolist()
    latencies = dflat['latency'].tolist()
    weights = dflat['weight'].tolist()

    rate = -1
    psize = -1

    fig = plt.figure()

    plt.hist(latencies, weights=weights, bins=100)
    #plt.title('Rate {} Mbit/s - Packet size: {} B'.format(rate, psize))
    plt.title("{}: \n{}".format(tex_escape(os.path.basename(latfile)), tex_escape(parse_throughput(throughfile))))
    #plt.legend(loc=0)
    plt.ylabel("Number of events")
    plt.xlabel("Processing latency (ns)")
    fig.tight_layout()
    plt.grid(True)

    return get_tikz_code(outf, show_info=False, figurewidth="48cm", figureheight="7cm")

    #plt.show()
    #plt.draw()
    #plt.pause(0.001)



outf = "netronome.tex"
with codecs.open(outf, "w+", encoding="utf8") as f:
    f.write(tikz_header)
    for i in range(0, len(flatency)):

        #outf = '{}.tex'.format(flatency[i])
        
        f.write(latency_csv2tex(flatency[i], fthroughput[i]))
        f.write("\n\n\n")

    f.write(tikz_footer)



# pdflatex netronome.tex