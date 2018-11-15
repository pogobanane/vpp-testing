
# expects a dut_test*.yaml


rm -f /dev/shm/db /dev/shm/global_vm /dev/shm/vpe-api
modprobe uio_pci_generic

vpp -c $(pos_get_variable vpp/config)
