#!/bin/bash
# expects a dut_test*.yaml
# expects the ba-okelmann git to be checked out at /root/ba-okelmann
GITDIR="/root/ba-okelmann"
# changing only this will probably not work
BINDIR="${GITDIR}/vpp/build-root/install-vpp_debug-native/vpp/bin"
VPP_ROOT="${GITDIR}/vpp"
VPP_CLIB_SCRIPT="${GITDIR}/theleos88-vpp-bench/scripts/vpp_change-frame-size.sh"
cd "$GITDIR"

# exit on error
set -e
# log every command
set -x

echo $(pos_get_variable hostname)

# write back some information about the host that might be of interest for the
# evaluation
pos_set_variable host/kernel-name $(uname -s)
pos_set_variable host/kernel-release $(uname -r)
pos_set_variable host/kernel-version $(uname -v)
pos_set_variable host/os $(uname -o)
pos_set_variable host/machine $(uname -m)

# write back the hash of the exact git commit used for reference later
cd "$GITDIR"
pos_set_variable git/commit-hash $(git rev-parse --verify HEAD)
cd "$GITDIR/vpp"
pos_set_variable git/vpp-commit-hash $(git rev-parse --verify HEAD)
cd "$GITDIR"

# disable turbo boost
echo 1 >   /sys/devices/system/cpu/intel_pstate/no_turbo

# set frequency
echo $(pos_get_variable -r cpu-freq) > /sys/devices/system/cpu/intel_pstate/min_perf_pct
echo $(pos_get_variable -r cpu-freq) > /sys/devices/system/cpu/intel_pstate/max_perf_pct

# load driver
modprobe $(pos_get_variable -r vpp/driver)

# read vars
INT_SRC=`pos_get_variable -r vpp/int_src`
INT_DST=`pos_get_variable -r vpp/int_dst`
INT_SRC_PCI=`pos_get_variable -r vpp/int_src_pci`
INT_DST_PCI=`pos_get_variable -r vpp/int_dst_pci`

VPP_PNAME="vpp_main"

# set clean up vpp
function cleanup_vpp () {
	set +e # ingore the follwing 2 possible errors
	pkill $VPP_PNAME
	rm -f /dev/shm/db /dev/shm/global_vm /dev/shm/vpe-api
	set -e
}

echo 'Done setting up'
pos_sync
echo 'sync done'

# this function is blocking!
# $1: filename for perf-stat.csv
# $2: filename for perf-record (without .csv or .data appendix)
# $3: time to collect (in sec).
function perf-collect () {
	hwevents="branch-instructions,\
branch-misses,\
cache-misses,\
ref-cycles,\
cpu-cycles"
	unused="
cache-references,\
instructions,\
idle-cycles-frontend"
	cacheevents="L1-dcache-load-misses,\
L1-dcache-loads,\
L1-dcache-prefetch-misses,\
LLC-loads,\
LLC-load-misses,\
LLC-prefetches,\
LLC-prefetch-misses,\
branch-load-misses,\
branch-loads"
	unused="L1-icache-load-misses,\
L1-dcache-store-misses,\
L1-dcache-stores,\
LLC-store-misses,\
LLC-stores,\
dTLB-load-misses,\
dTLB-loads,\
dTLB-store-misses,\
dTLB-stores"

	vpp_pid=`pgrep $VPP_PNAME`
	
	# worker thread to attatch perf record to
	vpp_wk_spid=`ps -T -p $vpp_pid | grep vpp_wk_0 | tr " " "\n" | head -n2 | tail -n1`
	if [[ -z "$vpp_wk_spid" ]]; then
		vpp_wk_spid="$vpp_pid" # vpp runs without a worker -> attatch to vpp
	fi

	# run stats on the process to register all events 
	perf stat -x";" -e "$hwevents,$cacheevents" -o "$1" -p $vpp_pid sleep $3 &
	# run record only on main working thread to get representative
	# perf top results
	perf record -o "${2}.data" -t $vpp_wk_spid sleep $3 &
	wait
	perf report -i "${2}.data" --field-separator=";" > ${2}.csv
}

# this function is blocking!
# $1: filename for perf-stat.csv
# $2: time to collect (in sec).
function perf-stat () {
	vpp_pid=`pgrep $VPP_PNAME`
	
	# worker thread to attatch perf record to
	vpp_wk_spid=`ps -T -p $vpp_pid | grep vpp_wk_0 | tr " " "\n" | head -n2 | tail -n1`
	if [[ -z "$vpp_wk_spid" ]]; then
		vpp_wk_spid="$vpp_pid" # vpp runs without a worker -> attatch to vpp
	fi

	perf stat -x";" -e "cpu-cycles" -o "$1" -p $vpp_pid sleep $2
}

