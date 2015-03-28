require 'ucloud_ruby_sdk'
public_key = 'your_public_key'
private_key = 'your_private_key'
region = 'cn-north-03'

@client = UCloud::Client.new(public_key, private_key, region)
result = @client.execute('DescribeImage', ImageType: 'Base', OsType: 'Linux')
image = result['ImageSet'].find{|image| image['ImageName'] == 'Ubuntu 14.04 32位'}
image_id = image['ImageId']
p "Ubuntu 14.04 32位镜像ID: #{image_id}"

def create_uhost(image_id)
  result = @client.execute('CreateUHostInstance', ImageId: image_id, ChargeType: 'Dynamic', LoginMode: 'Password', Password: 'UjAwdG1lCg==', CPU: 1, Memory: 2048, DiskSpace: 10)
  uhost_id = result['UHostIds'].first
  p "UHost创建成功, ID: #{uhost_id}"
  return uhost_id
end
uhost_id = create_uhost(image_id)

result = @client.execute('CreateULB')
ulb_id = result['ULBId']
p "创建ULB成功, ID: #{ulb_id}"

result = @client.execute('AllocateEIP', OperatorName: 'Bgp', Bandwidth: 2)
eip = result['EIPSet'].first
p "分配弹性IP成功, ID: #{eip['EIPId']}, Addr: #{eip['EIPAddr'].first['IP']}"
@client.execute('BindEIP', EIPId: eip['EIPId'], ResourceType: 'ulb', ResourceId: ulb_id)
p "绑定弹性IP到ULB成功"
result = @client.execute('CreateVServer', ULBId: ulb_id)
vserver_id = result['VServerId']
p "创建VServer成功, ID: #{vserver_id}"

def add_uhost_to_ulb(uhost_id, vserver_id, ulb_id)
  result = @client.execute('AllocateBackend', ULBId: ulb_id, VServerId: vserver_id, ResourceType: 'UHost', ResourceId: uhost_id)
  backend_id = result['BackendId']
  p "添加UHost到ULB后端实例成功, ID: #{backend_id}"
  return backend_id
end
add_uhost_to_ulb(uhost_id, vserver_id, ulb_id)

def create_custom_image(uhost_id)
  result = @client.execute('CreateCustomImage', UHostId: uhost_id, ImageName: '自定义镜像')
  image_id = result['ImageId']
  p "创建自定义镜像成功, ID: #{image_id}"
  return image_id
end
image_id = create_custom_image(uhost_id)


result = @client.execute('GetMetric', MetricName: ['NetworkOut'], ResourceType: 'ulb', ResourceId: ulb_id)
last_value = result['DataSets']['NetworkOut'].last['Value']
p "最新的网络出口流量是: #{last_value}"

if last_value > 102400
  uhost_id = create_uhost(image_id)
  add_uhost_to_ulb(uhost_id, vserver_id, ulb_id)
elsif last_value < 1024
  terminate_uhost(uhost_id)
end
