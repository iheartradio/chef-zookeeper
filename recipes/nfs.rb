directory "#{node[:sto][:base_path]}/zk_shared_config" do
  mode "0775"
  action :create
end

nfs_export "#{node[:sto][:base_path]}/zk_shared_config" do
  network "10.5.32.0/23"
  writeable true
  sync true
  options ["no_root_squash"]
end

nfs_export "#{node[:sto][:base_path]}/zk_shared_config" do
  network "10.5.40.0/23"
  writeable true
  sync true
  options ["no_root_squash"]
end

nfs_export "#{node[:sto][:base_path]}/zk_shared_config" do
  network "10.5.42.128/25"
  writeable true
  sync true
  options ["no_root_squash"]
end

nfs_export "#{node[:sto][:base_path]}/zk_shared_config" do
  network "10.5.43.0/25"
  writeable true
  sync true
  options ["no_root_squash"]
end
