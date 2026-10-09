#!/usr/bin/env ruby

# Offline structural checks for the agent-host stack. CloudFormation short-form
# tags (!Ref, !Sub) load as their plain values, which is sufficient here.

require 'fileutils'
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
# Binding values (recipes/agent-host/recipe.toml) arrive as parameters whose
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
# shell variables are written without braces, and ${!name} renders as a literal ${name}.
user_data = instance.dig('UserData', 'Fn::Base64')
pseudo = { 'AWS::Region' => 'eu-west-1', 'AWS::AccountId' => '000000000000', 'AWS::Partition' => 'aws' }
render = lambda do |overrides = {}|
  user_data.gsub(/\$\{([^}]+)\}/) do
    name = Regexp.last_match(1)
    if name.start_with?('!')
      "${#{name[1..]}}"
    elsif pseudo.key?(name)
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

# OS patching (TECHNE-TOOLS-OPS-022). The window is a daily 24-hour HH:MM or
# empty; CloudFormation matches AllowedPattern against the whole value.
window_pattern = Regexp.new("\\A(?:#{parameters.dig('RebootWindow', 'AllowedPattern')})\\z")
check.call(parameters.dig('RebootWindow', 'Default') == '' && parameters.dig('Livepatch', 'Default') == 'false',
           'RebootWindow must default to none and Livepatch to off')
check.call(['', '04:00', '23:59', '00:00'].all? { |value| window_pattern.match?(value) },
           'RebootWindow must accept a daily HH:MM or empty')
check.call(['Sun 04:00', 'Sun 04:00:00', '24:00', '4:00', '04:00:00', '*-*-* 04:00'].none? { |value| window_pattern.match?(value) },
           'RebootWindow must reject a weekday, seconds or an invalid time')
check.call(parameters.dig('Livepatch', 'AllowedValues') == %w[false true], 'Livepatch must be false or true')

origins = rendered[%r{^Unattended-Upgrade::Allowed-Origins \{\n(.*?)^\};$}m, 1].to_s.lines.map(&:strip)
check.call(origins == ['"${distro_id}:${distro_codename}-security";', '"${distro_id}ESMApps:${distro_codename}-apps-security";',
                       '"${distro_id}ESM:${distro_codename}-infra-security";'],
           "unattended upgrades must allow security origins only, got #{origins.inspect}")
check.call(rendered.include?("#clear Unattended-Upgrade::Allowed-Origins;\n#clear Unattended-Upgrade::Origins-Pattern;"),
           'the security-only origins must replace the image defaults')
check.call(rendered.include?('APT::Periodic::Unattended-Upgrade "1";') && rendered.include?('APT::Periodic::Update-Package-Lists "1";'),
           'user data must enable the daily list update and unattended upgrade')
check.call(rendered.scan(/Automatic-Reboot\b.*$/) == ['Automatic-Reboot "false";'],
           'unattended upgrades must never reboot the host themselves')
check.call(!user_data.match?(/amazon-ssm-agent\.service.*enable|PatchManager|AWS-RunPatchBaseline/), 'patching must not use SSM')

# run_block <name> <rendered> <pattern> <paths> <stubs>: runs one block of the
# user data in a temporary root, its system paths moved there and its commands
# stubbed to log their arguments; returns the root and the stub log. The
# boot script's key_file is set by then, so the block may name it.
run_block = lambda do |name, text, pattern, paths, stubs, env = {}|
  block = text[pattern]
  check.call(!block.nil?, "user data must hold the #{name} block")
  next [nil, ''] unless block

  root = Dir.mktmpdir("agent-host-#{name.tr(' ', '-')}")
  bin = File.join(root, 'bin')
  Dir.mkdir(bin)
  log = File.join(root, 'stub.log')
  stubs.each do |command, body|
    File.write(File.join(bin, command), "#!/usr/bin/env bash\necho \"#{command} $*\" >>'#{log}'\n#{body}\n")
    File.chmod(0o755, File.join(bin, command))
  end
  block = block.gsub('/snap/bin/aws', 'aws')
  paths.each do |path|
    FileUtils.mkdir_p(File.join(root, path))
    block = block.gsub(path, File.join(root, path))
  end
  output, status = Open3.capture2e(env.merge('PATH' => "#{bin}:/usr/bin:/bin", 'key_file' => File.join(root, 'key')),
                                   'bash', '-c', "set -euo pipefail\n#{block}")
  check.call(status.success?, "the #{name} block must run:\n#{output}")
  [root, File.exist?(log) ? File.read(log) : '']
end

# The reboot timer exists only with a window, fires daily at it, and its
# service restarts only when a reboot is required and who lists no session.
reboot_block = /^reboot_window=.*?\nif \[\[ -n \$reboot_window \]\]; then\n.*?enable --now ki-agent-host-reboot\.timer\nfi$/m
unit_paths = ['/usr/local/sbin', '/etc/systemd/system']
root, calls = run_block.call('reboot window', rendered, reboot_block, unit_paths, { 'systemctl' => '', 'chmod' => '' })
check.call(root && Dir.glob(File.join(root, '{usr,etc}', '**', 'ki-agent-host-reboot*')).empty? && calls.empty?,
           'with no window, user data must install no reboot timer')
