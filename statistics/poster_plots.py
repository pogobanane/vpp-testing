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
from scipy.ndimage.filters import gaussian_filter1d

hmac = ''
DIRS = ['/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-04-01_01-08-16_986987/klaipeda/',
        '/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-04-01_01-08-16_986987/narva/']

GREEN = "#3f9852"
BLUE = "#3869b1"
ORANGE = "#da7e30"
RED = "#cc2428"
PURPLE = "#6b4c9a"

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
fstat = []

def scrape_dirs(folder, other):
    flatency = []
    fthroughput = []
    fstat = []

    dirs = [folder, other]
    for d in dirs:
        files = os.listdir(d)

        flatency_ = filter(lambda x: x.endswith('.histogram.csv'), files)
        flatency.extend(map(lambda x: os.path.join(d, x), flatency_))
        flatency = sorted(flatency)

        fthroughput_ = filter(lambda x: x.endswith('throughput.csv'), files)
        fthroughput.extend(map(lambda x: os.path.join(d, x), fthroughput_))
        fthroughput = sorted(fthroughput)

        fstat_ = filter(lambda x: x.endswith('.perfstat.csv'), files)
        fstat.extend(map(lambda x: os.path.join(d, x), fstat_))
        fstat = sorted(fstat)

    return flatency, fthroughput, fstat

flatency, fthroughput, fstat = scrape_dirs(DIRS[0], DIRS[1])

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

def parse_perfstats(statfile, key):
    with open(statfile, "r") as f:
        reader = csv.reader(f, delimiter=";")
        for row in reader: 
            if len(row) >= 2 and key in row[2]:
                ret = 0
                try:
                    ret = float(row[0])
                    return ret
                except:
                    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                    return -1.0
    return -1.0

def parse_perfrecord(statfile, key):
    with open(statfile, "r") as f:
        reader = csv.reader(f, delimiter=";")
        for row in reader: 
            if len(row) >= 4 and key in row[3]:
                ret = 0
                try:
                    ret = float(row[0].strip().strip('%'))
                    return ret
                except:
                    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                    return -1.0
    return -1.0

def parse_packetdrops(csvthroughputfile):
    print("penis")
    with open(csvthroughputfile, ) as f:
        reader = csv.reader(f)
        next(reader) # skip header line
        tx = next(reader)
        rx = next(reader)
        print("{0:.2f}".format(float(rx[2])))
        absdrops = int(float(tx[6])) - int(float(rx[6]))
        print("asdasdasdasd")
        print(absdrops)
        if absdrops <= 0:
            return 0
        return absdrops #/ int(float(tx[6]))
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

def latency_per_throughput_collect(fileprefix):
    rates = []
    q0 = []
    q25 = []
    q5 = []
    q75 = []
    q90 = []
    q99 = []
    q999 = []
    drops = []
    for latfile in flatency: 
        filename = os.path.basename(latfile)
        if fileprefix in filename and not "mbit9000" in filename:
            rate = float(filename.split(fileprefix)[1][0:6]) / (64*8)
            # rate = int(filename[16:20]) # * 1000 / (64*8) # kbit / packetSize(byte) * 8bit
            latencies, weights = parse_histogramfile(latfile)
            csvthroughputfile = "{}.throughput.csv".format(latfile[:-14])
            dropped = parse_packetdrops(csvthroughputfile)
            tx,n2,throughput,n3 = parse_throughput(csvthroughputfile)
            quantiles = weighted_quantile(latencies, [0.0, 0.25, 0.5, 0.75, 0.90, 0.99, 0.999], sample_weight=weights, values_sorted=True)
            quantiles = list(map(lambda u: (u / 1000), quantiles))
            rates.append(rate)
            q0.append(quantiles[0])
            q25.append(quantiles[1])
            q5.append(quantiles[2])
            q75.append(quantiles[3])
            q90.append(quantiles[4])
            q99.append(quantiles[5])
            q999.append(quantiles[6])
            drops.append(dropped)
    return rates, q0, q5, q99, q999, drops

