#!/usr/bin/env ruby

# Offline structural checks for the agent-host stack. CloudFormation short-form
# tags (!Ref, !Sub) load as their plain values, which is sufficient here.

require 'open3'
require 'tempfile'
require 'yaml'

path = ARGV.fetch(0) { abort 'usage: agent-host-stack.rb <template>' }
template = YAML.load(File.read(path))
resources = template.fetch('Resources')
parameters = template.fetch('Parameters')
failures = []
check = ->(condition, message) { failures << message unless condition }

expected_tags = {
  'Name' => 'ki-techne-agent-host',
  'ki-agent-host-id' => 'AgentHostId',
  'ki-lifecycle' => 'prototype',
  'ki-work-item' => 'KI-ARCADIA-GOV-020'
}

text = File.read(path)
check.call(!text.match?(/Controller|ImportValue|ops-007/i), 'template must not reference the controller stack or its resources')

resources.each do |name, resource|
  check.call(resource['Type'] != 'AWS::EC2::SecurityGroupIngress', "#{name}: ingress resources are prohibited")
  tags = resource.dig('Properties', 'Tags')
  next unless tags

  actual = tags.to_h { |tag| [tag['Key'], tag['Value']] }
  check.call(actual == expected_tags, "#{name}: tags must be exactly #{expected_tags.keys.join(', ')}")
end

group = resources.fetch('AgentHostSecurityGroup').fetch('Properties')
check.call(!group.key?('SecurityGroupIngress'), 'security group must have no ingress rules')
egress = group.fetch('SecurityGroupEgress').map { |rule| [rule['IpProtocol'], rule['FromPort'], rule['ToPort']] }
check.call(egress.sort == [['tcp', 443, 443], ['tcp', 80, 80], ['udp', 3478, 3478], ['udp', 41641, 41641]].sort,
           "unexpected egress rules: #{egress.inspect}")

role = resources.fetch('AgentHostRole').fetch('Properties')
check.call(!role.key?('ManagedPolicyArns'), 'instance role must not attach managed policies')
statements = role.fetch('Policies').flat_map { |policy| policy.dig('PolicyDocument', 'Statement') }
statements.each do |statement|
  check.call(statement['Effect'] == 'Allow', 'unexpected role statement effect')
  actions = Array(statement['Action'])
  if actions == ['kms:Decrypt']
    check.call(statement.dig('Condition', 'StringEquals', 'kms:ViaService').to_s.start_with?('ssm.'),
               'kms:Decrypt must be limited to Parameter Store')
  else
    check.call(actions.sort == %w[ssm:GetParameter ssm:GetParameters], "unexpected role actions: #{actions.inspect}")
    check.call(statement['Resource'].to_s.end_with?(':parameter${ParameterPrefix}/*'), 'parameter access must be limited to the prefix')
  end
end
check.call(parameters.dig('ParameterPrefix', 'Default') == '/ki/techne/agent-host', 'parameter prefix default changed')

instance = resources.fetch('AgentHostInstance').fetch('Properties')
check.call(instance.dig('MetadataOptions', 'HttpTokens') == 'required', 'instance metadata must require tokens')
check.call(instance.fetch('BlockDeviceMappings').all? { |mapping| mapping.dig('Ebs', 'Encrypted') == true }, 'volumes must be encrypted')
check.call(instance.fetch('NetworkInterfaces').all? { |nic| nic['GroupSet'] == ['AgentHostSecurityGroup'] },
           'instance must use only the agent-host security group')

# Every ${...} in the Fn::Sub body must name a parameter or pseudo parameter;
# shell variables are written without braces.
user_data = instance.dig('UserData', 'Fn::Base64')
pseudo = { 'AWS::Region' => 'eu-west-1', 'AWS::AccountId' => '000000000000', 'AWS::Partition' => 'aws' }
rendered = user_data.gsub(/\$\{([^}]+)\}/) do
  name = Regexp.last_match(1)
  if pseudo.key?(name)
    pseudo[name]
  elsif parameters.key?(name)
    parameters.dig(name, 'Default').to_s
  else
    failures << "user data references unknown substitution ${#{name}}"
    ''
  end
end
check.call(rendered.include?("tailscale up --auth-key=\"file:$key_file\" --ssh --advertise-tags='tag:ki-techne-agent-host'"),
           'user data must join the tailnet with Tailscale SSH and the agent-host tag')
check.call(rendered.include?('/ki/techne/agent-host/tailscale-auth-key'), 'user data must read the auth key parameter')
check.call(!rendered.match?(/^\s*set -[a-z]*x/), 'user data must not trace commands')

Tempfile.create(['agent-host-user-data', '.sh']) do |file|
  file.write(rendered)
  file.flush
  _, status = Open3.capture2e('bash', '-n', file.path)
  check.call(status.success?, 'user data fails bash -n')
  output, status = Open3.capture2e('shellcheck', '--shell=bash', file.path)
  check.call(status.success?, "user data fails shellcheck:\n#{output}")
end

abort failures.map { |failure| "#{path}: #{failure}" }.join("\n") unless failures.empty?

puts "validated #{path}"
