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
az_letters = {}

data = profiles.map do |account|
  regions_json = `aws ec2 describe-regions --output json --profile #{account} --region us-east-1`
  if $?.exitstatus != 0
    print "Failed to run aws ec2 describe-regions --output json --profile #{account} --region us-east-1"
    exit 1
  end
  regions = JSON.parse(regions_json)['Regions'].map { |d| d['RegionName'] }
  regions.map do |region|
    azs_json = `aws ec2 describe-availability-zones --output json --profile #{account} --region #{region}`
    if $?.exitstatus != 0
      print "Failed to run aws ec2 describe-availability-zones --output json --profile #{account} --region #{region}"
      exit 1
    end
    JSON.parse(azs_json)['AvailabilityZones'].map do |tuple|
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
  az_counts[tuple[:name]] = az_counts[tuple[:name]]+1
  az_lists[tuple[:name]] ||= []
  az_lists[tuple[:name]].push tuple['ZoneName']
  az_letters[tuple[:name]] ||= []
  az_letters[tuple[:name]].push tuple['ZoneName'][-1,1]
  if !primary_azs[tuple[:name]]
    primary_azs[tuple[:name]] = tuple['ZoneName']
  elsif !secondary_azs[tuple[:name]]
    secondary_azs[tuple[:name]] = tuple['ZoneName']
  elsif !tertiary_azs[tuple[:name]]
    tertiary_azs[tuple[:name]] = tuple['ZoneName']
  end
end

[az_lists, az_letters].each do |squash|
  squash.each_key { |k| squash[k] = squash[k].join ',' }
end
az_counts.each_key { |k| az_counts[k] = "#{az_counts[k]}" }

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
    'list_all' => {
        'default' => az_lists
    },
    'list_letters' => {
        'default' => az_letters
    },
    'az_counts' => {
        'default' => az_counts
    }
  }
}

File.open('variables.tf.json.new', 'w') { |f| f.puts JSON.pretty_generate(output) }
File.rename 'variables.tf.json.new', 'variables.tf.json'
