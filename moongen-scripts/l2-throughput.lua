local mg     = require "moongen"
local memory = require "memory"
local device = require "device"
local stats  = require "stats"
local hist   = require "histogram"
local timer  = require "timer"
local log    = require "log"
local random = math.random
local table = table 

package.path = package.path .. ";./throughput-util.lua;./timestampingnonhist.lua"
require "throughput-util"
local ts     = require "timestampingnonhist"

function configure(parser)
  parser:description("Generates CBR traffic with hardware rate control")
  parser:argument("txDev", "Device to send from."):convert(tonumber)
  parser:argument("rxDev", "Device to recieve from."):convert(tonumber)
  parser:option("--ethSrc", "Source eth addr."):default("00:11:22:33:44:55"):convert(tostring)
  parser:option("-d --ethDst", "Target eth addr. (network BO if using --macs)"):default("00:00:00:00:00:00"):convert(tostring)
  parser:option("-s --pktSize", "Packet size."):default(60):convert(tonumber)
  parser:option("-r --rate", "Transmit rate in Mbit/s."):default(10000):convert(tonumber)
  parser:option("-m --macs", "Send to (ethDst...ethDst+macs)."):default(0):convert(tonumber)
  parser:option("-h --hifile", "Filename for the latency histogram."):default("histogram.csv")
  parser:option("-t --thfile", "Filename for the throughput csv file."):default("throuput.csv")
  parser:option("-l --lafile", "Filename for latency summary file."):default("latency.csv")
end

function master(args)
  local txDev = device.config({port = args.txDev, rxQueues = 2, txQueues = 2})
  local rxDev = device.config({port = args.rxDev, rxQueues = 2, txQueues = 2})
  device.waitForLinks()
  if args.rate > 0 then
    local rate = ( args.rate / (args.pktSize + 24) ) * (args.pktSize + 4)
    txDev:getTxQueue(0):setRate(rate)
    rxDev:getTxQueue(0):setRate(rate)
  end
  local recTask = mg.startTask("rxWarmup", rxDev:getRxQueue(0), 10000000)
  txWarmup(recTask, txDev:getTxQueue(0), args.ethSrc, args.ethDst, args.pktSize)
  mg.waitForTasks()
  -- warmup done
  mg.startTask("statsTask", txDev, rxDev, args.thfile)
  mg.startTask("loadSlave", txDev:getTxQueue(0), rxDev, args.ethSrc, args.ethDst, args.pktSize, args.macs, args.thfile)
  mg.startTask("timerSlaveNonhist", txDev:getTxQueue(1), rxDev:getRxQueue(1), args.ethDst, args.hifile, args.lafile)
  mg.waitForTasks()
end

