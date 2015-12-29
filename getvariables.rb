#!/usr/bin/ruby
require 'json'
require 'net/http'
require 'optparse'

options = {:iam_profile_name => nil, :aws_account => 'default' }
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: getvariables.rb [options]"
  opts.on('-i','--iam-profile-name iam_profile_name', 'IAM Profile Name') do |iam_profile_name|
    options[:iam_profile_name] = iam_profile_name
  end
  opts.on('-a','--aws-account aws_account', 'AWS Account Name') do |aws_account|
    options[:aws_account] = aws_account
  end
  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end

optparse.parse!

ENV.delete('AWS_ACCESS_KEY_ID')
ENV.delete('AWS_SECRET_ACCESS_KEY')

def is_iam_instance?(profile_name)
  return nil if profile_name.nil?
  begin
    iam_info = Net::HTTP.get('169.254.169.254','/latest/meta-data/iam/info')
  rescue Exception => e
    return nil
  end
  return true if JSON.parse(iam_info)['InstanceProfileArn'].split(':')[5].split('/')[1] == profile_name
  return nil
end

profiles = []
unless is_iam_instance?(options[:iam_profile_name])
  File.open(File.expand_path('~/.aws/credentials'), 'r') do |f|
    f.each_line do |l|
      next unless l.gsub!(/^\[\s*(.*?)\s*\].*/, '\1')
      l.chomp!
      profiles.push(l)
    end
  end
else
  profiles = options[:aws_account].split(',')
end

primary_azs = {}
secondary_azs = {}
tertiary_azs = {}
az_counts = {}
az_lists = {}
az_letters = {}

data = profiles.map do |account|
  regions_json = `aws ec2 describe-regions --output json --profile #{account} --region us-east-1` unless is_iam_instance?(options[:iam_profile_name])
  regions_json = `aws ec2 describe-regions --output json --region us-east-1` if is_iam_instance?(options[:iam_profile_name])
  if $?.exitstatus != 0
    print "Failed to run aws ec2 describe-regions --output json --profile #{account} --region us-east-1"
    exit 1
  end
  regions = JSON.parse(regions_json)['Regions'].map { |d| d['RegionName'] }
  regions.map do |region|
    azs_json = `aws ec2 describe-availability-zones --output json --profile #{account} --region #{region}` unless is_iam_instance?(options[:iam_profile_name])
    azs_json = `aws ec2 describe-availability-zones --output json --region #{region}` if is_iam_instance?(options[:iam_profile_name])

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
