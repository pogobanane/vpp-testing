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
  parser:description("Generates CBR ipv6 traffic with hardware rate control")
  parser:argument("txDev", "Device to send from."):convert(tonumber)
  parser:argument("rxDev", "Device to recieve from."):convert(tonumber)
  parser:option("--ethSrc", "Source eth addr."):default("00:11:22:33:44:55"):convert(tostring)
  parser:option("--ethDst", "Target eth addr."):default("de:ad:be:ef:00:02"):convert(tostring)
  parser:option("--ipSrc", "Source eth addr."):default("0:0:0:1::3"):convert(tostring)
  parser:option("--ipDst", "Target eth addr."):default("0:0:0:2::3"):convert(tostring)
  parser:option("-s --pktSize", "Packet size (payload + header; no CRC, preamble or inter packet gap)."):default(84):convert(tonumber)
  parser:option("-r --rate", "Transmit rate in Mbit/s."):default(100000):convert(tonumber)
  parser:option("-f --flows", "Number of flows (rotating source IP). Max 2^(6*8) flows. Can't be used with -o."):default(0):convert(tonumber)
  parser:option("-o --routes", "Number of /64 routes to send to (randomized dst IP). Max 2^(6*8) routes. Can't be used with -f."):default(0):convert(tonumber)
  parser:option("-h --hifile", "Filename for the latency histogram."):default("histogram.csv")
  parser:option("-t --thfile", "Filename for the throughput csv file."):default("throuput.csv")
  parser:option("-l --lafile", "Filename for latency summery file."):default("latency.csv")
end

function master(args)
  local txDev = device.config({port = args.txDev, rxQueues = 6, txQueues = 6})
  local rxDev = device.config({port = args.rxDev, rxQueues = 6, txQueues = 6})
  device.waitForLinks()
  if args.rate > 0 then
    txDev:getTxQueue(0):setRate(args.rate)
    rxDev:getTxQueue(0):setRate(args.rate)
  end
  local recTask = mg.startTask("rxWarmup", rxDev:getRxQueue(0), 10000000)
  txWarmup(recTask, txDev:getTxQueue(0), args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.pktSize)
  mg.waitForTasks()
  -- warmup done
  mg.startSharedTask("statsTask", txDev, rxDev, args.thfile)
  mg.startTask("loadSlave", txDev:getTxQueue(1), rxDev, args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.pktSize, args.flows, args.routes, args.thfile)
  mg.startTask("loadSlave", txDev:getTxQueue(2), rxDev, args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.pktSize, args.flows, args.routes, args.thfile)
  mg.startTask("loadSlave", txDev:getTxQueue(3), rxDev, args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.pktSize, args.flows, args.routes, args.thfile)
  mg.startTask("loadSlave", txDev:getTxQueue(4), rxDev, args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.pktSize, args.flows, args.routes, args.thfile)
  mg.startSharedTask("timerSlave", txDev:getTxQueue(0), rxDev:getRxQueue(0), args.pktSize, args.ethSrc, args.ethDst, args.ipSrc, args.ipDst, args.hifile, args.lafile)
  mg.waitForTasks()
end

local function fillUdpPacket(buf, eth_src, eth_dst, ip_src, ip_dst, len)
  buf:getUdpPacket(false):fill{
    ethSrc = eth_src,
    ethDst = eth_dst,
    ip6Src = ip_src,
    ip6Dst = ip_dst,
    udpSrc = 1,
    udpDst = 2,
    pktLength = len
  }
end

