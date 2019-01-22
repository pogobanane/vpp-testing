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
import matplotlib.ticker as tick
import csv
import re

hmac = ''
DIRS = ['/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-01-21_16-40-17_545512/nida/']

USED = """
l2_multimac_00000100_mbit4149hires.histogram.csv
l2_multimac_00001000_mbit4103hires.histogram.csv
l2_multimac_00005000_mbit4121_final.histogram.csv
l2_multimac_00010000_mbit4104hires.histogram.csv
l2_multimac_00015000_mbit4106hires.histogram.csv
l2_multimac_00020000_mbit4093hires.histogram.csv
l2_multimac_00025000_mbit4081hires.histogram.csv
l2_multimac_00050000_mbit4114hires.histogram.csv
l2_multimac_00075000_mbit4103hires.histogram.csv
l2_multimac_00100000_mbit4120hires.histogram.csv
l2_multimac_00125000_mbit4108hires.histogram.csv
l2_multimac_00150000_mbit4100hires.histogram.csv
l2_multimac_00175000_mbit4081hires.histogram.csv
l2_multimac_00200000_mbit4110hires.histogram.csv
l2_multimac_00225000_mbit4109hires.histogram.csv
l2_multimac_00250000_mbit4112hires.histogram.csv
l2_multimac_00275000_mbit3843hires.histogram.csv
l2_multimac_00300000_mbit4121hires.histogram.csv
l2_multimac_00325000_mbit4115hires.histogram.csv
l2_multimac_00350000_mbit4120hires.histogram.csv
l2_multimac_00375000_mbit4110hires.histogram.csv
l2_multimac_00400000_mbit4112hires.histogram.csv
l2_multimac_00425000_mbit4105hires.histogram.csv
l2_multimac_00450000_mbit4096hires.histogram.csv
l2_multimac_00475000_mbit4103hires.histogram.csv
l2_multimac_00500000_mbit4093hires.histogram.csv
"""
USED = """
l2_multimac_00000100_mbit4299hires.histogram.csv
l2_multimac_00001000_mbit4153hires.histogram.csv
l2_multimac_00005000_mbit4121hires.histogram.csv
l2_multimac_00010000_mbit4104hires.histogram.csv
l2_multimac_00015000_mbit4056hires.histogram.csv
l2_multimac_00020000_mbit4093hires.histogram.csv
l2_multimac_00025000_mbit4081hires.histogram.csv
l2_multimac_00050000_mbit4064hires.histogram.csv
l2_multimac_00075000_mbit4053hires.histogram.csv
l2_multimac_00100000_mbit4020hires.histogram.csv
l2_multimac_00125000_mbit4008hires.histogram.csv
l2_multimac_00150000_mbit4000hires.histogram.csv
l2_multimac_00175000_mbit3931hires.histogram.csv
l2_multimac_00200000_mbit3960hires.histogram.csv
l2_multimac_00225000_mbit3959hires.histogram.csv
l2_multimac_00250000_mbit3962_final.histogram.csv
l2_multimac_00275000_mbit3843hires.histogram.csv
l2_multimac_00300000_mbit3921hires.histogram.csv
l2_multimac_00325000_mbit3915hires.histogram.csv
l2_multimac_00350000_mbit3970hires.histogram.csv
l2_multimac_00375000_mbit3860hires.histogram.csv
l2_multimac_00400000_mbit3912hires.histogram.csv
l2_multimac_00425000_mbit3855hires.histogram.csv
l2_multimac_00450000_mbit3846hires.histogram.csv
l2_multimac_00475000_mbit3853hires.histogram.csv
l2_multimac_00500000_mbit3793hires.histogram.csv
"""

#hmac = 'hmac_'
#DIRS = ['/Users/gallenmu/mkdir/2018-07-29_18-13-41/rapla']

flatency = []
fthroughput = []
fthroughmac = []

for d in DIRS:
    files = os.listdir(d)
    flatency_ = filter(lambda x: x.endswith('.histogram.csv'), files)
    flatency.extend(map(lambda x: os.path.join(d, x), flatency_))
    flatency = sorted(flatency)
    fthroughput_ = filter(lambda x: x.endswith('throughput.csv'), files)
    fthroughput.extend(map(lambda x: os.path.join(d, x), fthroughput_))
    fthroughput = sorted(fthroughput)
    fthroughmac_ = filter(lambda x: x.startswith("l2_throughmac_"), files)
    fthroughmac__ = filter(lambda x: x.endswith("throughput.csv"), fthroughmac_)
    #for file in files:


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
        return float(tx[1]), float(tx[2]), float(rx[1]), float(rx[2])
    return "err"

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


