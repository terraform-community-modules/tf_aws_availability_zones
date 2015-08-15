#!/usr/bin/ruby
require 'json'
require 'aws-sdk'

def get_aws_profiles
# Read all the available profile.
# For safety reasons 'default' profile will be skipped.
  profiles = []
  File.open(File.expand_path('~/.aws/credentials'), 'r') do |f|
    f.each_line do |l|
      next unless l.gsub!(/^\[\s*(\w+)\s*\].*/, '\1')
      l.chomp!
      next if l == 'default'
      profiles.push(l)
    end
  end
  profiles
end

def get_AZs_by_profile account
  credentials = Aws::SharedCredentials.new(profile_name: "#{account}")
  @ec2 = Aws::EC2::Client.new(credentials: credentials, region: 'us-east-1')

  begin
    data = []
    regions = @ec2.describe_regions().data.regions.map { |region| region.region_name}

    regions.each do |region|
      @ec2 = Aws::EC2::Client.new(credentials: credentials, region: "#{region}")
      @ec2.describe_availability_zones({ filters: [{ name: 'state', values: ['available']}] }).data.availability_zones.map do |az|
        data <<  { 'State' => az.state, 'RegionName' => az.region_name, 'ZoneName' => az.zone_name, :name => "#{account}-#{az.region_name}", :sortkey => "#{account}-#{az.zone_name}" }
      end
    end

    # Sort the AZs by account
    data.sort { |a,b| a[:sortkey] <=> b[:sortkey] }
  rescue StandardError => e
    puts e.message
  end
end

def build_variables_file data
  # Output variables
  primary_azs = {}
  secondary_azs = {}
  tertiary_azs = {}
  az_counts = {}
  az_lists = {}
  az_letters = {}

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

  begin
    File.open('variables.tf.json.new', 'w') { |f| f.puts JSON.pretty_generate(output) }
    File.rename 'variables.tf.json.new', 'variables.tf.json'
  rescue StandardError => e
    puts e.message
  end
end

# RUN RUN
variables = []
get_aws_profiles.each { |account| variables += get_AZs_by_profile account }
build_variables_file variables



