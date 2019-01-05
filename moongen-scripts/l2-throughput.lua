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
  parser:option("--ethSrc", "Source eth addr."):default("00:11:22:33:44:55"):convert(tostring)
  parser:option("-d --ethDst", "Target eth addr."):default("20:00:00:00:00:00"):convert(tostring)
  parser:option("-s --pktSize", "Packet size."):default(60):convert(tonumber)
  parser:option("-r --rate", "Transmit rate in Mbit/s."):default(10000):convert(tonumber)
  parser:option("-m --macs", "Send to (ethDst...ethDst+macs)."):default(0):convert(tonumber)
  parser:option("-h --hifile", "Filename for the latency histogram."):default("histogram.csv")
  parser:option("-t --thfile", "Filename for the throughput csv file."):default("throuput.csv")
  parser:option("-l --lafile", "Filename for latency summery file."):default("latency.csv")
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
  txWarmup(recTask, txDev:getTxQueue(0), args.ethSrc, args.ethDst, args.pktSize)
  mg.waitForTasks()
  mg.startTask("loadSlave", txDev:getTxQueue(0), rxDev, args.ethSrc, args.ethDst, args.pktSize, args.macs, args.thfile)
  mg.startTask("timerSlave", txDev:getTxQueue(1), rxDev:getRxQueue(1), args.ethDst, args.hifile, args.lafile)
  mg.waitForTasks()
end

function logThroughput(txCtr, rxCtr, file)
  log:info(("Saving throughput to '%s'"):format(file))
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

function logLatency(hist, file)
  log:info(("Saving latency to '%s'"):format(file))
  file = io.open(file, "w+")
  file:write("samples,average_ns,stdDev_ns,quartile_25th,quartile_50th,quartile_75th\n")
  file:write(("%u,%f,%f,%f,%f,%f\n"):format(hist.numSamples, hist.avg, hist.stdDev, unpack(hist.quarts)))
  file:close()
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

function sendSimple(bufs, txQueue, txCtr, rxCtr, pktSize)
  while mg.running() do
    bufs:alloc(pktSize)
    txQueue:send(bufs)
    txCtr:update()
    rxCtr:update()
  end
end

-- unfinished
-- bufs: getudppacket fills!
-- multiple flows from devices or to devices?
-- to deviecs -> have to fill arps for them
-- from devices -> overhead from arp filling
function sendMacs(bufs, txQueue, txCtr, rxCtr, pktSize, baseIP, flows)
  local counter = 0
  local baseIpNr = parseIPAddress(baseIP)
  while mg.running() do
    bufs:alloc(pktSize)
    for _, buf in ipairs(bufs) do
      local pkt = buf:getUdpPacket()
      pkt.ip4.dst:set(baseMacNr + counter)
      counter = incAndWrap(counter, flows) -- starts to increment the leftmost byte to test subnets
    end
    -- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
    bufs:offloadUdpChecksums()
    txQueue:send(bufs)
    txCtr:update()
    rxCtr:update()
  end
end

function sendMacs(bufs, txQueue, txCtr, rxCtr, pktSize, baseMac, flows)
  local counter = 0
  local baseMacNr = parseMacAddress(baseMac, 1)
  while mg.running() do
    bufs:alloc(pktSize)
    for _, buf in ipairs(bufs) do
      local pkt = buf:getEthernetPacket()
      pkt.eth.dst:set(baseMacNr + counter)
      counter++
      counter %= flows
    end
    -- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
    bufs:offloadUdpChecksums()
    txQueue:send(bufs)
    txCtr:update()
    rxCtr:update()
  end
end

function loadSlave(txQueue, rxDev, eth_src, eth_dst, pktSize, macCount, file)
  local mem = memory.createMemPool(function(buf)
    fillEthPacket(buf, eth_src, eth_dst)
  end)
  local bufs = mem:bufArray()
	local txCtr = stats:newDevTxCounter(txQueue, "plain")
	local rxCtr = stats:newDevRxCounter(rxDev, "plain")
	-- local txCtrF = stats:newDevTxCounter(txQueue, "csv", "txthrouhput.csv")
	-- local rxCtrF = stats:newDevRxCounter(rxDev, "csv", "rxthroughput.csv")
  if macCount > 0 then
    sendMacs(bufs, txQueue, txCtr, rxCtr, pktSize, eth_dst, macCount)
  else
    sendSimple(bufs, txQueue, txCtr, rxCtr, pktSize)
  end
  txCtr:finalize()
  rxCtr:finalize()
  logThroughput(txCtr, rxCtr, file)
end

function timerSlave(txQueue, rxQueue, ethDst, histfile, lafile)
	local timestamper = ts:newTimestamper(txQueue, rxQueue)
	local hist = hist:new()
	mg.sleepMillis(1000) -- ensure that the load task is running
	while mg.running() do
		hist:update(timestamper:measureLatency(function(buf) buf:getEthernetPacket().eth.dst:setString(ethDst) end))
	end
	hist:print()
	hist:save(histfile)
  logLatency(hist, lafile)
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
