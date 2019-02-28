-- This script can be used to both simulate and test a VTEP
-- isEndpoint isTunneled determine what this script does:
-- 0 0: Send ethernet frames, expect to receive VXLAN packets (the encapsulated ethernet frame)
-- 0 1: Send VXLAN packet, expect to receive the decapsulated ethernet frame
-- 1 0: Receive ethernet frames, encapsulate them, send VXLAN packet
-- 1 1: Receive VXLAN packets, decapsulate them, send ethernet frame

local mg        = require "moongen"
local memory    = require "memory"
local device    = require "device"
local stats     = require "stats"
local proto     = require "proto.proto"
local log       = require "log"
local ffi       = require "ffi"

package.path = package.path .. ";./throughput-util.lua"
require "throughput-util"

function configure(parser)
	parser:description("vxlan testing")  
	parser:argument("txDev", "Device to send from."):convert(tonumber)
	parser:argument("rxDev", "Device to recieve from."):convert(tonumber)
	parser:argument("isEndpoint", "0 if you expect someone else to encap/decap"):convert(tonumber)
	parser:argument("isTunneled", "0 to send ethernet, 1 to send vxlan"):convert(tonumber)
	parser:option("-r --rate", "Transmit rate in Mbit/s."):default(10000):convert(tonumber)
	parser:option("-h --hifile", "Filename for the latency histogram."):default("histogram.csv")
	parser:option("-t --thfile", "Filename for the throughput csv file."):default("throuput.csv")
	parser:option("-l --lafile", "Filename for latency summery file."):default("latency.csv")
end

-- vtep is the endpoint when MoonGen de-/encapsulates traffic 
-- enc(capsulated/tunneled traffic) is facing the l3 network, dec(apsulated traffic) is facing l2 network
-- remote is where we tx/rx traffic with MoonGen (load-/counterslave)
-- Setup: <interface>:<host>:<interface>
-- :loadgen/sink:decRemote <-----> decVtep:Vtep:encVtep <-----> encRemote:sink/loadgen:
local encVtepEth        = "00:00:00:00:00:00" -- vtep, public/l3 side
local encVtepIP         = "10.2.0.2"
local encRemoteEth      = "00:11:22:33:44:55" -- MoonGen load/counter slave
local encRemoteIP       = "10.1.0.2"

local VNI               = 7

local decVtepEth        = "00:00:00:00:00:00" -- vtep, private/l2 side
local decRemoteEth      = "00:11:22:33:44:55" -- MoonGen counter/load slave

-- can be any proper payload really, we use this etherType to identify the packets
local decEthType        = 1

local decPacketLen      = 60
local encapsulationLen  = 14 + 20 + 8 + 8 -- Eth, IP, UDP, VXLAN
local encPacketLen      = encapsulationLen + decPacketLen

function master(args)
		local txPort = args.txDev
		local rxPort = args.rxDev
		local isEndpoint = args.isEndpoint
		local isTunneled = args.isTunneled
		local rate = args.rate
        if not txPort or not rxPort or not isEndpoint or not isTunneled then
                log:info("usage: txPort rxPort isEndpoint isTunneled [rate]")
                return
        end
        txPort = tonumber(txPort)
        rxPort = tonumber(rxPort)
        isEndpoint = tonumber(isEndpoint) == 1
        isTunneled= tonumber(isTunneled) == 1
        rate = rate or 0

        local txDev = device.config{ port = txPort, rxQueues = 3, txQueues = 3 }
        txDev:wait()
        txDev:getTxQueue(0):setRate(rate)
        local rxDev = device.config{ port = rxPort, rxQueues = 3, txQueues = 3 }
        rxDev:wait()

		local recTask = mg.startTask("rxWarmup", rxDev:getRxQueue(0), 10000000)
		txWarmup(recTask, txDev:getTxQueue(0), decRemoteEth, decVtepEth, encRemoteIP, encVtepIP, 60)
		mg.waitForTasks()

        if isEndpoint then
                if isTunneled then
                        mg.startTask("decapsulateSlave", rxDev, txPort, 2)
                else
                        mg.startTask("encapsulateSlave", rxDev, txPort, 2)
                end
        else
                mg.startTask("loadSlave", isTunneled, txPort, 2)
                mg.startTask("counterSlave", isTunneled, rxDev:getRxQueue(2))
        end

        mg.waitForTasks()