# $1: filename for vpp output like vpp-stats
function vpp-collect () {
	echo "show err" | socat - UNIX-CONNECT:/tmp/vpptesting_cli | tail -n +1 > $1
}

# $1: jobname
# $2: command
# $3: additional args for command
# $4: ranger mode: { noai | ipcdump | doai }
# optional $5: ranger ipc response (sample_ipc_for_client_t)
function vpp-test-ranger () {
	jobname=$1
	perfstatfile="/tmp/$jobname.perfstat.csv"
	perfdataname="/tmp/$jobname.perfrecord" # without .csv appendix
	vppfile="/tmp/$jobname.vpp.out"
	badgesizes="/tmp/$jobname.badgesizes.csv"
	forestio="/tmp/$jobname.forestio.csv"

	echo "Starting bridging test $1"

	cleanup_vpp
	# pos_run COMMMAND_ID -- COMMAND ARGS
	pos_run $jobname -- $2 $INT_SRC $INT_DST $INT_SRC_PCI $INT_DST_PCI $3
	pos_sync #s1 vpp is set up

	pos_sync #s21: moogen should be generating load now

	# !!! marks lines commented to disable perf-collect 
	# !!! perf-collect "$perfstatfile" "$perfdataname" 10
	perf-stat "$perfstatfile" 10 &

	# all the following branches MUST block for around 10 seconds
	if [ $4 = "ipcdump" ]; then
		${GITDIR}/ranger/cpp_version/build/ranger ipcdump 9 "$badgesizes" $5
	elif [ $4 = "doai" ]; then
		# file must exist and be empty
		touch "$forestio"
		echo "" > "$forestio"
		for i in {1..10}; do
			sleep 1
			${GITDIR}/ranger/cpp_version/build/ranger doai "$forestio"
		done
	else # equals $4 = "noai"
		sleep 10
	fi

	wait # for perf-stat
	pos_sync #s31: vpp side live data collection done
	pos_sync #s32: moongen is now terminating
	
	echo "collecting vpp info and upload files..."
	vpp-collect "$vppfile"
	# !!! pos_upload ${perfdataname}.csv
	pos_upload $perfstatfile
	pos_upload $vppfile
	if [ $4 = "ipcdump" ]; then
		pos_upload $badgesizes
	elif [ $4 = "doai" ]; then
		pos_upload $forestio
	fi

	# wait for test done signal
	pos_sync #s42: test end
	echo "Stopped test" # ~46s

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill $1
}

# $1: jobname
# $2: command
# $3: additional args for command
function vpp-test () {
	vpp-test-ranger $1 $2 $3 noai
}

# does 9 test runs to find the maximum throughput with low drop rates
# $1: jobname
# $2: cmd to run
# $3: arg for cmd
function vpp-find-sweetspot () {
	spjobname="$1"
	cmd="$2"
	cmdarg="$3"

	# # measure everything with low resolution
	# for s in {1..15}
	# do
	# 	i=$((s*400))
	# 	istr=`printf "%04i" $i`
	# 	vpp-test "${spjobname}_mbit$istr" "$cmd" "$cmdarg"
	# done

	# Try to find max_throughput
	vpp-test "${spjobname}_mbit9000" "$cmd" "$cmdarg"
	for i in {0..6}
	do
		istr=`printf "%04i" $i`
		vpp-test "${spjobname}_mbit${istr}hires" "$cmd" "$cmdarg"
	done

	# final test
	vpp-test "${spjobname}_mbit0000_final" "$cmd" "$cmdarg"
}

# recompile vpp to use only $1 as maximum batch size
# $1: max batch size
function recompile-vpp-maxbatch () {
	VPP_ROOT="$VPP_ROOT" $VPP_CLIB_SCRIPT $1
	cd ${GITDIR}/vpp
	# this cache can grow by up to 1GB per recompilation with new batch sizes. 
	rm -r ./build-root/.ccache/
	make build-release
	cd ${GITDIR}
}

#### short and simple bridge test ####
function bridge_simple_test () {
	vpp-test "l2_bridgingSimple_cnf0_mbit9000" "${GITDIR}/scripts/vpp_tests/l2-bridging.sh" "0"
}

#### bridge config testing ####
function bridge_config_testing () {
	for i in {0..5}
	do
		vpp-find-sweetspot "l2_bridging_cnf${i}" "${GITDIR}/scripts/vpp_tests/l2-bridging.sh" "${i}"
	done

	vpp-find-sweetspot "l2_xconnect" "${GITDIR}/scripts/vpp_tests/l2-xconnect.sh"
}

