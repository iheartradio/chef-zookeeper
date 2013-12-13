#
# Cookbook Name:: zookeeper
# Recipe:: Exhibitor
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

include_recipe "zookeeper::zookeeper"

package "nfs-utils"

service "rpcbind" do
  provider Chef::Provider::Service::Init
  supports :start => true, :status => true, :restart => true
  action :start
end

nfs_server = search(:node, "recipe:zookeeper\\:\\:nfs AND chef_environment:#{node.chef_environment}")[0]

directory "#{node[:exhibitor][:shared_conf_dir]}" do
  action :create
  recursive true
end

mount "#{node[:exhibitor][:shared_conf_dir]}" do
  device "#{nfs_server[:hostname]}-v600.ihr:#{node[:exhibitor][:mount_dir]}"
  fstype "nfs"
  options "noatime,nocto"
  action [:mount, :enable]
end

exhibitor_build_path = ::File.join(Chef::Config[:file_cache_path], 'exhibitor')

[node[:exhibitor][:install_dir],
  node[:exhibitor][:snapshot_dir],
  node[:exhibitor][:transaction_dir],
  node[:exhibitor][:log_index_dir],
  exhibitor_build_path
].uniq.each do |dir|
  directory dir do
    owner node[:zookeeper][:user]
    mode "0755"
  end
end

template ::File.join(exhibitor_build_path, 'build.gradle') do
  variables(
    :version => node[:exhibitor][:version] )
  action :create
end

include_recipe "zookeeper::gradle"

jar_file = "#{exhibitor_build_path}/build/libs/exhibitor-#{node[:exhibitor][:version]}.jar"
if !::File.exists?(jar_file)
  execute "build exhibitor" do
    user "root"
    cwd exhibitor_build_path
    command 'gradle jar'
  end
end

exhibitor_jar = ::File.join(node[:exhibitor][:install_dir], "#{node[:exhibitor][:version]}.jar")
if !::File.exists?(exhibitor_jar)
  execute "move exhibitor jar" do
    command "cp '#{jar_file}' '#{exhibitor_jar}' && chown '#{node[:zookeeper][:user]}:#{node[:zookeeper][:group]}' '#{exhibitor_jar}'"
  end
end

check_script = ::File.join(node[:exhibitor][:script_dir], 'check-local-zk.py')
template check_script do
  owner node[:zookeeper][:user]
  mode "0744"
  variables(
    :exhibitor_port => node[:exhibitor][:opts][:port],
    :localhost => node[:exhibitor][:opts][:hostname] )
end

template "/etc/init/exhibitor.conf" do
  source "exhibitor.upstart.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :stop, "service[exhibitor]" # :restart doesn't reload upstart conf
  notifies :start, "service[exhibitor]"
  variables(
    :user => node[:zookeeper][:user],
    :jar => exhibitor_jar,
    :opts => node[:exhibitor][:opts],
    :check_script => check_script )
end

servers_spec=String.new

zookeepers = search(:node, "role:zookeeper AND chef_environment:#{node.chef_environment}")

zookeepers.each_with_index do |zk_node, index|
  if index == zookeepers.size - 1
     servers_spec = servers_spec + "S:" + "#{zk_node[:zookeeper][:server_id]}:" + "#{zk_node[:fqdn]}"
  else
     servers_spec = servers_spec + "S:" + "#{zk_node[:zookeeper][:server_id]}:" + "#{zk_node[:fqdn]},"
  end
end

#server_spec = server_spec_array.join ":"

template node[:exhibitor][:opts][:defaultconfig] do
  owner node[:zookeeper][:user]
  mode "0644"
  variables(
    :snapshot_dir => node[:exhibitor][:snapshot_dir],
    :transaction_dir => node[:exhibitor][:transaction_dir],
    :log_index_dir => node[:exhibitor][:log_index_dir],
    :defaultconfig => node[:exhibitor][:defaultconfig],
    :servers_spec => servers_spec )
end

service "exhibitor" do
  provider Chef::Provider::Service::Upstart
  supports :start => true, :status => true, :restart => true
  action :start
end

