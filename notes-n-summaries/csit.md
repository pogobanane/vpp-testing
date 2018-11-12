## CSIT testsuite tests: 

- sämtliche features von vpp:

    L2BD, L2XC
        tags: L2BDMACSTAT or L2BDMACLRN or L2XCFWD
    IPv4 base, scale, feature
        tags: IP4FWD
    IPv6 base, scale, feature
        tags: IP6FWD
    Overlay tunnels - LISP, VXLAN, GPE, GRE
        tags: VXLAN or LISP or LISPGPE or VXLANGPE or GRE
    Crypto in software: IP4FWD, IP6FWD
        tags: IPSECSW and (IPSECTRAN or IPSECTUN)
    Crypto in hardware: IP4FWD, IP6FWD
        tags: IPSECHW and (IPSECTRAN or IPSECTUN)
    Overlay tunnels with crypto in software
        tags: (VXLAN or LISP or LISPGPE or VXLANGPE or GRE) and IPSECSW and (IPSECTRAN or IPSECTUN)
    Overlay tunnels with crypto in hardware
        tags: (VXLAN or LISP or LISPGPE or VXLANGPE or GRE) and IPSEHW and (IPSECTRAN or IPSECTUN)
    vhost-user
        tags: VHOST and (ETH or DOT1Q or VXLAN)

- jeweils mit cpu config:
	- 1thread1core
	- 2t2c
	- 4t4c
	- 2t1c
	- 8t4c
	- ...


- für jede davon: 
	- packets per second: (no drop rate vs partial drop rate?)

Fokus von CSIT: contious system integration and testing -> [pps] per time or build