FileUtils.rm_rf(root) if root
windowed = render.call('RebootWindow' => '04:00')
root, calls = run_block.call('reboot window', windowed, reboot_block, unit_paths, { 'systemctl' => '', 'chmod' => '' })
if root
  timer = File.read(File.join(root, '/etc/systemd/system/ki-agent-host-reboot.timer')) rescue ''
  check.call(timer.lines.grep(/^OnCalendar=/) == ["OnCalendar=*-*-* 04:00:00\n"],
             "the reboot timer must fire daily at the window, got #{timer.inspect}")
  check.call(timer.include?('WantedBy=timers.target') && !timer.match?(/Persistent=true/),
             'the reboot timer must be enabled and must not catch up on a missed window')
  check.call(calls.include?('systemctl enable --now ki-agent-host-reboot.timer'), "the reboot timer must be enabled, got #{calls.inspect}")
  service = File.read(File.join(root, '/etc/systemd/system/ki-agent-host-reboot.service')) rescue ''
  check.call(service.include?("ExecStart=#{root}/usr/local/sbin/ki-agent-host-reboot\n"), 'the reboot service must run the guard')
  FileUtils.rm_rf(root)
end

guard = windowed[/<<'REBOOT'\n(.*?)^REBOOT$/m, 1]
check.call(!guard.nil?, 'user data must install the reboot guard')
if guard
  Dir.mktmpdir('agent-host-reboot-guard') do |dir|
    bin = File.join(dir, 'bin')
    Dir.mkdir(bin)
    log = File.join(dir, 'systemctl.log')
    File.write(File.join(bin, 'systemctl'), "#!/usr/bin/env bash\necho \"$*\" >>'#{log}'\n")
    File.write(File.join(bin, 'who'), "#!/usr/bin/env bash\ncat '#{dir}/who' 2>/dev/null || true\n")
    [File.join(bin, 'systemctl'), File.join(bin, 'who')].each { |stub| File.chmod(0o755, stub) }
    flag = File.join(dir, 'reboot-required')
    script = File.join(dir, 'ki-agent-host-reboot')
    File.write(script, guard.gsub('/var/run/reboot-required', flag))
    File.chmod(0o755, script)
    output, status = Open3.capture2e('shellcheck', '--shell=bash', script)
    check.call(status.success?, "reboot guard fails shellcheck:\n#{output}")
    attempt = lambda do
      File.delete(log) if File.exist?(log)
      Open3.capture2e({ 'PATH' => "#{bin}:/usr/bin:/bin" }, script)
      File.exist?(log) ? File.read(log) : ''
    end
    check.call(attempt.call.empty?, 'the guard must not restart when no reboot is required')
    File.write(flag, "*** System restart required ***\n")
    File.write(File.join(dir, 'who'), "techne   pts/0        2026-10-09 04:00 (100.64.0.1)\n")
    check.call(attempt.call.empty?, 'the guard must not restart while who lists a session')
    File.delete(File.join(dir, 'who'))
    check.call(attempt.call == "reboot\n", 'the guard must restart when a reboot is required and nobody is logged in')
  end
end

# Livepatch reads the Pro token only when on, into a file on /run, and attaches
# from that file; the token never reaches a command line or disk.
livepatch_block = /^livepatch=.*?\nif \[\[ \$livepatch == true \]\]; then\n.*?^fi$/m
pro_stubs = {
  'aws' => 'echo stub-pro-token',
  'pro' => 'cp "$3" "$(dirname "$0")/../attach-config"'
}
root, calls = run_block.call('Livepatch', rendered, livepatch_block, ['/run/'], pro_stubs)
check.call(root && calls.empty?, "with Livepatch off, user data must not read the Pro token or attach, got #{calls.inspect}")
FileUtils.rm_rf(root) if root
patched = render.call('Livepatch' => 'true')
check.call(patched[livepatch_block].to_s.include?("mktemp /run/ki-agent-host-pro."), 'the Pro attach configuration must live on /run')
root, calls = run_block.call('Livepatch', patched, livepatch_block, ['/run/'], pro_stubs)
if root
  check.call(calls.include?('aws ssm get-parameter --region eu-west-1 --name /ki/techne/agent-host/ubuntu-pro-token --with-decryption'),
             "Livepatch must read the Pro token under ParameterPrefix, got #{calls.inspect}")
  check.call(calls.match?(%r{^pro attach --attach-config \S*/run/ki-agent-host-pro\.\S+$}) && !calls.include?('pro attach stub-pro-token'),
             "Livepatch must attach from the configuration file, got #{calls.inspect}")
  attach = File.read(File.join(root, 'attach-config')) rescue ''
  check.call(attach == "token: stub-pro-token\nenable_services:\n  - livepatch\n", "the attach configuration must enable Livepatch, got #{attach.inspect}")
  check.call(Dir.glob(File.join(root, 'run', 'ki-agent-host-pro.*')).empty?, 'the attach configuration must be removed after attaching')
  FileUtils.rm_rf(root)
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
