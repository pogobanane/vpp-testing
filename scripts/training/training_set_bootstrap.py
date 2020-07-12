#!/usr/bin/python3

import argparse
import csv
import os.path
import random

import csvutil

parser = argparse.ArgumentParser(description="Create a initial boostrapping trainingset for ranger by taking .badgesizes.csv files or a pos upload folder as input.")
parser.add_argument("inputfile")
parser.add_argument("-t", "--training_set", help="validation set desitination")
parser.add_argument("-r", action="store_true", help="use hardcoded training results")
parser.add_argument("-a", "--validation_set")
parser.add_argument("-n", default=1, type=int, help="Maximum number of stub predictions to generate.")
parser.add_argument("-i", "--inputs", default=100, type=int, help="Count of inputs for a ranger prediction")
parser.add_argument("-p", "--port", default=0, type=int)
parser.add_argument("-q", "--queue", default=0, type=int)
args = parser.parse_args()

# inputs: count of inputs for a ranger prediction
def write_stub(reader, writer, inputs, result=None):
    # skip some
    skip = random.randrange(2, 2*(inputs+1))
    for i in range(skip):
        rrow = next(reader)

    # read&write 100 and one stub prediction
    wrow = []
    for i in range(inputs):
        # wait for correct port and queue
        while (int(rrow[0]) != args.port or int(rrow[1]) != args.queue):
            rrow = next(reader)
        wrow.append(rrow[2])
        rrow = next(reader)
    if result is not None: wrow.append(result)
    writer.writerow(wrow)

# append n datasets of finput to training_set and validation_set file

def extract_sets(training_set, validation_set, finput, n, training_map=None):
    with open(training_set, "a") as csvtrain:
        with open(validation_set, "a") as csvval:
            # old batchsize -> new batchsize
            # batchsize0,batchsize1,...,batchsize99,rangerResult
            trainwriter = csv.writer(csvtrain, delimiter=',', lineterminator="\n")
            validwriter = csv.writer(csvval, delimiter=',', lineterminator="\n")
            with open(finput, "r") as csvin: 
                # port,queue,batchsize
                reader = csv.reader(csvin, delimiter=',')
                b = False

                for i in range(n):
                    try:
                        write_stub(reader, validwriter, args.inputs)
                        map_key = None
                        if training_map is None:
                            write_stub(reader, validwriter, args.inputs) 
                        else:
                            for x in training_map.keys():
                                if x in finput:
                                    map_key = x
                            if map_key is not None:
                                write_stub(reader, trainwriter, args.inputs, result=training_map[map_key])

                    except StopIteration:
                        print("Reached EOF after " + i + " stub predictions.")
                        break

def main(): 

    if os.path.isdir(args.inputfile):
        dirs = [
                os.path.join(args.inputfile, "klaipeda"), 
                os.path.join(args.inputfile, "narva"),
                os.path.join(args.inputfile, "omastar"),
                os.path.join(args.inputfile, "omanyte")
               ]
        dirs = list(filter(lambda x: os.path.isdir(x), dirs))
        print("Using folders: {}".format(dirs))
        paths = csvutil.scrape_dirs(dirs, filematch=lambda filename: filename.startswith("l2_xconext_000256_0064_"))
        training_set = args.training_set
        validation_set = args.validation_set
        print("Writing into " + training_set + " and " + validation_set)

        csvutil.write_header(training_set, args.inputs)
        csvutil.write_header(validation_set, args.inputs, result=False)

        training_filter = {}
        training_filter["l2_xconext_000256_0064_001000"] = 100
        training_filter["l2_xconext_000256_0064_005000"] = 1
        training_filter["l2_xconext_000256_0064_010000"] = 0
        if not args.r:
            training_filter = None

        for fbatch in paths["batchsize"]:
            print(fbatch)
            extract_sets(training_set, validation_set, fbatch, args.n, training_map=training_filter)
            
    else:
        (inpath, infile) = os.path.split(args.inputfile)
        training_set = args.training_set
        if training_set == None:
            train = "trainingset_" + infile
        validation_set = args.validation_set
        if validation_set == None:
            val = "validationset_" + infile
        print("Writing into " + training_set + " and " + validation_set)

        extract_sets(train, val, args.inputfile, args.n)

main()