def latency_per_throughput():

    fig = plt.figure(figsize=(7, 4), dpi=160)
    axes = plt.gca()
    ax2 = axes.twinx()
    axes.set_ylim([0,50])
    ax2.set_yscale("log")
    axes.set_xlim([0.5, 12])
    axes.grid(True)
    rates, q0, q5, q99, q999, drops = latency_per_throughput_collect("l3_latroutes1_")
    axes.plot(rates, q0, linestyle=":", color=GREEN)
    g0, = axes.plot(rates, q5, color=GREEN, marker="o")
    g1, = axes.plot(rates, q99, linestyle=":", color=GREEN)
    axes.plot(rates, q999, linestyle=":", color=GREEN)
    g2, = ax2.plot(rates, drops, color=ORANGE, marker="1")
    rates, q0, q5, q99, q999, drops = latency_per_throughput_collect("l3_latroutes255k_")
    axes.plot(rates, q0, linestyle=":", color=BLUE)
    g3, = axes.plot(rates, q5, color=BLUE, marker=">")
    g4, = axes.plot(rates, q99, linestyle=":", color=BLUE)
    axes.plot(rates, q999, linestyle=":", color=BLUE)
    g5, = ax2.plot(rates, drops, color=PURPLE, marker="1")
    plt.title("Latencies in IPv4 routing")
    axes.set_ylabel("latency (ys)")
    axes.set_xlabel("throughput (Mpps)")
    ax2.set_ylabel("packet drops")
    plt.legend([g0,g1, g2, g3, g4, g5], ["1 r latency", "1 r 0/99/99,9th percentile", "1 r packet drops", "255k r latency", "255k r 0/99/99,9th percentile", "255k r packet drops"]) #, loc="center left")
    fig.tight_layout()
    fig.savefig("latencies_per_throughput_summary_ip4.pdf")
    plt.show()

