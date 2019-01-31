local mg     = require "moongen"
local memory = require "memory"
local device = require "device"
local ts     = require "timestamping"
local stats  = require "stats"
local hist   = require "histogram"
local log    = require "log"

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

function statsTask(txDev, rxDev, logfile)
  local txCtr = stats:newDevTxCounter(txDev, "plain")
  local rxCtr = stats:newDevRxCounter(rxDev, "plain")
  while mg.running(200) do
    txCtr:update()
    rxCtr:update()
  end
  txCtr:finalize()
  rxCtr:finalize()
  logThroughput(txCtr, rxCtr, logfile)
end

function logLatency(hist, file)
  log:info(("Saving latency to '%s'"):format(file))
  file = io.open(file, "w+")
  file:write("samples,average_ns,stdDev_ns,quartile_25th,quartile_50th,quartile_75th\n")
  file:write(("%u,%f,%f,%f,%f,%f\n"):format(hist.numSamples, hist.avg, hist.stdDev, unpack(hist.quarts)))
  file:close()
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