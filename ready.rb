require 'httparty'
require 'yaml'

host_id = YAML.load_file(File.expand_path('../config/host.yml', __FILE__))['host_id']

HTTParty.put("http://besdirac01.ihep.ac.cn:9292/hosts/#{host_id}", query: { status: 'READY' })
