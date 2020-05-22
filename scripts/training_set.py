import argparse
import csv
import os.path
import random

parser = argparse.ArgumentParser(description="Create a initial boostrapping trainingset for ranger by taking .badgesizes.csv files as input.")
parser.add_argument("inputfile")
parser.add_argument("-o", "--output")
parser.add_argument("-n", default=1, type=int, help="Maximum number of stub predictions to generate.")
parser.add_argument("-p", "--port", default=0, type=int)
parser.add_argument("-q", "--queue", default=0, type=int)
args = parser.parse_args()

(inpath, infile) = os.path.split(args.inputfile)
outfile = args.output
if outfile == None:
    outfile = "trainingset_" + infile

print("Writing into " + outfile)



with open(outfile, "w") as csvout:
    # batchsize0,batchsize1,...,batchsize99,rangerResult
    writer = csv.writer(csvout, delimiter=',')
    with open(args.inputfile, "r") as csvin: 
        # port,queue,batchsize
        reader = csv.reader(csvin, delimiter=',')
        b = False

        for n in range(args.n):
            try:
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

                wrow.append(-1)
                writer.writerow(wrow)
            except StopIteration:
                print("Reached EOF after " + n + " stub predictions.")
                break


