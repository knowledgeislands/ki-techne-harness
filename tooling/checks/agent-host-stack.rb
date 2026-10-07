#!/usr/bin/env ruby

# Offline structural checks for the agent-host stack. CloudFormation short-form
# tags (!Ref, !Sub) load as their plain values, which is sufficient here.

require 'open3'
require 'tmpdir'
require 'tempfile'
require 'yaml'

path = ARGV.fetch(0) { abort 'usage: agent-host-stack.rb <template>' }
template = YAML.load(File.read(path))
resources = template.fetch('Resources')
parameters = template.fetch('Parameters')
failures = []
check = ->(condition, message) { failures << message unless condition }

expected_tags = {
  'Name' => 'HostName',
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
# Binding values (recipes/direct-host/recipe.toml) arrive as parameters whose
# defaults are the agent-host binding's, so the first binding changes nothing.
{
  'AgentHostId' => 'agent-host',
  'HostName' => 'ki-techne-agent-host',
  'TailscaleHostname' => 'ki-techne-agent-host',
  'TailscaleTag' => 'tag:ki-techne-agent-host',
  'ParameterPrefix' => '/ki/techne/agent-host',
  'InstanceType' => 't3.medium',
  'VolumeSize' => 40
}.each do |name, default|
  check.call(parameters.dig(name, 'Default') == default, "#{name} default must be #{default.inspect}")
end
%w[Resources Outputs].each do |section|
  body = YAML.dump(template.fetch(section))
  check.call(!body.match?(%r{ki-techne-agent-host|/ki/techne/agent-host}), "#{section} must take host values from parameters, not literals")
end
check.call(template.dig('Outputs', 'TailscaleHostname', 'Value') == 'TailscaleHostname', 'TailscaleHostname output must be the parameter')
check.call(parameters.dig('OperatorUser', 'Default') == 'techne', 'operator user default must be techne')

instance = resources.fetch('AgentHostInstance').fetch('Properties')
check.call(instance.dig('MetadataOptions', 'HttpTokens') == 'required', 'instance metadata must require tokens')
check.call(instance.fetch('BlockDeviceMappings').all? { |mapping| mapping.dig('Ebs', 'Encrypted') == true }, 'volumes must be encrypted')
check.call(instance.fetch('NetworkInterfaces').all? { |nic| nic['GroupSet'] == ['AgentHostSecurityGroup'] },
           'instance must use only the agent-host security group')

# Every ${...} in the Fn::Sub body must name a parameter or pseudo parameter;
# shell variables are written without braces.
user_data = instance.dig('UserData', 'Fn::Base64')
pseudo = { 'AWS::Region' => 'eu-west-1', 'AWS::AccountId' => '000000000000', 'AWS::Partition' => 'aws' }
render = lambda do |overrides = {}|
  user_data.gsub(/\$\{([^}]+)\}/) do
    name = Regexp.last_match(1)
    if pseudo.key?(name)
      pseudo[name]
    elsif parameters.key?(name)
      overrides.fetch(name) { parameters.dig(name, 'Default') }.to_s
    else
      failures << "user data references unknown substitution ${#{name}}"
      ''
    end
  end
end
rendered = render.call

# A second binding's values reach the host name, tailnet name, tag and prefix.
other = render.call('HostName' => 'ki-techne-scratch', 'TailscaleHostname' => 'scratch-tail',
                    'TailscaleTag' => 'tag:ki-techne-scratch', 'ParameterPrefix' => '/ki/techne/scratch')
check.call(other.include?('hostnamectl set-hostname ki-techne-scratch') && other.include?('127.0.1.1 ki-techne-scratch'),
           'user data must set the OS hostname from HostName')
check.call(other.include?("--advertise-tags='tag:ki-techne-scratch' --hostname=scratch-tail"),
           'user data must join the tailnet with TailscaleTag and TailscaleHostname')
check.call(other.include?('/ki/techne/scratch/tailscale-auth-key') && !other.include?('/ki/techne/agent-host'),
           'user data must read parameters only under ParameterPrefix')
check.call(rendered.include?("tailscale up --auth-key=\"file:$key_file\" --ssh --advertise-tags='tag:ki-techne-agent-host'"),
           'user data must join the tailnet with Tailscale SSH and the agent-host tag')
check.call(rendered.include?('/ki/techne/agent-host/tailscale-auth-key'), 'user data must read the auth key parameter')
check.call(rendered.include?('hostnamectl set-hostname ki-techne-agent-host'), 'user data must set the OS hostname')
check.call(rendered.include?('preserve_hostname: true') && rendered.include?('127.0.1.1 ki-techne-agent-host'),
           'user data must keep the hostname across boots and resolvable in /etc/hosts')
check.call(!rendered.match?(/^\s*set -[a-z]*x/), 'user data must not trace commands')
check.call(!rendered.match?(/sudoers|usermod|adduser|--groups|\s-G\s/), 'the operator user must not gain sudo or extra groups')
check.call(rendered.include?("git config --global credential.https://github.com.helper ki-agent-host"),
           'user data must configure the GitHub credential helper for the operator user')

# The credential helper is a quoted heredoc in the user data; run it against a
# stub aws that records its arguments.
helper = rendered[/<<'HELPER'\n(.*?)^HELPER$/m, 1]
check.call(!helper.nil?, 'user data must install the GitHub credential helper')
if helper
  Dir.mktmpdir('agent-host-credential-helper') do |dir|
    log = File.join(dir, 'aws.log')
    stub = File.join(dir, 'aws')
    File.write(stub, "#!/usr/bin/env bash\necho \"$*\" >>'#{log}'\necho stub-token\n")
    File.chmod(0o755, stub)
    script = File.join(dir, 'git-credential-ki-agent-host')
    File.write(script, helper.sub('/snap/bin/aws', stub))
    File.chmod(0o755, script)

    output, status = Open3.capture2e('shellcheck', '--shell=bash', script)
    check.call(status.success?, "credential helper fails shellcheck:\n#{output}")

    output, status = Open3.capture2(script, 'get', stdin_data: "protocol=https\nhost=github.com\n\n")
    check.call(status.success? && output == "username=x-access-token\npassword=stub-token\n",
               "credential helper must answer GitHub with the token, got #{output.inspect}")
    calls = File.exist?(log) ? File.read(log) : ''
    check.call(calls.include?('--name /ki/techne/agent-host/github-token --with-decryption'),
               "credential helper must read only the github-token parameter, got #{calls.inspect}")

    File.delete(log) if File.exist?(log)
    [['get', "protocol=https\nhost=gitlab.com\n\n"], ['get', "protocol=http\nhost=github.com\n\n"],
     ['store', "protocol=https\nhost=github.com\npassword=x\n\n"]].each do |action, input|
      output, status = Open3.capture2(script, action, stdin_data: input)
      check.call(status.success? && output.empty?, "credential helper must ignore #{action} #{input.lines.first(2).join.inspect}")
    end
    check.call(!File.exist?(log), 'credential helper must not read the token for other hosts or actions')
  end
end

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
