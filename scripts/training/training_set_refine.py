#!/usr/bin/python3

import argparse
import os
import re
import numpy

import csvutil

parser = argparse.ArgumentParser(description="Use test results to refine the dataset.")
parser.add_argument("pos_upload", help="Location for pos_uploads containing $DUT and $LOADGEN")
parser.add_argument("dut")
parser.add_argument("loadgen")
parser.add_argument("-o", "--outfile", default="trainingset.csv", type=str, help="File to write refined trainingset to.")

RANGER_INPUTS = 100

args = parser.parse_args()

dutfiles = os.listdir(args.pos_upload + "/" + args.dut)
dutfiles = filter(lambda x: 
            re.search("^l2_training_00000000_0064_.*\.forestio.csv$", x)
        , dutfiles)
dutfiles = sorted(dutfiles)


def reward_function(prefix, latency, latmax, throughput, cycles):
    # packets per cpu time with bonus for little latency TODO
    reward = - 0.5 * latency + (4000 * throughput) / ( 0.00000001 * cycles )
    #print("- {:.0f} + {:.0f} / {:.0f} = {:.0f}".format(latency, throughput, cycles, reward))
    print("{} = {: 4.0f}: {:.0f}c {}ys ({}) @ {}mpps".format(prefix, reward, cycles, latency, latmax, throughput)) 
    return reward

def calculate_reward(batchfile):
    prefix = batchfile.split(".")[0]

    throughputfile = os.path.join(args.pos_upload, args.loadgen, prefix + ".throughput.csv")
    throughput = csvutil.parse_throughput(throughputfile)[2]

    latfile = os.path.join(args.pos_upload, args.loadgen, prefix + ".latencies.csv")
    latency, maxi = csvutil.parse_latencies_avg(latfile)

    forestiofile = os.path.join(args.pos_upload, args.dut, prefix + ".forestio.csv")
    trainingrows = csvutil.parse_forestio(forestiofile)

    statfile = os.path.join(args.pos_upload, args.dut, prefix + ".perfstat.csv")
    cycles = csvutil.parse_perfstats(statfile, "cpu-cycles") 

    reward = reward_function(prefix, latency, maxi, throughput, cycles)
    return prefix, reward, trainingrows

# returns: array of scenario
# scenario: array of tuple<reward, dataset_row>
def calculate_rewards():
    rewards = []

    # for each tested scenario
    for batchfile in dutfiles:
        rewards.append(calculate_reward(batchfile))

    return rewards

def trainingrows_avg_result(trainingrows):
    #return numpy.mean(list(map(lambda x: x[-1], trainingrows)))
    a = []
    for row in trainingrows:
        a.append(int(row[-1]))
    return numpy.mean(a)

def positive_random_normal(center, stddev):
    r = numpy.random.normal(center, stddev)
    while r < 0:
        r = numpy.random.normal(center, stddev)
    return r

# changes the prediction to train for. 
# the worse the scenario did, the more randomly deviate from the prediction
def refine_scenario(prefix, reward, trainingrows):
    reward_min = -10
    reward_max = 120
    reward = max(reward, reward_min)
    reward = min(reward, reward_max)
    reward -= reward_min 
    # 0 < reward < 100
    p_deviate = 1 - (reward / (numpy.abs(reward_min) + numpy.abs(reward_max))) # normalized deviation
    stddev = 30 * pow(p_deviate, 2)
    old_prediction = trainingrows_avg_result(trainingrows)
    new_prediction = int(positive_random_normal(old_prediction, stddev))
    for row in trainingrows:
        row[-1] = new_prediction

    print("{}: {} --{:.1f}--> {}".format(prefix, old_prediction, stddev, new_prediction)) 
    return trainingrows

def write_dataset(filename, trainingrows):
    csvutil.write_header(filename, RANGER_INPUTS) 
    csvutil.append_trainingset(filename, trainingrows)

rewarded_scenarios = calculate_rewards()

refined_trainingset = []
for prefix, reward, trainingrows in rewarded_scenarios:
    refined_trainingset = refined_trainingset + refine_scenario(prefix, reward, trainingrows)

#print(refined_trainingset)
write_dataset(args.outfile, refined_trainingset)

# TODO only keep best 30% and dont forget randomness

