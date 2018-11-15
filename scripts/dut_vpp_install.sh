

# expects a dut_setup_variables.yaml



VPP_DEBS=$(pos_get_variable dependencies)
for i in "${VPP_DEBS[@]}"
do
  dpkg -i ${i}
done


systemctl disable vpp.service
systemctl stop vpp.service