#### multimac latency testing ####
function multimac_latency_testing () {
	vppcmd="${GITDIR}/scripts/vpp_tests/l2-multimac.sh"
	for s in {1..40}
	do
		i=$((s*25000))
		istr=`printf "%08i" $i`
		vpp-find-sweetspot "l2_multimac_$istr" "$vppcmd" $i
	done
	vpp-find-sweetspot "l2_multimac_00000100" "$vppcmd" 100
	vpp-find-sweetspot "l2_multimac_00001000" "$vppcmd" 1000
	vpp-find-sweetspot "l2_multimac_00005000" "$vppcmd" 5000
	vpp-find-sweetspot "l2_multimac_00010000" "$vppcmd" 10000
	vpp-find-sweetspot "l2_multimac_00015000" "$vppcmd" 15000
	vpp-find-sweetspot "l2_multimac_00020000" "$vppcmd" 20000
}

function multimac_latency_testing_hires () {
	vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip4-routing.sh"
	for run in {0..5}
	do
		for s in {1..50}
		do
			i=$((s*200))
			istr=`printf "%06i" $i`
			vpp-test "l3_latroutes1_${istr}_${run}" "$vppcmd" "1 2 1"
			vpp-test "l3_latroutes255k_${istr}_${run}" "$vppcmd" "1 2 255116"
		done
	done
}

#### multimac throughput testing ####
function multimac_throughput_testing () {
	# 6 runs with 47 different l2fib sizes each = 282
	vppcmd="${GITDIR}/scripts/vpp_tests/l2-multimac.sh"
	for run in {0..5}
	do
		for s in {1..47}
		do
			i=`echo "1.4^$s" | bc`
			i=`printf "%.0f" $i`
			istr=`printf "%08i" $i`
			vpp-test "l2_throughmac_${istr}_$run" "$vppcmd" $i
		done
	done
}

# #### l3 ip4 multicore testing ####
function l3ip4_multicore_testing () {
	vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip4-flows.sh"
	for run in {0..5}
	do
		max=6
		for s in $(seq 0 $max)
		do
			sstr=`printf "%02i" $s`
			j=$((1+$s))
			vpp-test "l3_multicore_${sstr}_$run" "$vppcmd" "$s 2-$j"
		done
	done
}

# #### l3 ip6 multicore testing ####
function l3ip6_multicore_testing () {
	vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip6-flows.sh"
	for run in {0..5}
	do
		max=6
		for s in $(seq 0 $max)
		do
			sstr=`printf "%02i" $s`
			j=$((1+$s))
			vpp-test "l3v6_multicore_${sstr}_$run" "$vppcmd" "$s 2-$j"
		done
	done
}

# #### l3 ip4 routing ####
function l3ip4_routing_testing () {
	# 6 runs with 37 different l2fib sizes each = 222
	vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip4-routing.sh"
	for run in {0..5}
	do
		for s in {1..37} # 47}
		do
			i=`echo "1.4^$s" | bc`
			i=`printf "%.0f" $i`
			istr=`printf "%08i" $i`
			vpp-test "l3_routes_${istr}_$run" "$vppcmd" "1 2 $i"
		done
	done
}

# #### l3 ip6 routing ####
function l3ip6_routing_testing () {
	# 6 runs with 37 different l2fib sizes each = 222
	vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip6-routing.sh"
	for run in {0..5}
	do
		for s in {1..37} # 47}
		do
			i=`echo "1.4^$s" | bc`
			i=`printf "%.0f" $i`
			istr=`printf "%08i" $i`
			vpp-test "l3v6_routes_${istr}_$run" "$vppcmd" "1 2 $i"
		done
	done
}

#### l3 ip4 routing legacy: v16.09 ####
function l3ip4_routing_legacy () {
	6 runs with 50 different l3fib sizes each = 300
	vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip4-routinglegacy.sh"
	for run in {0..5}
	do
		for s in {1..48} # 47}
		do
			i=`echo "1.4^$s" | bc`
			i=`printf "%.0f" $i`
			istr=`printf "%08i" $i`
			vpp-test "l3_routes_${istr}_$run" "$vppcmd" "1 2 $i"
		done

		# 2^20
		i=`echo "2^20" | bc`
		i=`printf "%.0f" $i`
		istr=`printf "%08i" $i`
		vpp-test "l3_routes_${istr}_$run" "$vppcmd" "1 2 $i"

		# 2^23
		i=`echo "2^23" | bc`
		i=`printf "%.0f" $i`
		istr=`printf "%08i" $i`
		vpp-test "l3_routes_${istr}_$run" "$vppcmd" "1 2 $i"
	done
}

