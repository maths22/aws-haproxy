require 'aws-sdk-autoscaling'
require 'aws-sdk-ec2'
require 'aws-sdk-route53'

def lambda_handler(event:, context:)
  group = autoscaling_client.describe_auto_scaling_groups(auto_scaling_group_names: [event['detail']['AutoScalingGroupName']])
    .auto_scaling_groups.first

  tags = group.tags.map do |t|
      [t.key, t.value]
    end.to_h

  return unless tags['Role'] == 'Haproxy'

  instance_ids = group.instances.map(&:instance_id)
  running_instances = if instance_ids.length.zero?
    []
  else
    ec2_client.describe_instances(instance_ids: instance_ids).reservations.flat_map(&:instances).map(&:public_ip_address)
  end

  route53_client.change_resource_record_sets(
    hosted_zone_id: ENV['hosted_zone_id'],
    change_batch: {
      changes: [{
        action: 'UPSERT',
        resource_record_set: {
          name: tags['DNSName'],
          resource_records: running_instances.map { |v| { value: v } },
          ttl: 60,
          type: 'A'
        }
      }],
      comment: 'Autoscaling group member change'
    }
  )
end

def autoscaling_client
  @autoscaling_client ||= Aws::AutoScaling::Client.new
end

def route53_client
  @route53_client ||= Aws::Route53::Client.new
end

def ec2_client
  @ec2_client ||= Aws::EC2::Client.new
end
