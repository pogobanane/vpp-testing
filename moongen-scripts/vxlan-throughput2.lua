local mg     = require "moongen"
local memory = require "memory"
local device = require "device"
local ts     = require "timestamping"
local stats  = require "stats"
local hist   = require "histogram"
local log    = require "log"
local random = math.random

package.path = package.path .. ";./throughput-util.lua"
require "throughput-util"

function configure(parser)
  parser:description("Generates CBR traffic with hardware rate control")
  parser:argument("txDev", "Device to send from."):convert(tonumber)
  parser:argument("rxDev", "Device to recieve from."):convert(tonumber)
  parser:option("--ethSrc", "Source eth addr."):default("00:11:22:33:44:55"):convert(tostring)
  parser:option("--ethDst", "Target eth addr."):default("00:00:00:00:00:00"):convert(tostring)
  parser:option("--ipSrc", "Source eth addr."):default("10.1.0.3"):convert(tostring)
  parser:option("--ipDst", "Target eth addr."):default("10.2.0.3"):convert(tostring)
  parser:option("-s --pktSize", "Packet size (payload + header; no CRC, preamble or inter packet gap)."):default(60):convert(tonumber)
  parser:option("-r --rate", "Transmit rate in Mbit/s."):default(10000):convert(tonumber)
  parser:option("-h --hifile", "Filename for the latency histogram."):default("histogram.csv")
  parser:option("-t --thfile", "Filename for the throughput csv file."):default("throuput.csv")
  parser:option("-l --lafile", "Filename for latency summery file."):default("latency.csv")
end

function master(args)
  local txDev = device.config({port = args.txDev, rxQueues = 3, txQueues = 3})
  local rxDev = device.config({port = args.rxDev, rxQueues = 3, txQueues = 3})
  device.waitForLinks()
  if args.rate > 0 then
    txDev:getTxQueue(0):setRate(args.rate)
    rxDev:getTxQueue(0):setRate(args.rate)
  end
  local recTask = mg.startTask("rxWarmup", rxDev:getRxQueue(0), 10000000)
  txWarmup(recTask, txDev:getTxQueue(0), args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.pktSize)
  mg.waitForTasks()
  -- warmup done
  mg.startTask("statsTask", txDev, rxDev, args.thfile)
  mg.startTask("loadSlave", txDev:getTxQueue(1), rxDev, args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.pktSize, args.thfile)
  mg.startTask("loadSlave", txDev:getTxQueue(2), rxDev, args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.pktSize, args.thfile)
  mg.startTask("timerSlave", txDev:getTxQueue(0), rxDev:getRxQueue(0), args.pktSize, args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.hifile, args.lafile)
  mg.waitForTasks()
end

local function fillUdpPacket(buf, eth_src, eth_dst, ip_src, ip_dst, len)
  buf:getUdpPacket():fill{
    ethSrc = eth_src,
    ethDst = eth_dst,
    ip4Src = ip_src,
    ip4Dst = ip_dst,
    udpSrc = 1,
    udpDst = 2,
    pktLength = len
  }
end

local function fillEthPacket(buf, eth_src, eth_dst)
  buf:getEthernetPacket():fill{
    ethSrc = eth_src,
    ethDst = eth_dst,
    ethType = 0x1234
  }
end

function sendSimple(bufs, txQueue, pktSize)
  while mg.running() do
    bufs:alloc(pktSize)
    -- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
    -- bufs:offloadUdpChecksums() this is no udp traffic
    txQueue:send(bufs)
  end
end

function loadSlave(txQueue, rxDev, eth_src, eth_dst, ip_src, ip_dst, pktSize, file)
  local ip_src_nr = parseIPAddress(ip_src)
  local mem = memory.createMemPool(function(buf)
    fillEthPacket(buf, eth_src, eth_dst)
  end)
  local bufs = mem:bufArray()
  -- local txCtrF = stats:newDevTxCounter(txQueue, "csv", "txthrouhput.csv")
  -- local rxCtrF = stats:newDevRxCounter(rxDev, "csv", "rxthroughput.csv")
  sendSimple(bufs, txQueue, pktSize)
end

function timerSlave(txQueue, rxQueue, size, eth_src, eth_dst, ip_src, ip_dst, histfile, lafile)
  if size < 84 then
    log:warn("Packet size %d is smaller than minimum timestamp size 84. Timestamped packets will be larger than load packets.", size)
    size = 84
  end
	local timestamper = ts:newUdpTimestamper(txQueue, rxQueue)
	local hist = hist:new()
	mg.sleepMillis(1000) -- ensure that the load task is running
	while mg.running() do
		hist:update(timestamper:measureLatency(size, function(buf)
      fillUdpPacket(buf, eth_src, eth_dst, ip_src, ip_dst, size)
    end))
	end
	hist:print()
	hist:save(histfile)
  logLatency(hist, lafile)
end

-- recTask is only usable in master thread
function txWarmup(recTask, txQueue, eth_src, eth_dst, ip_src, ip_dst, pktSize)
  local mem = memory.createMemPool(function(buf)
    fillEthPacket(buf, eth_src, eth_dst)
  end)
  local bufs = mem:bufArray(1)
  mg.sleepMillis(1000) -- ensure that waitWarmup is listening

  local c = 0
  while recTask:isRunning() do
    bufs:alloc(pktSize)

    -- dump first packet to see what we send
    if c < 1 then
      log:info("Sent frame:")
      bufs[1]:dump()
      c = c + 1
    end

    bufs:offloadUdpChecksums()
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
		log:info("first packet received:")
    bufs[1]:dump()
	end
end