#### vxlan throughput ####
function vxlan_throughput_testing () {
	vpp-test "vxlan_encap" "${GITDIR}/scripts/vpp_tests/vxlan-encapsulated.sh" ""
}


#### training ####

# 3*3+1 = 10 runs => 205 training items per day
# 3*6+1 = 19 runs => 110 items/day

# 7+1 = 8 runs => 257x/day
# $1: training item id
# $2: ipc command
function offline_training () {
	vppcmd="${GITDIR}/scripts/vpp_tests/l2-xconnect-rr.sh"
	${GITDIR}/ranger/cpp_version/build/ranger respond 1 0 0 0 0 0 0 0 0
	b=`printf "%.0f" $1`
	bstr=`printf "%08i" $b`

	# test with 0 packets
	vpp-test-ranger "l2_training_${bstr}_0000_00000000" "$vppcmd" "" doai

	# suggested throughputs: 1, 10, 100, 1000, 5000, 10000
	# or: 1, 500, 10000
	# //edit: not 10000 but 7500 for not overfitting for 256
	# //edit: moongen doesnt rate limit with 1. use 2 instead. 
	# //edit: remove 100, as it has no entropy during training
	for throughput in {2,10,500,1000,5000,7500}
	do
		t=`printf "%.0f" $throughput`
		tstr=`printf "%06i" $t`
		vpp-test-ranger "l2_training_${bstr}_0064_${tstr}" "$vppcmd" "" doai
		#vpp-test "l2_training_${bstr}_0512_${tstr}" "$vppcmd" "$2"
		#vpp-test "l2_training_${bstr}_1522_${tstr}" "$vppcmd" "$2"
	done

}

#### conext experiments ####

# 240 runs
function xconext_all_tests () {
	xconext_tests 256
	xconext_tests 16
	xconext_tests 64
	xconext_tests 1024
}

# xconnect 60 runs
# $1: maximum batch size
function xconext_tests () {
	vppcmd="${GITDIR}/scripts/vpp_tests/l2-xconnect.sh"
	b=`printf "%.0f" $1`
	bstr=`printf "%06i" $b`

	# test vpp max batch size $b
	recompile-vpp-maxbatch $b
	# do 0 - 10G in 500th steps
	for throughput in {1..20}
	do
		t=`echo "$throughput * 500" | bc`
		t=`printf "%.0f" $t`
		tstr=`printf "%06i" $t`
		# do different packet sizes/mixes (64, 512, 1522)
		vpp-test "l2_xconext_${bstr}_0064_${tstr}" "$vppcmd"
		vpp-test "l2_xconext_${bstr}_0512_${tstr}" "$vppcmd"
		vpp-test "l2_xconext_${bstr}_1522_${tstr}" "$vppcmd"
		# TODO vpp-test "l2_xconnext_0256_IMIX_${tstr}" $t IMIX
	done
}

# xconnect 60 runs
function validation () {
	vppcmd="${GITDIR}/scripts/vpp_tests/l2-xconnect-rr.sh"

	for run in {0..5}
	do
		# do 0 - 10G in 500th steps
		for throughput in {1..20}
		do
			t=`echo "$throughput * 500" | bc`
			t=`printf "%.0f" $t`
			tstr=`printf "%06i" $t`
			# do different packet sizes/mixes (64, 512, 1522)
			vpp-test-ranger "l2_training_0064_${tstr}_${run}" "$vppcmd" "" ipcdump
			vpp-test-ranger "l2_training_0512_${tstr}_${run}" "$vppcmd" "" ipcdump
			vpp-test-ranger "l2_training_1522_${tstr}_${run}" "$vppcmd" "" ipcdump
		done
	done
}

function training_step () {
	# load parameters
	iteration="0"
	if [ -e /tmp/pos_commands_param_1 ]; then
		iteration=$(cat /tmp/pos_commands_param_1)
	fi
	offline_training $iteration
}

#### run test functions ####

validation
#training_step
#xconext_all_tests
#bridge_simple_test
# bridge_config_testing
# multimac_latency_testing
# multimac_latency_testing_hires
# multimac_throughput_testing
# l3ip4_multicore_testing
# l3ip6_multicore_testing
# l3ip4_routing_testing
# l3ip6_routing_testing
# l3ip4_routing_legacy
# vxlan_throughput_testing

echo "all done"
