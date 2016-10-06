# reverse_playbook.py
simple python script to switch the order of an ansible playbook

## usage

The script takes to required arguments, an in and an out file, along with an optional `-v` to show the converted file

~~~
$ ./reverse_playbook.py [-h] [-v] infile outfile
~~~

## example

This script targets a particular use case, where you might want to build up and environment and then tear it down when you're done. The tear down has to be done in the reverse order of creation. Here's an example playbook, `mini_stack.yaml` that spins up a quick OpenStack environment and boots an instance:

~~~
---
- hosts: builder
  tasks:
  - name: upload image to glance
    os_image:
      state: present
      auth: '{{ osp_user }}'
      name: '{{ glance_image.name }}'
      filename: '{{ glance_image.file }}'
      container_format: bare
      disk_format: '{{ glance_image.disk }}'
    tags:
    - qcow2
    - glance
  - name: create a security group
    os_security_group:
      state: present
      auth: '{{ osp_user }}'
      name: '{{ osp_priv.security_group }}'
  - name: open up ping
    os_security_group_rule:
      state: present
      auth: '{{ osp_user }}'
      security_group: '{{ osp_priv.security_group }}'
      protocol: icmp
      remote_ip_prefix: 0.0.0.0/0
    tags:
    - secgroups
  - name: ...and ssh
    os_security_group_rule:
      state: present
      auth: '{{ osp_user }}'
      security_group: '{{ osp_priv.security_group }}'
      protocol: tcp
      port_range_min: 22
      port_range_max: 22
      remote_ip_prefix: 0.0.0.0/0
    tags:
    - secgroups
  - name: create private network
    os_network:
      state: present
      auth: '{{ osp_user }}'
      name: '{{ osp_priv.net_name }}'
    tags:
    - priv_nets
  - name: create private subnet
    os_subnet:
      state: present
      auth: '{{ osp_user }}'
      name: '{{ osp_priv.subnet_name }}'
      network_name: '{{ osp_priv.net_name }}'
      cidr: '{{ osp_priv.cidr }}'
      dns_nameservers: '{{ osp_priv.dns }}'
      enable_dhcp: True
    tags:
    - priv_nets
  - name: create private router
    os_router:
      state: present
      auth: '{{ osp_user }}'
      name: '{{ osp_priv.router_name }}'
      interfaces: '{{ osp_priv.subnet_name }}'
      network: '{{ osp_admin_net.name }}'
    tags:
    - priv_nets
  - name: boot an instance in nova
    os_server:
      state: present
      auth: '{{ osp_user }}'
      name: '{{ instance_name }}'
      image: '{{ image_name }}'
      key_name: '{{ osp_user.username }}'
      flavor: '{{ nova_flavor }}'
      floating_ip_pools: '{{ osp_admin_net.name }}'
    register: os_server
  - debug: var=os_server.server.accessIPv4
~~~

You'd run it like so:

~~~
$ ansible-playbook -i hosts --extra-vars @env.yaml mini_stack.yaml

PLAY [builder] *****************************************************************

TASK [setup] *******************************************************************
ok: [builder.example.com]

TASK [upload image to glance] **************************************************
changed: [builder.example.com]

TASK [create a security group] *************************************************
changed: [builder.example.com]

TASK [open up ping] ************************************************************
changed: [builder.example.com]

TASK [...and ssh] **************************************************************
changed: [builder.example.com]

TASK [create private network] **************************************************
changed: [builder.example.com]

TASK [create private subnet] ***************************************************
changed: [builder.example.com]

TASK [create private router] ***************************************************
changed: [builder.example.com]

TASK [boot an instance in nova] ************************************************
changed: [builder.example.com]

TASK [debug] *******************************************************************
ok: [builder.example.com] => {
    "os_server.server.accessIPv4": "10.10.10.192"
}

PLAY RECAP *********************************************************************
builder.example.com                : ok=10   changed=8    unreachable=0    failed=0   

$
~~~

Running the script against the playbook yields:

~~~
$ ./reverse_playbook.py -v mini_stack.yaml rmini_stack.yaml
- hosts: builder
  tasks:
  - debug: var=os_server.server.accessIPv4
  - name: boot an instance in nova
    os_server:
      auth: '{{ osp_user }}'
      flavor: '{{ nova_flavor }}'
      floating_ip_pools: '{{ osp_admin_net.name }}'
      image: '{{ image_name }}'
      key_name: '{{ osp_user.username }}'
      name: '{{ instance_name }}'
      state: absent
    register: os_server
  - name: create private router
    os_router:
      auth: '{{ osp_user }}'
      interfaces: '{{ osp_priv.subnet_name }}'
      name: '{{ osp_priv.router_name }}'
      network: '{{ osp_admin_net.name }}'
      state: absent
    tags:
    - priv_nets
  - name: create private subnet
    os_subnet:
      auth: '{{ osp_user }}'
      cidr: '{{ osp_priv.cidr }}'
      dns_nameservers: '{{ osp_priv.dns }}'
      enable_dhcp: true
      name: '{{ osp_priv.subnet_name }}'
      network_name: '{{ osp_priv.net_name }}'
      state: absent
    tags:
    - priv_nets
  - name: create private network
    os_network:
      auth: '{{ osp_user }}'
      name: '{{ osp_priv.net_name }}'
      state: absent
    tags:
    - priv_nets
  - name: '...and ssh'
    os_security_group_rule:
      auth: '{{ osp_user }}'
      port_range_max: 22
      port_range_min: 22
      protocol: tcp
      remote_ip_prefix: 0.0.0.0/0
      security_group: '{{ osp_priv.security_group }}'
      state: absent
    tags:
    - secgroups
  - name: open up ping
    os_security_group_rule:
      auth: '{{ osp_user }}'
      protocol: icmp
      remote_ip_prefix: 0.0.0.0/0
      security_group: '{{ osp_priv.security_group }}'
      state: absent
    tags:
    - secgroups
  - name: create a security group
    os_security_group:
      auth: '{{ osp_user }}'
      name: '{{ osp_priv.security_group }}'
      state: absent
  - name: upload image to glance
    os_image:
      auth: '{{ osp_user }}'
      container_format: bare
      disk_format: '{{ glance_image.disk }}'
      filename: '{{ glance_image.file }}'
      name: '{{ glance_image.name }}'
      state: absent
    tags:
    - qcow2
    - glance

saving reversed version of mini_stack.yaml to rmini_stack.yaml
~~~

Which can then be run to tear it all down again:

~~~
$ ansible-playbook -i hosts --extra-vars @env.yaml rmini_stack.yaml

PLAY [builder] *****************************************************************

TASK [setup] *******************************************************************
ok: [builder.example.com]

TASK [debug] *******************************************************************
ok: [builder.example.com] => {
    "os_server.server.accessIPv4": "VARIABLE IS NOT DEFINED!"
}

TASK [boot an instance in nova] ************************************************
changed: [builder.example.com]

TASK [create private router] ***************************************************
changed: [builder.example.com]

TASK [create private subnet] ***************************************************
changed: [builder.example.com]

TASK [create private network] **************************************************
changed: [builder.example.com]

TASK [...and ssh] **************************************************************
changed: [builder.example.com]

TASK [open up ping] ************************************************************
changed: [builder.example.com]

TASK [create a security group] *************************************************
changed: [builder.example.com]

TASK [upload image to glance] **************************************************
changed: [builder.example.com]

PLAY RECAP *********************************************************************
builder.example.com                : ok=10   changed=8    unreachable=0    failed=0

$
~~~

It's kind of dirty, and dosen't flip the verbiage around, but it will do me until an equivalent feature lands in ansible.

