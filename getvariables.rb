#!/usr/bin/ruby
require 'net/https'
require 'json'

profiles = ['eat24']
profiles.each do |account|
  regions = JSON.parse(`aws ec2 describe-regions --profile #{account} --region us-east-1`)
  puts JSON.pretty_generate(regions)
end

#data = Hash[JSON.parse(shit)['aaData'].map { |tuple| ["#{tuple[0]}-#{tuple[1]}-#{tuple[3]}-#{tuple[4].match(/^hvm:/)?'hvm':'pv'}-#{tuple[4].gsub(/^hvm:/, '')}", tuple[6].gsub(/.*>(ami-[^<]*)<.*/, '\1')] }]
#output = {
#  "variable" => {
#    "all_amis" => {
#      "description" => "The AMI to use",
#      "default" => data 
#    }
#  }
#}

#File.open('variables.tf.json.new', 'w') { |f| f.puts JSON.pretty_generate(output) }