end

function loadSlave(sendTunneled, port, queue)

        local queue = device.get(port):getTxQueue(queue)
        local packetLen
        local mem

        if sendTunneled then
                -- create a with VXLAN encapsulated ethernet packet
                packetLen = encPacketLen
                mem = memory.createMemPool(function(buf)
                        buf:getVxlanEthernetPacket():fill{ 
                                ethSrc=encRemoteEth, 
                                ethDst=encVtepEth, 
                                ip4Src=encRemoteIP,
                                ip4Dst=encVtepIP,

                                vxlanVNI=VNI,

                                innerEthSrc=decVtepEth,
                                innerEthDst=decRemoteEth,
                                innerEthType=decEthType,

                                pktLength=encPacketLen 
                        }
                end)
        else
                -- create an ethernet packet
                packetLen = decPacketLen
                mem = memory.createMemPool(function(buf)
                        buf:getEthernetPacket():fill{ 
                                ethSrc=decRemoteEth,
                                ethDst=decVtepEth,
                                ethType=decEthType,

                                pktLength=decPacketLen 
                        }
                end)

        end

        local bufs = mem:bufArray()
        local c = 0

        local txStats = stats:newDevTxCounter(queue, "plain")
        while mg.running() do
                -- fill packets and set their size 
                bufs:alloc(packetLen)

                -- dump first packet to see what we send
                if c < 1 then
                        bufs[1]:dump()
                        c = c + 1
                end 

                if sendTunneled then
                        --offload checksums to NIC
                        bufs:offloadUdpChecksums()
                end

                queue:send(bufs)
                txStats:update()
        end
        txStats:finalize()
end

--- Checks if the content of a packet parsed as Vxlan packet indeed fits with a Vxlan packet
--- @param pkt A buffer parsed as Vxlan packet
--- @return true if the content fits a Vxlan packet (etherType, ip4Proto and udpDst fit)
function isVxlanPacket(pkt)
        return pkt.eth:getType() == proto.eth.TYPE_IP 
                and pkt.ip4:getProtocol() == proto.ip4.PROTO_UDP 
                and pkt.udp:getDstPort() == proto.udp.PORT_VXLAN
end

function counterSlave(receiveInner, queue)
        rxStats = stats:newDevRxCounter(queue, "plain")
        local bufs = memory.bufArray(1)
        local c = 0

        while mg.running() do
                local rx = queue:recv(bufs)
                if rx > 0 then
                        local buf = bufs[1]
                        if receiveInner then
                                -- any ethernet frame
                                local pkt = buf:getEthernetPacket()
                                if c < 1 then
                                        printf(red("Received"))
                                        buf:dump()
                                        c = c + 1
                                end
                        else
                                local pkt = buf:getVxlanEthernetPacket()
                                -- any vxlan packet
                                if isVxlanPacket(pkt) then
                                        if c < 1 then
                                                printf(red("Received"))
                                                buf:dump()
                                                c = c + 1
                                        end
                                end
                        end

                        bufs:freeAll()
                end
                rxStats:update()
        end
        rxStats:finalize()
end

