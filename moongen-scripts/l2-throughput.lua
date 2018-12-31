local mg     = require "moongen"
local memory = require "memory"
local device = require "device"
local ts     = require "timestamping"
local stats  = require "stats"
local hist   = require "histogram"
local log    = require "log"


function configure(parser)
  parser:description("Generates CBR traffic with hardware rate control")
  parser:argument("txDev", "Device to send from."):convert(tonumber)
  parser:argument("rxDev", "Device to recieve from."):convert(tonumber)
  parser:option("-d --ethDst", "Target eth addr."):default("11:12:13:14:15:16"):convert(tostring)
  parser:option("-s --pktSize", "Packet size."):default(60):convert(tonumber)
  parser:option("-r --rate", "Transmit rate in Mbit/s."):default(10000):convert(tonumber)
  parser:option("-l --lafile", "Filename for the latency histogram."):default("histogram.csv")
  parser:option("-t --thfile", "Filename for the throughput csv file."):default("throuput.csv")
end

function master(args)
  local txDev = device.config({port = args.txDev, rxQueues = 2, txQueues = 2})
  local rxDev = device.config({port = args.rxDev, rxQueues = 2, txQueues = 2})
  device.waitForLinks()
  if args.rate > 0 then
    txDev:getTxQueue(0):setRate(args.rate)
    rxDev:getTxQueue(0):setRate(args.rate)
  end
  local recTask = mg.startTask("rxWarmup", rxDev:getRxQueue(0), 10000000)
  txWarmup(recTask, txDev:getTxQueue(0), args.ethDst, args.pktSize)
  mg.waitForTasks()
  mg.startTask("loadSlave", txDev:getTxQueue(0), rxDev, args.ethDst, args.pktSize, args.thfile)
  mg.startTask("timerSlave", txDev:getTxQueue(1), rxDev:getRxQueue(1), args.ethDst, args.lafile)
  mg.waitForTasks()
end

function logThroughput(txCtr, rxCtr, file)
  file = io.open(file, "w+")
  file:write("devDesc,mpps_avg,mpps_stdDev,mbit_avg,mbit_stdDev,wirembit_avg,bytes_total,packets_total\n")
  file:write(("txCtr,%f,%f,%f,%f,%f,%f,%f\n"):format(
    txCtr.mpps.avg, txCtr.mpps.stdDev,
    txCtr.mbit.avg, txCtr.mbit.stdDev,
    txCtr.wireMbit.avg,
    txCtr.total, txCtr.totalBytes
  ))
  file:write(("rxCtr,%f,%f,%f,%f,%f,%f,%f\n"):format(
    rxCtr.mpps.avg, rxCtr.mpps.stdDev,
    rxCtr.mbit.avg, rxCtr.mbit.stdDev,
    rxCtr.wireMbit.avg,
    rxCtr.total, rxCtr.totalBytes
  ))
  file:close()
end

local function fillUdpPacket(buf, eth_dst, len)
	buf:getUdpPacket():fill{
		ethSrc = txQueue,
		ethDst = eth_dst,
		ip4Src = "4.3.2.1",
		ip4Dst = "1.2.3.4",
		udpSrc = 1,
		udpDst = 2,
		pktLength = len
	}
end

local function fillEthPacket(buf, eth_dst)
  buf:getEthernetPacket():fill{
    ethSrc = txQueue,
    ethDst = eth_dst,
    ethType = 0x1234
  }
end

function loadSlave(txQueue, rxDev, eth_dst, pktSize, file)
  local mem = memory.createMemPool(function(buf)
    fillEthPacket(buf, eth_dst)
  end)
  local bufs = mem:bufArray()
	local txCtr = stats:newDevTxCounter(txQueue, "plain")
	local rxCtr = stats:newDevRxCounter(rxDev, "plain")
	-- local txCtrF = stats:newDevTxCounter(txQueue, "csv", "txthrouhput.csv")
	-- local rxCtrF = stats:newDevRxCounter(rxDev, "csv", "rxthroughput.csv")
  while mg.running() do
    bufs:alloc(pktSize)
    txQueue:send(bufs)
    txCtr:update()
    rxCtr:update()
  end
  txCtr:finalize()
  rxCtr:finalize()
  logThroughput(txCtr, rxCtr, file)
end

function timerSlave(txQueue, rxQueue, ethDst, histfile)
	local timestamper = ts:newTimestamper(txQueue, rxQueue)
	local hist = hist:new()
	mg.sleepMillis(1000) -- ensure that the load task is running
	while mg.running() do
		hist:update(timestamper:measureLatency(function(buf) buf:getEthernetPacket().eth.dst:setString(ethDst) end))
	end
	hist:print()
	hist:save(histfile)
end

-- recTask is only usable in master thread
function txWarmup(recTask, txQueue, eth_dst, pktSize)
  local mem = memory.createMemPool(function(buf)
    fillEthPacket(buf)
  end)
  local bufs = mem:bufArray(1)
  mg.sleepMillis(1000) -- ensure that waitWarmup is listening
  while recTask:isRunning() do
    bufs:alloc(pktSize)
    txQueue:send(bufs)
    log:info("warmup packet sent")
    mg.sleepMillis(1500)
  end
end

function rxWarmup(rxQueue, timeout)
	local bufs = memory.bufArray(128)

	log:info("waiting for first successful packet...")
	local rx = rxQueue:tryRecv(bufs, timeout)
	bufs:freeAll()
	if rx <= 0 then
		log:fatal("no packet could be received!")
	else
		log:info("first packet received")
	end
end
