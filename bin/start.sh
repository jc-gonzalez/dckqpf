#!/bin/bash
source env_qpf.sh
qpfexe=$(which qpf)
ip=$(hostname -i)
sed -e "s|@QPF_MASTER_IP@|$ip|g" /home/eucops/qpf/cfg/qpf-test.tpl.cfg \
    > /home/eucops/qpf/cfg/qpf-test.cfg
${qpfexe} -v -v -v -v -c /home/eucops/qpf/cfg/qpf-test.cfg -I ${ip} 2>&1 \
    | tee ${HOME}/qpf/data/QPF.log

