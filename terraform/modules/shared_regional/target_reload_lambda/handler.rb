require 'aws-sdk-autoscaling'
require 'aws-sdk-ec2'
require 'net/http'

def lambda_handler(event:, context:)
  groups = autoscaling_client.describe_tags(filters: [
    {
      name: "key",
      values: ["SourceGroup"],
    },
    {
      name: "value",
      values: [event['detail']['AutoScalingGroupName']],
    },
  ]).tags.map(&:resource_id)

  return if groups.length.zero?

  instance_ids = autoscaling_client.describe_auto_scaling_groups(auto_scaling_group_names: groups)
    .auto_scaling_groups.flat_map(&:instances).map(&:instance_id)

  running_instances = if instance_ids.length.zero?
    []
  else
    ec2_client.describe_instances(instance_ids: instance_ids).reservations.flat_map(&:instances).map(&:public_ip_address)
  end

  running_instances.each do |ip|
    Net::HTTP.get(ip, '/reload', 91)
  end
end

def autoscaling_client
  @autoscaling_client ||= Aws::AutoScaling::Client.new
end

def ec2_client
  @ec2_client ||= Aws::EC2::Client.new
end
