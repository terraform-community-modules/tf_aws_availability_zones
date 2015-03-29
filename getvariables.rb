#!/usr/bin/ruby
require 'json'

profiles = []
File.open(File.expand_path('~/.aws/credentials'), 'r') do |f|
  f.each_line do |l|
    next unless l.gsub!(/^\[\s*(\w+)\s*\].*/, '\1')
    l.chomp!
    next if l == 'default'
    profiles.push(l)
  end
end

primary_azs = {}
secondary_azs = {}
tertiary_azs = {}

data = profiles.map do |account|
  regions = JSON.parse(`aws ec2 describe-regions --profile #{account} --region us-east-1`)['Regions'].map { |d| d['RegionName'] }
  regions.map do |region|
    JSON.parse(`aws ec2 describe-availability-zones --profile #{account} --region #{region}`)['AvailabilityZones'].map { |tuple| tuple[:account] = account; tuple }
  end.flatten
end.flatten.reject { |tuple| tuple['State'] != 'available' }

data.each do |tuple|
  name = "#{tuple[:account]}-#{tuple['RegionName']}"
  if !primary_azs[name]
    primary_azs[name] = tuple['ZoneName']
  elsif !secondary_azs[name]
    secondary_azs[name] = tuple['ZoneName']
  elsif !tertiary_azs[name]
    tertiary_azs[name] = tuple['ZoneName']
  end
end

output = {
 "variable" => {
    "primary_azs" => {
      "default" => primary_azs
    },
    'secondary_azs' => {
       "default" => secondary_azs
    },
    'tertiary_azs' => {
        "default" => tertiary_azs
    }
  }
}

File.open('variables.tf.json.new', 'w') { |f| f.puts JSON.pretty_generate(output) }
File.rename 'variables.tf.json.new', 'variables.tf.json'

