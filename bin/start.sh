#!/bin/bash
source env_qpf.sh
qpfexe=$(which qpf)
ip=$(hostname -i)
sudo chown -R ${USER_NAME}.${GRP_NAME} /home/${USER_NAME}/qpf/
sed -e "s|@QPF_MASTER_IP@|$ip|g" /home/${USER_NAME}/qpf/cfg/qpf-test.tpl.cfg \
    > /home/${USER_NAME}/qpf/cfg/qpf-test.cfg
${qpfexe} -v -v -v -v -c /home/${USER_NAME}/qpf/cfg/qpf-test.cfg -I ${ip} 2>&1 \
    | tee /home/${USER_NAME}/qpf/data/QPF.log