def throughput_per_macs(fileprefix):
    macss = []
    throughputs = []
    through_stddevs = []
    cachemisses1 = []
    cachemisses1_stddevs = []
    cachemisses3 = []
    cachemisses3_stddevs = []
    fn1pcts = []
    fn1pct_stddevs = []
    fn2pcts = []
    fn2pct_stddevs = []
    for throughfile in fthroughput: 
            filename = os.path.basename(throughfile)
            if fileprefix in filename and "_0." in filename:
                macs = int(filename.split(fileprefix)[1][0:8])
                runs = 6
                runresults = []
                runresults_cache1 = []
                runresults_cache3 = []
                runrestults_fn1 = []
                runrestults_fn2 = []
                for run in range(0,runs):
                    print(run)
                    postfix = filename.split(fileprefix)[1]
                    postfix = "{}{}{}".format(postfix[0:9], run, postfix[10:])
                    nextfile = os.path.join(os.path.dirname(throughfile), "{}{}".format(fileprefix, postfix))
                    print(nextfile)
                    n1,n2,throughput,n3 = parse_throughput(nextfile)
                    statfile = nextfile[:-15]
                    statfile = "{}{}".format(nextfile[:-15], ".perfstat.csv")
                    print(statfile)
                    statfilepath = next(filter(lambda x: x.endswith(os.path.basename(statfile)), fstat))
                    recordfilepath = "{}{}".format(statfilepath[:-13], ".perfrecord.csv")
                    misses1 = parse_perfstats(statfilepath, "L1-dcache-load-misses") * 0.1 # WATCH OUT THIS *0.1 CAN BE EVIL because it serves beautification purpose. 
                    misses3 = parse_perfstats(statfilepath, "cache-misses")
                    fn1 = parse_perfrecord(recordfilepath, "l2fwd_node")
                    fn2 = 0 #fn2 = parse_perfrecord(recordfilepath, "ip6_rewrite")
                    runresults.append(throughput)
                    runresults_cache1.append(misses1)
                    runresults_cache3.append(misses3)
                    if fn1 > 0:
                        runrestults_fn1.append(fn1)
                    if fn2 > 0:
                        runrestults_fn2.append(fn2)

                macss.append(macs)
                through_avg = np.average(runresults)
                throughputs.append(through_avg)
                through_stddevs.append(np.std(runresults))
                fn1pcts.append(np.average(runrestults_fn1))
                fn1pct_stddevs.append(np.std(runrestults_fn1))
                fn2pcts.append(np.average(runrestults_fn2))
                fn2pct_stddevs.append(np.std(runrestults_fn2))
                print(runresults_cache1)
                print(runresults_cache3)
                cachemisses1.append(np.average(runresults_cache1) / through_avg / 1000000)
                cachemisses1_stddevs.append(np.std(runresults_cache1) / through_avg / 1000000)
                cachemisses3.append(np.average(runresults_cache3) / through_avg / 1000000)
                cachemisses3_stddevs.append(np.std(runresults_cache3) / through_avg / 1000000)
    print(macss)
    print(throughputs)
    print(cachemisses1)
    print(cachemisses3)
    cachemisses1_smooth = gaussian_filter1d(cachemisses1, sigma=1)
    cachemisses3_smooth = gaussian_filter1d(cachemisses3, sigma=1)
    fig = plt.figure(figsize=(7, 4), dpi=160)
    axes = plt.gca() # swap axes
    ax2 = axes.twinx()
    #axes.set_ylim([0,150])
    #axes.set_xlim([0, 10000000])
    #axes.set_yscale("log")
    #ax2.set_yscale('log')
    axes.set_xscale("log", basex=10)
    axes.axvline(color="gray", x=2048)
    axes.text(2048, 11.7, " l1 cache")
    axes.axvline(color="gray", x=16384)
    axes.text(16384, 11.7, " l2 cache")
    axes.axvline(color="gray", x=2097152)
    axes.text(2097152, 8.4, " l3 cache")

    #ax2.axhline(color="gray", linewidth=0.5, y=15)
    g2,n0,n1 = ax2.errorbar(macss, cachemisses1, cachemisses1_stddevs, elinewidth=0.5, color=BLUE, marker="1")
    #n2,n0,n1 = ax2.errorbar(macss, cachemisses1_smooth, elinewidth=0.5, color=BLUE, linestyle=":")
    g1,n0,n1 = ax2.errorbar(macss, cachemisses3, cachemisses3_stddevs, elinewidth=0.5, color=ORANGE)
    #n2,n0,n1 = ax2.errorbar(macss, cachemisses3_smooth, elinewidth=0.5, color=ORANGE, linestyle=":")
    g3,n0,n1 = ax2.errorbar(macss, fn1pcts, fn1pct_stddevs, elinewidth=0.5, color=PURPLE)
    #g4,n0,n1 = ax2.errorbar(macss, fn2pcts, fn2pct_stddevs, elinewidth=0.5, color=RED)
    g0,n0,n1 = axes.errorbar(macss, throughputs, through_stddevs, linewidth=3, elinewidth=0.5, color=GREEN) #, linestyle="-", marker=".")
    plt.title("sending to many destinations")
    axes.set_ylabel("throughput (Mpps)")
    axes.set_xlabel("l2fib entries")
    ax2.set_ylabel("cache-misses/packet & CPU time percentage")
    plt.legend([g0,g1, g2, g3], ["throughput", "LLC load misses", "1/10 * L1d load misses", "fn l2fwd_node"], loc="lower left")
    fig.tight_layout()
    #plt.grid(True)

    #return get_tikz_code(outf, show_info=False, figurewidth="48cm", figureheight="7cm")
    fig.savefig("throughput_{}.pdf".format(fileprefix))
    plt.show()


