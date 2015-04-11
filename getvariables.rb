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
az_counts = {}
az_lists = {}

data = profiles.map do |account|
  regions = JSON.parse(`aws ec2 describe-regions --profile #{account} --region us-east-1`)['Regions'].map { |d| d['RegionName'] }
  regions.map do |region|
    JSON.parse(`aws ec2 describe-availability-zones --profile #{account} --region #{region}`)['AvailabilityZones'].map do |tuple|
      tuple[:name] = "#{account}-#{tuple['RegionName']}"
      tuple[:sortkey] = "#{account}-#{tuple['ZoneName']}"
      tuple
    end
  end.flatten
end.flatten.reject { |tuple| tuple['State'] != 'available' }.sort do |a,b|
  a[:sortkey] <=> b[:sortkey] 
end

data.each do |tuple|
  az_counts[tuple[:name]] ||= 0
  az_counts[tuple[:name]]++
  az_lists[tuple[:name]] ||= []
  az_lists[tuple[:name]].push tuple['ZoneName']
  if !primary_azs[tuple[:name]]
    primary_azs[tuple[:name]] = tuple['ZoneName']
  elsif !secondary_azs[tuple[:name]]
    secondary_azs[tuple[:name]] = tuple['ZoneName']
  elsif !tertiary_azs[tuple[:name]]
    tertiary_azs[tuple[:name]] = tuple['ZoneName']
  end
end

az_lists.each_key { |k| az_lists[k] = az_lists[k].join ',' }

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
    },
    'az_lists' => {
        'default' => az_lists
    },
    'az_counts' => {
        'default' => az_counts
    }
  }
}

File.open('variables.tf.json.new', 'w') { |f| f.puts JSON.pretty_generate(output) }
File.rename 'variables.tf.json.new', 'variables.tf.json'

