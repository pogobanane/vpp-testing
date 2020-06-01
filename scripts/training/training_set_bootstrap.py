#!/usr/bin/python3

import argparse
import csv
import os.path
import random

import csvutil

parser = argparse.ArgumentParser(description="Create a initial boostrapping trainingset for ranger by taking .badgesizes.csv files or a pos upload folder as input.")
parser.add_argument("inputfile")
parser.add_argument("-t", "--training_set", help="validation set desitination")
parser.add_argument("-a", "--validation_set")
parser.add_argument("-n", default=1, type=int, help="Maximum number of stub predictions to generate.")
parser.add_argument("-p", "--port", default=0, type=int)
parser.add_argument("-q", "--queue", default=0, type=int)
args = parser.parse_args()

def write_stub(reader, writer, result=True):
    # skip some
    skip = random.randrange(2, 200)
    for i in range(skip):
        rrow = next(reader)

    # read&write 100 and stub prediction
    wrow = []
    for i in range(100):
        # wait for correct port and queue
        while (int(rrow[0]) != args.port or int(rrow[1]) != args.queue):
            rrow = next(reader)
        wrow.append(rrow[2])
        rrow = next(reader)
    if result: wrow.append(-1)
    writer.writerow(wrow)

# append n datasets of finput to training_set and validation_set file
def extract_sets(training_set, validation_set, finput, n):
    with open(training_set, "a") as csvtrain:
        with open(validation_set, "a") as csvval:
            # old batchsize -> new batchsize
            # batchsize0,batchsize1,...,batchsize99,rangerResult
            trainwriter = csv.writer(csvtrain, delimiter=',')
            validwriter = csv.writer(csvval, delimiter=',')
            with open(finput, "r") as csvin: 
                # port,queue,batchsize
                reader = csv.reader(csvin, delimiter=',')
                b = False

                for i in range(n):
                    try:
                        write_stub(reader, trainwriter)
                        write_stub(reader, validwriter, result=False)

                    except StopIteration:
                        print("Reached EOF after " + i + " stub predictions.")
                        break

# whether to add result column
def write_header(setfile, result=True):
    with open(setfile, "w") as f:
        w = csv.writer(f, delimiter=",")
        row = []
        for i in range(100):
            row.append("a{}".format(i))
        if result: row.append("result")

        w.writerow(row)


def main(): 

    if os.path.isdir(args.inputfile):
        dirs = [
                os.path.join(args.inputfile, "klaipeda"), 
                os.path.join(args.inputfile, "narva"),
                os.path.join(args.inputfile, "omastar"),
                os.path.join(args.inputfile, "omanyte")
               ]
        dirs = filter(lambda x: os.path.isdir(x), dirs)
        print("Using folders: {}".format(list(dirs)))
        paths = csvutil.scrape_dirs(dirs, filematch=lambda filename: filename.startswith("l2_xconext_000256_0064_"))
        training_set = args.training_set
        validation_set = args.validation_set
        print("Writing into " + training_set + " and " + validation_set)

        write_header(training_set)
        write_header(validation_set, result=False)
        for fbatch in paths["batchsize"]:
            print(fbatch)
            extract_sets(training_set, validation_set, fbatch, args.n)
            
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