def throughput_per_routes(fileprefix):
    macss = []
    throughputs = []
    through_stddevs = []
    cachemisses1 = []
    cachemisses1_stddevs = []
    cachemisses3 = []
    cachemisses3_stddevs = []
    fn1pcts = []
    fn1pct_stddevs = []
    fn2pcts = []
    fn2pct_stddevs = []
    for throughfile in fthroughput: 
            filename = os.path.basename(throughfile)
            if fileprefix in filename and "_0." in filename:
                macs = int(filename.split(fileprefix)[1][0:8])
                runs = 6
                runresults = []
                runresults_cache1 = []
                runresults_cache3 = []
                runrestults_fn1 = []
                runrestults_fn2 = []
                for run in range(0,runs):
                    print(run)
                    postfix = filename.split(fileprefix)[1]
                    postfix = "{}{}{}".format(postfix[0:9], run, postfix[10:])
                    nextfile = os.path.join(os.path.dirname(throughfile), "{}{}".format(fileprefix, postfix))
                    print(nextfile)
                    n1,n2,throughput,n3 = parse_throughput(nextfile)
                    statfile = nextfile[:-15]
                    statfile = "{}{}".format(nextfile[:-15], ".perfstat.csv")
                    print(statfile)
                    statfilepath = next(filter(lambda x: x.endswith(os.path.basename(statfile)), fstat))
                    recordfilepath = "{}{}".format(statfilepath[:-13], ".perfrecord.csv")
                    misses1 = parse_perfstats(statfilepath, "L1-dcache-load-misses") * 0.1 # WATCH OUT THIS *0.1 CAN BE EVIL because it serves beautification purpose. 
                    # misses3 = parse_perfstats(statfilepath, "LLC-load-misses")
                    misses3 = parse_perfstats(statfilepath, "cache-misses")
                    # fn1 = parse_perfrecord(recordfilepath, "ip4_lookup")
                    # fn2 = parse_perfrecord(recordfilepath, "ip4_rewrite")
                    fn1 = parse_perfrecord(recordfilepath, "ip6_lookup")
                    fn2 = parse_perfrecord(recordfilepath, "ip6_rewrite")
                    runresults.append(throughput)
                    runresults_cache1.append(misses1)
                    runresults_cache3.append(misses3)
                    if fn1 > 0:
                        runrestults_fn1.append(fn1)
                    if fn2 > 0:
                        runrestults_fn2.append(fn2)

                macss.append(macs)
                through_avg = np.average(runresults)
                throughputs.append(through_avg)
                through_stddevs.append(np.std(runresults))
                fn1pcts.append(np.average(runrestults_fn1))
                fn1pct_stddevs.append(np.std(runrestults_fn1))
                fn2pcts.append(np.average(runrestults_fn2))
                fn2pct_stddevs.append(np.std(runrestults_fn2))
                print(runresults_cache1)
                print(runresults_cache3)
                cachemisses1.append(np.average(runresults_cache1) / through_avg / 1000000)
                cachemisses1_stddevs.append(np.std(runresults_cache1) / through_avg / 1000000)
                cachemisses3.append(np.average(runresults_cache3) / through_avg / 1000000)
                cachemisses3_stddevs.append(np.std(runresults_cache3) / through_avg / 1000000)
    print(macss)
    print(throughputs)
    print(cachemisses1)
    print(cachemisses3)
    cachemisses1_smooth = gaussian_filter1d(cachemisses1, sigma=1)
    cachemisses3_smooth = gaussian_filter1d(cachemisses3, sigma=1)
    fig = plt.figure(figsize=(7, 4), dpi=160)
    axes = plt.gca() # swap axes
    ax2 = axes.twinx()
    #axes.set_ylim([0,150])
    #axes.set_xlim([0, 10000000])
    #axes.set_yscale("log")
    #ax2.set_yscale('log')
    axes.set_xscale("log", basex=10)
    #axes.axvline(color="gray", x=2048)
    #axes.text(2048, 8.4, " l1 cache")
    #axes.axvline(color="gray", x=16384)
    #axes.text(16384, 8.4, " l2 cache")
    #axes.axvline(color="gray", x=2097152)
    #axes.text(2097152, 8.4, " l3 cache")

    #ax2.axhline(color="gray", linewidth=0.5, y=15)
    g2,n0,n1 = ax2.errorbar(macss, cachemisses1, cachemisses1_stddevs, elinewidth=0.5, color=BLUE)
    #n2,n0,n1 = ax2.errorbar(macss, cachemisses1_smooth, elinewidth=0.5, color=BLUE, linestyle=":")
    g1,n0,n1 = ax2.errorbar(macss, cachemisses3, cachemisses3_stddevs, elinewidth=0.5, color=ORANGE)
    g3,n0,n1 = ax2.errorbar(macss, fn1pcts, fn1pct_stddevs, elinewidth=0.5, color=PURPLE)
    g4,n0,n1 = ax2.errorbar(macss, fn2pcts, fn2pct_stddevs, elinewidth=0.5, color=RED)
    #n2,n0,n1 = ax2.errorbar(macss, cachemisses3_smooth, elinewidth=0.5, color=ORANGE, linestyle=":")
    g0,n0,n1 = axes.errorbar(macss, throughputs, through_stddevs, linewidth=3, elinewidth=0.5, color=GREEN) #, linestyle="-", marker=".")
    plt.title("sending to many destinations")
    axes.set_ylabel("throughput (Mpps)")
    axes.set_xlabel("l3fib entries")
    ax2.set_ylabel("cache-misses/packet & CPU time percentage")
    plt.legend([g0,g1, g2, g3, g4], ["throughput", "LLC load misses", "1/10 * L1d load misses", "fn ip6_lookup", "fn ip6_rewrite"], loc="lower left")
    fig.tight_layout()
    #plt.grid(True)

    #return get_tikz_code(outf, show_info=False, figurewidth="48cm", figureheight="7cm")
    fig.savefig("throughput_{}.pdf".format(fileprefix))
    plt.show()