# pasted from https://stackoverflow.com/questions/21844024/weighted-percentile-using-numpy?noredirect=1
def weighted_quantile(values, quantiles, sample_weight=None, values_sorted=False, old_style=False):
    """ Very close to numpy.percentile, but supports weights.
    NOTE: quantiles should be in [0, 1]!
    :param values: numpy.array with data
    :param quantiles: array-like with many quantiles needed
    :param sample_weight: array-like of the same length as `array`
    :param values_sorted: bool, if True, then will avoid sorting of initial array
    :param old_style: if True, will correct output to be consistent with numpy.percentile.
    :return: numpy.array with computed quantiles.
    """
    values = np.array(values)
    quantiles = np.array(quantiles)
    if sample_weight is None:
        sample_weight = np.ones(len(values))
    sample_weight = np.array(sample_weight)
    assert np.all(quantiles >= 0) and np.all(quantiles <= 1), 'quantiles should be in [0, 1]'

    if not values_sorted:
        sorter = np.argsort(values)
        values = values[sorter]
        sample_weight = sample_weight[sorter]

    weighted_quantiles = np.cumsum(sample_weight) - 0.5 * sample_weight
    if old_style:
        # To be convenient with np.percentile
        weighted_quantiles -= weighted_quantiles[0]
        weighted_quantiles /= weighted_quantiles[-1]
    else:
        weighted_quantiles /= np.sum(sample_weight)
    return np.interp(quantiles, weighted_quantiles, values)

def parse_histogramfile(latfile):
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
    return latencies, weights

def latency_per_macs(fileprefix):
    macss = []
    q0 = []
    q25 = []
    q5 = []
    q75 = []
    q90 = []
    q99 = []
    q999 = []
    for latfile in flatency: 
        filename = os.path.basename(latfile)
        if fileprefix in filename and not "mbit9000" in filename and filename in USED:
            print(filename)
            print(filename.split(fileprefix)[1][0:8])
            macs = int(filename.split(fileprefix)[1][0:8])
            latencies, weights = parse_histogramfile(latfile)
            quantiles = weighted_quantile(latencies, [0.0, 0.25, 0.5, 0.75, 0.90, 0.99, 0.999], sample_weight=weights, values_sorted=True)
            quantiles = list(map(lambda u: (u / 1000), quantiles))
            macss.append(macs)
            q0.append(quantiles[0])
            q25.append(quantiles[1])
            q5.append(quantiles[2])
            q75.append(quantiles[3])
            q90.append(quantiles[4])
            q99.append(quantiles[5])
            q999.append(quantiles[6])

    print(macss)
    print(q5)
    fig = plt.figure(figsize=(7, 4), dpi=80)
    axes = plt.gca()
    #axes.set_ylim([0,150])
    #axes.set_xlim([0.5, 12])
    g0, = plt.plot(macss, q0, marker=".")
    g1, = plt.plot(macss, q25, marker=".")
    g2, = plt.plot(macss, q5, marker=".")
    g3, = plt.plot(macss, q75, marker=".")
    g4, = plt.plot(macss, q90, marker=".")
    g5, = plt.plot(macss, q99, marker=".")
    g6, = plt.plot(macss, q999, marker=".")
    plt.title("{}*_final".format(fileprefix))
    plt.ylabel("latency (ys)")
    plt.xlabel("mac flows")
    plt.legend([g0,g1,g2,g3,g4,g5,g6], ["0th percentile", "25th", "50th", "75th", "90th", "99th", "99.9th"])
    fig.tight_layout()
    #plt.grid(True)

    #return get_tikz_code(outf, show_info=False, figurewidth="48cm", figureheight="7cm")
    fig.savefig("latency_{}.pdf".format(fileprefix))
    plt.show()

def throughput_per_macs(fileprefix):
    macss = []
    throughputs = []
    stddevs = []
    for throughfile in fthroughput: 
            filename = os.path.basename(throughfile)
            if fileprefix in filename and "_0." in filename:
                macs = int(filename.split(fileprefix)[1][0:8])
                runs = 5
                runresults = []
                for run in range(0,runs):
                    print(run)
                    postfix = filename.split(fileprefix)[1]
                    postfix = "{}{}{}".format(postfix[0:9], run, postfix[10:])
                    nextfile = os.path.join(os.path.dirname(throughfile), "{}{}".format(fileprefix, postfix))
                    print(nextfile)
                    n1,n2,throughput,n3 = parse_throughput(nextfile)
                    runresults.append(throughput)
                macss.append(macs)
                throughputs.append(np.average(runresults))
                stddevs.append(np.std(runresults))
    print(macss)
    print(throughputs)
    fig = plt.figure(figsize=(7, 4), dpi=80)
    axes = plt.gca()
    #axes.set_ylim([0,150])
    #axes.set_xlim([0.5, 12])
    #axes.set_yscale('log')
    plt.axvline(label="l2 cache", color="#f48024", x=16000)
    plt.axvline(label="l2 cache", color="#f48024", x=1250000)
    plt.text(37000, 8.4, "l2 cache")
    plt.text(1270000, 8.4, "l3 cache")
    g0,n0,n1 = plt.errorbar(macss, throughputs, stddevs) #, linestyle="-", marker=".")
    plt.title("sending to many destinations")
    plt.ylabel("throughput (Mpps)")
    plt.xlabel("mac table entries")
    fig.tight_layout()
    #plt.grid(True)

    #return get_tikz_code(outf, show_info=False, figurewidth="48cm", figureheight="7cm")
    fig.savefig("throughput_{}.pdf".format(fileprefix))
    plt.show()

throughput_per_macs("l2_throughmac_")