#!/usr/bin/env ruby

require 'yaml'

abort 'usage: validate-manifests.rb <manifest>...' if ARGV.empty?

ARGV.each do |path|
  documents = YAML.load_stream(File.read(path)).compact
  abort "#{path}: no YAML documents" if documents.empty?

  documents.each_with_index do |document, index|
    unless document.is_a?(Hash) && document['apiVersion'].is_a?(String) && document['kind'].is_a?(String)
      abort "#{path}: document #{index + 1} lacks apiVersion or kind"
    end

    metadata = document['metadata']
    unless metadata.is_a?(Hash) && metadata['name'].is_a?(String)
      abort "#{path}: document #{index + 1} lacks metadata.name"
    end
  end
end

puts "validated #{ARGV.length} Kubernetes manifest files"