def throughput_per_cores(fileprefix):
    macss = []
    throughputs = []
    through_stddevs = []
    cachemisses1 = []
    cachemisses1_stddevs = []
    cachemisses3 = []
    cachemisses3_stddevs = []
    for throughfile in fthroughput: 
            filename = os.path.basename(throughfile)
            if fileprefix in filename and "_0." in filename:
                macs = int(filename.split(fileprefix)[1][0:2])
                runs = 6
                runresults = []
                runresults_cache1 = []
                runresults_cache3 = []
                for run in range(0,runs):
                    print(run)
                    postfix = filename.split(fileprefix)[1]
                    postfix = "{}{}{}".format(postfix[0:3], run, postfix[4:])
                    nextfile = os.path.join(os.path.dirname(throughfile), "{}{}".format(fileprefix, postfix))
                    print(nextfile)
                    n1,n2,throughput,n3 = parse_throughput(nextfile)
                    statfile = nextfile[:-15]
                    statfile = "{}{}".format(nextfile[:-15], ".perfstat.csv")
                    print(statfile)
                    statfilepath = next(filter(lambda x: x.endswith(os.path.basename(statfile)), fstat))
                    misses1 = parse_perfstats(statfilepath, "L1-dcache-load-misses")
                    misses3 = parse_perfstats(statfilepath, "LLC-load-misses")
                    runresults.append(throughput)
                    runresults_cache1.append(misses1)
                    runresults_cache3.append(misses3)

                macss.append(macs)
                through_avg = np.average(runresults)
                throughputs.append(through_avg)
                through_stddevs.append(np.std(runresults))
                print(runresults_cache1)
                print(runresults_cache3)
                cachemisses1.append(np.average(runresults_cache1) / through_avg * 256 / 1000000)
                cachemisses1_stddevs.append(np.std(runresults_cache1) / through_avg * 256 / 1000000)
                cachemisses3.append(np.average(runresults_cache3) / through_avg * 256 / 1000000)
                cachemisses3_stddevs.append(np.std(runresults_cache3) / through_avg * 256 / 1000000)
    print(macss)
    print(throughputs)
    print(cachemisses1)
    print(cachemisses3)
    cachemisses1_smooth = gaussian_filter1d(cachemisses1, sigma=1)
    cachemisses3_smooth = gaussian_filter1d(cachemisses3, sigma=1)
    fig = plt.figure(figsize=(7, 4), dpi=160)
    axes = plt.gca() # swap axes
    ax2 = axes.twinx()
    #axes.set_ylim([0,150])
    #axes.set_xlim([0, 10000000])
    #axes.set_yscale("log")
    ax2.set_yscale('log')
    #axes.set_xscale("log", basex=10)
    #axes.axvline(color="gray", x=2048)
    #axes.text(2048, 8.4, " l1 cache")
    #axes.axvline(color="gray", x=16384)
    #axes.text(16384, 8.4, " l2 cache")
    #axes.axvline(color="gray", x=2097152)
    #axes.text(2097152, 8.4, " l3 cache")

    #ax2.axhline(color="gray", linewidth=0.5, y=15)
    g2,n0,n1 = ax2.errorbar(macss, cachemisses1, cachemisses1_stddevs, elinewidth=0.5, color=BLUE)
    n2,n0,n1 = ax2.errorbar(macss, cachemisses1_smooth, elinewidth=0.5, color=BLUE, linestyle=":")
    g1,n0,n1 = ax2.errorbar(macss, cachemisses3, cachemisses3_stddevs, elinewidth=0.5, color=ORANGE)
    n2,n0,n1 = ax2.errorbar(macss, cachemisses3_smooth, elinewidth=0.5, color=ORANGE, linestyle=":")
    g0,n0,n1 = axes.errorbar(macss, throughputs, through_stddevs, linewidth=3, elinewidth=0.5, color=GREEN) #, linestyle="-", marker=".")
    plt.title("sending from a few ip's")
    axes.set_ylabel("throughput (Mpps)")
    axes.set_xlabel("vpp workers (rss)")
    ax2.set_ylabel("cache misses per 256-packet vector")
    plt.legend([g0,g1, g2], ["throughput", "L3 load misses", "L1d load misses"], loc="center left")
    fig.tight_layout()
    #plt.grid(True)

    #return get_tikz_code(outf, show_info=False, figurewidth="48cm", figureheight="7cm")
    fig.savefig("throughput_{}.pdf".format(fileprefix))
    plt.show()