function decapsulateSlave(rxDev, txPort, queue)
        local txDev = device.get(txPort)

        local mem = memory.createMemPool(function(buf)
                buf:getRawPacket():fill{ 
                        -- we take everything from the received encapsulated packet's payload
                }
        end)
        local rxBufs = memory.bufArray()
        local txBufs = mem:bufArray()

        local rxStats = stats:newDevRxCounter(rxDev, "plain")
        local txStats = stats:newDevTxCounter(txDev, "plain")

        local rxQ = rxDev:getRxQueue(0)
        local txQ = txDev:getTxQueue(queue)

        log:info("Starting vtep decapsulation task")
        while mg.running() do
                local rx = rxQ:tryRecv(rxBufs, 0)

                -- alloc empty tx packets
                txBufs:allocN(decPacketLen, rx)

                for i = 1, rx do
                        local rxBuf = rxBufs[i]
                        local rxPkt = rxBuf:getVxlanPacket()
                        -- if its a vxlan packet, decapsulate it
                        if isVxlanPacket(rxPkt) then
                                -- use template raw packet (empty)
                                local txPkt = txBufs[i]:getRawPacket()

                                -- get the size of only the payload
                                local payloadSize = rxBuf:getSize() - encapsulationLen

                                -- copy payload
                                ffi.copy(txPkt.payload, rxPkt.payload, payloadSize)

                                -- update buffer size
                                txBufs[i]:setSize(payloadSize)
                        end
                end
                -- send decapsulated packet
                txQ:send(txBufs)

                -- free received packet                                         
                rxBufs:freeAll()

                -- update statistics
                rxStats:update()
                txStats:update()
        end
        rxStats:finalize()
        txStats:finalize()
end

function encapsulateSlave(rxDev, txPort, queue)
        local txDev = device.get(txPort)

        local mem = memory.createMemPool(function(buf)
                buf:getVxlanPacket():fill{ 
                        -- the outer packet, basically defines the VXLAN tunnel 
                        ethSrc=encVtepEth, 
                        ethDst=encRemoteEth, 
                        ip4Src=encVtepIP,
                        ip4Dst=encRemoteIP,

                        vxlanVNI=VNI,}
        end)

        local rxBufs = memory.bufArray()
        local txBufs = mem:bufArray()

        local rxStats = stats:newDevRxCounter(rxDev, "plain")
        local txStats = stats:newDevTxCounter(txDev, "plain")

        local rxQ = rxDev:getRxQueue(0)
        local txQ = txDev:getTxQueue(queue)

        log:info("Starting vtep encapsulation task")
        while mg.running() do
                local rx = rxQ:tryRecv(rxBufs, 0)

                -- alloc "rx" tx packets with VXLAN template
                -- In the end we only want to send as many packets as we have received in the first place.
                -- In case this number would be lower than the size of the bufArray, we would have a memory leak (only sending frees the buffer!).
                -- allocN implicitly resizes the bufArray to that all operations like checksum offloading or sending the packets are only done for the packets that actually exist (would crash otherwise)
                txBufs:allocN(encPacketLen, rx)

                -- check if we received any packets
                for i = 1, rx do
                        -- we encapsulate everything that gets here. One could also parse it as ethernet frame and then only encapsulate on matching src/dst addresses
                        local rxPkt = rxBufs[i]:getRawPacket()

                        -- size of the packet
                        local rawSize = rxBufs[i]:getSize()

                        -- use template VXLAN packet
                        local txPkt = txBufs[i]:getVxlanPacket()

                        -- copy raw payload (whole frame) to encapsulated packet payload
                        ffi.copy(txPkt.payload, rxPkt.payload, rawSize)

                        -- update size
                        local totalSize = encapsulationLen + rawSize
                        -- for the actual buffer
                        txBufs[i]:setSize(totalSize)
                        -- for the IP/UDP header
                        txPkt:setLength(totalSize)
                end
                -- offload checksums
                txBufs:offloadUdpChecksums()

                -- send encapsulated packet
                txQ:send(txBufs)

                -- free received packet
                rxBufs:freeAll()

                -- update statistics
                txStats:update()
                rxStats:update()
        end
        rxStats:finalize()
        txStats:finalize()
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

-- recTask is only usable in master thread
function txWarmup(recTask, txQueue, eth_src, eth_dst, ip_src, ip_dst, pktSize)
  local mem = memory.createMemPool(function(buf)
    fillUdpPacket(buf, eth_src, eth_dst, ip_src, ip_dst, pktSize)
  end)
  local bufs = mem:bufArray(1)
  mg.sleepMillis(1000) -- ensure that waitWarmup is listening
  while recTask:isRunning() do
    bufs:alloc(pktSize)
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
		log:info("first packet received")
	end
end