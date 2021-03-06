#
# Cookbook Name:: zookeeper
# Recipe:: zookeeper
#
# Copyright 2013, Simple Finance Technology Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "java::oracle-7"

node.override['build_essential']['compiletime'] = true
include_recipe "build-essential"

chef_gem "zookeeper"
chef_gem "json"


group node[:zookeeper][:group] do
  action :create
end

user node[:zookeeper][:user] do
  gid node[:zookeeper][:group]
end

directory "#{node[:exhibitor][:snapshot_dir]}" do
  user "zookeeper"
  group "zookeeper"
  recursive true
end

directory "#{node[:exhibitor][:transaction_dir]}" do
  user "zookeeper"
  group "zookeeper"
  recursive true
end

mount "#{node[:exhibitor][:snapshot_dir]}" do
  device "/dev/sdb"
  fstype "ext4"
  pass 0
  action [:mount, :enable]
end

mount "#{node[:exhibitor][:transaction_dir]}" do
  device "/dev/sdc"
  fstype "ext4"
  pass 0
  action [:mount, :enable]
end

zk_basename = "zookeeper-#{node[:zookeeper][:version]}"

remote_file ::File.join(Chef::Config[:file_cache_path], "#{zk_basename}.tar.gz") do
  owner "root"
  mode "0644"
  source node[:zookeeper][:mirror]
  checksum node[:zookeeper][:checksum]
  action :create
end

directory node[:zookeeper][:install_dir] do
  owner node[:zookeeper][:user]
  mode "0755"
  recursive true
end

unless ::File.exists?(::File.join(node[:zookeeper][:install_dir], zk_basename))
  execute 'install zookeeper' do
    cwd Chef::Config[:file_cache_path]
    command "tar -C '#{node[:zookeeper][:install_dir]}' -zxf '#{zk_basename}.tar.gz' && chown -R '#{node[:zookeeper][:user]}:#{node[:zookeeper][:group]}' #{node[:zookeeper][:install_dir]}"
  end
end