def throughput_per_cores_collect(fileprefix, flatency, fthroughput, fstat):
    macss = []
    throughputs = []
    through_stddevs = []
    cachemisses1 = []
    cachemisses1_stddevs = []
    cachemisses3 = []
    cachemisses3_stddevs = []
    txmin = []
    for throughfile in fthroughput: 
            filename = os.path.basename(throughfile)
            if fileprefix in filename and "_0." in filename:
                macs = int(filename.split(fileprefix)[1][0:2])
                runs = 6
                runresults = []
                runresults_cache1 = []
                runresults_cache3 = []
                txresults = []
                for run in range(0,runs):
                    print(run)
                    postfix = filename.split(fileprefix)[1]
                    postfix = "{}{}{}".format(postfix[0:3], run, postfix[4:])
                    nextfile = os.path.join(os.path.dirname(throughfile), "{}{}".format(fileprefix, postfix))
                    print(nextfile)
                    tx,n2,throughput,n3 = parse_throughput(nextfile)
                    statfile = nextfile[:-15]
                    statfile = "{}{}".format(nextfile[:-15], ".perfstat.csv")
                    print(statfile)
                    statfilepath = next(filter(lambda x: x.endswith(os.path.basename(statfile)), fstat))
                    misses1 = parse_perfstats(statfilepath, "L1-dcache-load-misses")
                    misses3 = parse_perfstats(statfilepath, "LLC-load-misses")
                    runresults.append(throughput)
                    runresults_cache1.append(misses1)
                    runresults_cache3.append(misses3)
                    txresults.append(tx)

                macss.append(macs)
                through_avg = np.average(runresults)
                throughputs.append(through_avg)
                through_stddevs.append(np.std(runresults))
                txmin.append(np.min(txresults))
                print(runresults_cache1)
                print(runresults_cache3)
                cachemisses1.append(np.average(runresults_cache1) / through_avg * 256 / 1000000)
                cachemisses1_stddevs.append(np.std(runresults_cache1) / through_avg * 256 / 1000000)
                cachemisses3.append(np.average(runresults_cache3) / through_avg * 256 / 1000000)
                cachemisses3_stddevs.append(np.std(runresults_cache3) / through_avg * 256 / 1000000)
    print(macss)
    print(throughputs)
    print(cachemisses1)
    print(cachemisses3)
    print(txmin)
    return macss, throughputs, through_stddevs, txmin

