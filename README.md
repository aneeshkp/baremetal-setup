# baremetal-setup
FROM BMO
 go run cmd/make-virt-host/main.go node_0 | kubectl delete  -n metal3  -f -
  go run cmd/make-virt-host/main.go node_0 | kubectl apply   -n metal3  -f -
  
  
  sudo vbmc add node_0 --port 6235 


#From meta3 dev env to create vm

ansible-playbook -i inventory.ini setup-playbook.yml -e working_dir=~/metal_working_dir/


# in your laptop 
sudo brctl addbr provisioning
# sudo ifconfig provisioning 172.22.0.1 netmask 255.255.255.0 up
# Use ip command. ifconfig commands are deprecated now.
sudo ip addr add dev provisioning 172.22.0.1/24
sudo ip link set provisioning up



kubectl scale --replicas=0 deployment metal3-baremetal-operator -n metal3

# Accessing console
in your laptop /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 console-openshift-console.apps.aputtur.kni.lab.metal3.io oauth-openshift.apps.aputtur.kni.lab.metal3.io

sudo ssh -L 443:console-openshift-console.apps.aputtur.kni.lab.metal3.io:443 root@10.19.111.12

https://console-openshift-console.apps.aputtur.kni.lab.metal3.io
