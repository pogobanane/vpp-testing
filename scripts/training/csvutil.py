import csv
from tqdm import tqdm
import pandas as pd
import numpy as np
import os 

# scrapes an array of folders and finds all histogram, throughput and perfstat csv files.
# only use filenames matching 
# returns an array of histogram file paths, an array of ...
def scrape_dirs(dirs, filematch=lambda fname: True):
    flatency = []
    fthroughput = []
    fstat = []
    fbatch = []

    for d in dirs:
        files_ = os.listdir(d)
        files = list(filter(filematch, files_))

        flatency_ = filter(lambda x: x.endswith('.histogram.csv'), files)
        flatency.extend(map(lambda x: os.path.join(d, x), flatency_))
        flatency = sorted(flatency)

        fthroughput_ = filter(lambda x: x.endswith('.throughput.csv'), files)
        fthroughput.extend(map(lambda x: os.path.join(d, x), fthroughput_))
        fthroughput = sorted(fthroughput)

        fstat_ = filter(lambda x: x.endswith('.perfstat.csv'), files)
        fstat.extend(map(lambda x: os.path.join(d, x), fstat_))
        fstat = sorted(fstat)

        fbatch_ = filter(lambda x: x.endswith(".badgesizes.csv"), files)
        fbatch.extend(map(lambda x: os.path.join(d, x), fbatch_))
        fbatch = sorted(fbatch)


    print("Histogram files: {}".format(len(flatency)))
    print("Throughput files: {}".format(len(fthroughput)))
    print("Perfstat files: {}".format(len(fstat)))
    print("Batchsize files: {}".format(len(fbatch)))
    return { "histogram": flatency, "throughput": fthroughput, "perfstat": fstat, "batchsize": fbatch} 


# return: tx mpps, tx stddev, rx mpps, rx stddev
def parse_throughput(csvfile, verbose=False):
    with open(csvfile, ) as f:
        reader = csv.reader(f)
        next(reader) # skip header line
        tx = next(reader)
        rx = next(reader)
        if verbose: print("{0:.2f}".format(float(rx[2])))
        ret = "tx: %.2fmpps, %.2fstdDev; rx: %.2fmpps, %.2fstdDev" % (float(tx[1]), float(tx[2]), float(rx[1]), float(rx[2]))
        if verbose: print(ret)
        return float(tx[1]), float(tx[2]), float(rx[1]), float(rx[2])
    return "err"


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
    for fname in flatency: # tqdm(flatency, ncols=0):
       
        s = fname.split('.')
        t = s[0].split('/')
        u = t[len(t)-1].split('-')
        for e in u:
            if 'rate' in e:
                rate = int(e.replace('rate', ''))
            elif 'pktsz' in e:
                psize = int(e.replace('pktsz', ''))
        df = pd.read_csv(fname, names=["latency", "weight"], header=1)
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

def parse_latencies_avg(histfile): 
    latencies, weights = parse_histogramfile(histfile)
    #print(latencies)
    quantiles = weighted_quantile(latencies, [0.5], sample_weight=weights, values_sorted=False)
    average = list(map(lambda u: (u / 1000), quantiles))[0]
    return average