def throughput_per_cores_summary():

    # klaipeda, 3.2ghz, v18.10
    flatency, fthroughput, fstat = scrape_dirs('/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-03-15_21-17-06_287474/klaipeda/',
        '/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-03-15_21-17-06_287474/narva/')
    macss1, throughputs1, through_stddevs1, txmin1 = throughput_per_cores_collect("l3_multicore_", flatency, fthroughput, fstat)

    # klaipeda, 1.6ghz, v18.10
    flatency, fthroughput, fstat = scrape_dirs('/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-03-16_23-04-20_018896/klaipeda/',
        '/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-03-16_23-04-20_018896/narva/')
    macss2, throughputs2, through_stddevs2, txmin2 = throughput_per_cores_collect("l3_multicore_", flatency, fthroughput, fstat)
    
    # omastar, 2.2ghz, v18.10
    flatency, fthroughput, fstat = scrape_dirs('/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-03-12_21-04-57_933737/omastar/',
        '/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-03-12_21-04-57_933737/omanyte/')
    macss3, throughputs3, through_stddevs3, txmin3 = throughput_per_cores_collect("l3_multicore_", flatency, fthroughput, fstat)

    # omastar, 1.2ghz, v18.10
    flatency, fthroughput, fstat = scrape_dirs('/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-03-14_20-08-11_235402/omastar/',
        '/home/pogobanane/dev/ba/ba-okelmann/statistics/data/2019-03-14_20-08-11_235402/omanyte/')
    macss4, throughputs4, through_stddevs4, txmin4 = throughput_per_cores_collect("l3_multicore_", flatency, fthroughput, fstat)

    fig = plt.figure(figsize=(7, 4), dpi=160)
    axes = plt.gca() # swap axes
    #ax2 = axes.twinx()
    #axes.set_ylim([0,150])
    axes.set_xlim([0, 7])
    #axes.set_yscale("log")
    #ax2.set_yscale('log')
    #axes.set_xscale("log", basex=10)
    #axes.axvline(color="gray", x=2048)
    #axes.text(2048, 8.4, " l1 cache")
    #axes.axvline(color="gray", x=16384)
    #axes.text(16384, 8.4, " l2 cache")
    #axes.axvline(color="gray", x=2097152)
    #axes.text(2097152, 8.4, " l3 cache")

    n1,n1,n1 = axes.errorbar(macss1, txmin1, np.zeros(len(macss1)), linewidth=1, elinewidth=0.5, color="gray") #, linestyle="-", marker=".")
    n1,n1,n1 = axes.errorbar(macss2, txmin2, np.zeros(len(macss2)), linewidth=1, elinewidth=0.5, color="gray") #, linestyle="-", marker=".")
    n1,n1,n1 = axes.errorbar(macss3, txmin3, np.zeros(len(macss3)), linewidth=1, elinewidth=0.5, color="gray") #, linestyle="-", marker=".")
    n1,n1,n1 = axes.errorbar(macss4, txmin4, np.zeros(len(macss4)), linewidth=1, elinewidth=0.5, color="gray") #, linestyle="-", marker=".")

    g1,n1,n1 = axes.errorbar(macss1, throughputs1, through_stddevs1, linewidth=2, elinewidth=0.5, color=GREEN) #, linestyle="-", marker=".")
    g2,n2,n2 = axes.errorbar(macss2, throughputs2, through_stddevs2, linewidth=2, elinewidth=0.5, color=BLUE) #, linestyle="-", marker=".")
    g3,n1,n1 = axes.errorbar(macss3, throughputs3, through_stddevs3, linewidth=2, elinewidth=0.5, color=ORANGE) #, linestyle="-", marker=".")
    g4,n1,n1 = axes.errorbar(macss4, throughputs4, through_stddevs4, linewidth=2, elinewidth=0.5, color=PURPLE) #, linestyle="-", marker=".")

    axes.text(0.1, 15.1, "klaipeda tx (10GbE)")
    axes.axhline(color="gray", linewidth=1, y=14.88)
    axes.text(0.1, 19, "omastar tx (40GbE)")
    axes.axhline(color="gray", linewidth=1, y=20.5)

    plt.title("sending from a few ip's")
    axes.set_ylabel("throughput (Mpps)")
    axes.set_xlabel("vpp workers (rss)")
    #ax2.set_ylabel("cache misses per 256-packet vector")
    plt.legend([g1, g2, g3, g4], ["klaipeda @ 3.2GHz", "klaipeda @ 1.6GHz", "omastar @ 2.2GHz", "omastar @ 1.2GHz"], loc="lower right")
    fig.tight_layout()
    #plt.grid(True)

    #return get_tikz_code(outf, show_info=False, figurewidth="48cm", figureheight="7cm")
    fig.savefig("throughput_summary_multicore.pdf")
    plt.show()


#throughput_per_cores_summary()
#throughput_per_routes("l3_routes_")
#throughput_per_cores("l3_multicore_")
#throughput_per_routes("l3v6_routes_")
#throughput_per_cores("l3v6_multicore_")
#throughput_per_macs("l2_throughmac_")
latency_per_throughput() # for "l3_latroutes1_" and "l3_latroutes255k_"