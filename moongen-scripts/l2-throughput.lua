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
  parser:option("-f --file", "Filename for the latency histogram."):default("histogram.csv")
end

function master(args)
  local txDev = device.config({port = args.txDev, rxQueues = 2, txQueues = 2})
  local rxDev = device.config({port = args.rxDev, rxQueues = 2, txQueues = 2})
  device.waitForLinks()
  if args.rate > 0 then
    txDev:getTxQueue(0):setRate(args.rate)
    rxDev:getTxQueue(0):setRate(args.rate)
  end
  mg.startTask("txWarmup", txDev:getTxQueue(0), args.ethDst, args.pktSize)
  mg.startTask("rxWarmup", rxDev:getRxQueue(0), 10000000)
  mg.waitForTasks()
end

function loadSlave(txQueue, eth_dst, pktSize)
  local mem = memory.createMemPool(function(buf)
    buf:getEthernetPacket():fill{
      ethSrc = txQueue,
      ethDst = eth_dst,
      ethType = 0x1234
    }
  end)
  local bufs = mem:bufArray()
  while mg.running() do
    bufs:alloc(pktSize)
    txDev:send(bufs)
  end
end

function txWarmup(txQueue, eth_dst, pktSize)
  local mem = memory.createMemPool(function(buf)
    buf:getEthernetPacket():fill{
      ethSrc = txQueue,
      ethDst = eth_dst,
      ethType = 0x1234
    }
  end)
  local bufs = mem:bufArray(1)
  mg.sleepMillis(1000) -- ensure that waitWarmup is listening
  bufs:alloc(pktSize)
  txQueue:send(bufs)
  log:info("first packet sent")
end

function rxWarmup(rxQueue, timeout)
	local bufs = memory.bufArray(128)

	log:info("waiting for first successful packet...")
	local rx = rxQueue:tryRecv(bufs, timeout)
	bufs:freeAll()
	if rx <= 0 then
		log:error("no packet could be received!")
	else
		log:info("first packet received")
	end
end