local function fillUdpPacket(buf, eth_src, eth_dst, len)
	buf:getUdpPacket():fill{
		ethSrc = eth_src,
		ethDst = eth_dst,
		ip4Src = "4.3.2.1",
		ip4Dst = "1.2.3.4",
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

local function fillEthPacketMacs(buf, eth_src, eth_dst_base, macs)
  local dst = eth_dst_base + random(0, macs-1) * 2
  buf:getEthernetPacket():fill{
    ethSrc = eth_src,
    ethDst = eth_dst,
    ethType = 0x1234
  }
  local pl = buf:getRawPacket().payload
  pl.uint8[5] = bit.band(dst, 0xFF)
  pl.uint8[4] = bit.band(bit.rshift(dst, 8), 0xFF)
  pl.uint8[3] = bit.band(bit.rshift(dst, 16), 0xFF)
  pl.uint8[2] = bit.band(bit.rshift(dst, 24), 0xFF)
  pl.uint8[1] = bit.band(bit.rshift(dst + 0ULL, 32ULL), 0xFF)
  pl.uint8[0] = bit.band(bit.rshift(dst + 0ULL, 40ULL), 0xFF)
end

function sendPoisson(bufs, txQueue, txCtr, rxCtr, pktSize, rate)
  while mg.running() do
    bufs:alloc(pktSize)
    for _, buf in ipairs(bufs) do
      -- this script uses Mpps instead of Mbit (like the other scripts)
      buf:setDelay(poissonDelay(10^10 / 8 / (rate * 10^6) - pktSize - 24))
      --buf:setRate(rate)
    end
    txCtr:updateWithSize(txQueue:sendWithDelay(bufs), pktSize)
    rxCtr:update()
  end
end

function sendSimple(bufs, txQueue, pktSize)
  while mg.running() do
    bufs:alloc(pktSize)
    txQueue:send(bufs)
    end
end

function sendMacFlows(bufs, txQueue, pktSize, eth_dst_nr, macs)
  while mg.running() do
    bufs:alloc(pktSize)
    for i, buf in ipairs(bufs) do
      local dst = eth_dst_nr + random(0, macs-1) * 2
      local pl = buf:getRawPacket().payload
      pl.uint8[5] = bit.band(dst, 0xFF)
      pl.uint8[4] = bit.band(bit.rshift(dst, 8), 0xFF)
      pl.uint8[3] = bit.band(bit.rshift(dst, 16), 0xFF)
      pl.uint8[2] = bit.band(bit.rshift(dst, 24), 0xFF)
      pl.uint8[1] = bit.band(bit.rshift(dst + 0ULL, 32ULL), 0xFF)
      pl.uint8[0] = bit.band(bit.rshift(dst + 0ULL, 40ULL), 0xFF)
    end
    txQueue:send(bufs)
  end
end

-- unfinished
-- bufs: getudppacket fills!
-- multiple flows from devices or to devices?
-- to deviecs -> have to fill arps for them
-- from devices -> overhead from arp filling
function sendIPs(bufs, txQueue, txCtr, rxCtr, pktSize, baseIP, flows)
  local counter = 0
  local baseIpNr = parseIPAddress(baseIP)
  while mg.running() do
    bufs:alloc(pktSize)
    for _, buf in ipairs(bufs) do
      local pkt = buf:getUdpPacket()
      pkt.ip4.dst:set(baseMacNr + counter)
      counter = incAndWrap(counter, flows) -- starts to increment the leftmost byte to test subnets when flows is not max value but valueCount
    end
    -- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
    bufs:offloadUdpChecksums()
    txQueue:send(bufs)
    txCtr:update()
    rxCtr:update()
  end
end

function loadSlave(txQueue, rxDev, eth_src, eth_dst, pktSize, macCount, file)
  local eth_dst_nr = parseMacAddress(eth_dst, 1)
  local mem = memory.createMemPool(function(buf)
    fillEthPacket(buf, eth_src, eth_dst)
  end)
  local bufs = mem:bufArray()
  if macCount > 0 then
    sendMacFlows(bufs, txQueue, pktSize, eth_dst_nr, macCount)
  else
    sendSimple(bufs, txQueue, pktSize)
  end
end

-- produces latency histogram
function timerSlave(txQueue, rxQueue, ethDst, histfile, lafile)
	local timestamper = ts:newTimestamper(txQueue, rxQueue)
	local hist = hist:new()
  local rateLimit = timer:new(0.001)
	mg.sleepMillis(1000) -- ensure that the load task is running
	while mg.running() do
		hist:update(timestamper:measureLatency(function(buf) buf:getEthernetPacket().eth.dst:setString(ethDst) end))
    rateLimit:wait()
    rateLimit:reset()
	end
	hist:print()
	hist:save(histfile)
  logLatency(hist, lafile)
end

-- produces latency list
function timerSlaveNonhist(txQueue, rxQueue, ethDst, histfile, lafile)
  local timestamper = ts:newTimestamper(txQueue, rxQueue)
  local rateLimit = timer:new(0.001)
  local latencies = {}
  local txTimestamps = {}
  mg.sleepMillis(1000) -- ensure that the load task is running
  while mg.running() do
    local lat, numPkts, tx = timestamper:measureLatency(function(buf) buf:getEthernetPacket().eth.dst:setString(ethDst) end)
    if lat and tx then
      table.insert(latencies, lat)
      table.insert(txTimestamps, tx)
    end
    rateLimit:wait()
    rateLimit:reset()
  end
  local file = "latencies.csv"
  log:info(("Saving latency to '%s'"):format(file))
  file = io.open(file, "w+")
  file:write("txTimestamps,latencies(nanoSec?)\n")
  for i = 1, #latencies, 1 do
    file:write(("%u,%u\n"):format(txTimestamps[i], latencies[i]))
  end
  file:close()
end

-- recTask is only usable in master thread
function txWarmup(recTask, txQueue, eth_src, eth_dst, pktSize)
  local mem = memory.createMemPool(function(buf)
    fillEthPacket(buf, eth_src, eth_dst)
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