local function fillUdpPacketFlows(buf, eth_src, eth_dst, ip_src_nr, ip_dst, flows, len)
  local ip_src = ip_src_nr + random(0, flows-1) * 65536 -- flow mask 255.255.0.0 (2^16=65536)
  buf:getUdpPacket(false):fill{
    ethSrc = eth_src,
    ethDst = eth_dst,
    ip6Src = ip_src,
    ip6Dst = ip_dst,
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
    -- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
    -- but this breaks ipv6 traffic, so we dont offload checksums
    -- bufs:offloadUdpChecksums()
    txQueue:send(bufs)
  end
end

-- send from different src: rotate ip's
function sendIpFlows(bufs, txQueue, pktSize, flows, ipSrc)
  local counter = 0
  local baseIP = 3
  while mg.running() do
    bufs:alloc(pktSize)
    for i, buf in ipairs(bufs) do
      local pl = buf:getRawPacket().payload
      local src = baseIP + counter
      -- 14B ethernet header + 8B ip6 header = 22B
      -- [22,38) ip6 src addr
      -- least significant 6B of src addr: first 10B stay untouched
      pl.uint8[37] = bit.band(src, 0xFF)
      pl.uint8[36] = bit.band(bit.rshift(src, 8), 0xFF)
      pl.uint8[35] = bit.band(bit.rshift(src, 16), 0xFF)
      pl.uint8[34] = bit.band(bit.rshift(src, 24), 0xFF)
      pl.uint8[33] = bit.band(bit.rshift(src + 0ULL, 32ULL), 0xFF)
      pl.uint8[32] = bit.band(bit.rshift(src + 0ULL, 40ULL), 0xFF)
      counter = incAndWrap(counter, flows)
    end
    -- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
    -- but this breaks ipv6 traffic, so we dont offload checksums
    -- bufs:offloadUdpChecksums()
    txQueue:send(bufs)
  end
end

-- send to different locations: $routes amount of random /24 subnets
function sendIpRoutes(bufs, txQueue, pktSize, routes, ipDst)
  local baseIP = 3
  while mg.running() do
    bufs:alloc(pktSize)
    for i, buf in ipairs(bufs) do
      local dst = baseIP + random(0, routes)
      local pl = buf:getRawPacket().payload
      -- 14B ethernet header + 24B ip6 header and source addr = 38B
      -- [38,54) ip6 dst addr
      -- overwrite 6B of dst addr: first 2B and last 8B stay untouched
      -- but network byte order:
      pl.uint8[45] = bit.band(dst, 0xFF)
      pl.uint8[44] = bit.band(bit.rshift(dst, 8), 0xFF)
      pl.uint8[43] = bit.band(bit.rshift(dst, 16), 0xFF)
      pl.uint8[42] = bit.band(bit.rshift(dst, 24), 0xFF)
      pl.uint8[41] = bit.band(bit.rshift(dst + 0ULL, 32ULL), 0xFF)
      pl.uint8[40] = bit.band(bit.rshift(dst + 0ULL, 40ULL), 0xFF)
    end
    -- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
    -- but this breaks ipv6 traffic, so we dont offload checksums
    -- bufs:offloadUdpChecksums()
    txQueue:send(bufs)
  end
end

function loadSlave(txQueue, rxDev, eth_src, eth_dst, ip_src, ip_dst, pktSize, flows, routes, file)
  local ip_src_nr = parseIPAddress(ip_src)
  local mem = memory.createMemPool(function(buf)
    fillUdpPacket(buf, eth_src, eth_dst, ip_src, ip_dst, pktSize)
  end)
  local bufs = mem:bufArray()
  -- local txCtrF = stats:newDevTxCounter(txQueue, "csv", "txthrouhput.csv")
  -- local rxCtrF = stats:newDevRxCounter(rxDev, "csv", "rxthroughput.csv")
  if flows > 0 then
    sendIpFlows(bufs, txQueue, pktSize, flows, ip_src)
  elseif routes > 0 then
    sendIpRoutes(bufs, txQueue, pktSize, routes, ip_dst)
  else
    sendSimple(bufs, txQueue, pktSize)
  end
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
    fillUdpPacket(buf, eth_src, eth_dst, ip_src, ip_dst, pktSize)
  end)
  local bufs = mem:bufArray(1)
  mg.sleepMillis(1000) -- ensure that waitWarmup is listening
  while recTask:isRunning() do
    bufs:alloc(pktSize)
    -- bufs:offloadUdpChecksums()
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
