require 'clockwork'
require 'httparty'

require 'yaml'
require 'json'
require 'open3'
require 'base64'
require 'fileutils'

$host_id = YAML.load_file(File.expand_path('../config/host.yml', __FILE__))['host_id']

module Clockwork
  every 1.minute, 'Fetch job' do
    response = HTTParty.get('http://besdirac01.ihep.ac.cn:9292/job_pools', query: { host_id: $host_id })
    JSON.parse(response.body).each do |job_pool|
      if job_pool['operation'] == 'START'
        response_job = HTTParty.get("http://besdirac01.ihep.ac.cn:9292/jobs/#{job_pool['job_id']}")
        job = JSON.parse(response_job.body)

        job_dir = "/tmp/#{job['job_id']}"
        Dir.mkdir job_dir
        job_exe = File.join(job_dir, job['exe_name'])
        File.open(job_exe, 'wb') do |file|
          file.write Base64.decode64(job['exe_file'])
        end
        File.chmod(0755, job_exe)

        HTTParty.put("http://besdirac01.ihep.ac.cn:9292/jobs/#{job['job_id']}", query: { status: 'RUNNING' })

        puts "Running job #{job['job_id']}"

        Dir.chdir job_dir
        job_stdout = ''
        job_stderr = ''
        Open3.popen3(job_exe) do |stdin, stdout, stderr, wait_thr|
          job_stdout = stdout.read
          job_stderr = stderr.read
          puts 'STDOUT:', job_stdout
          puts 'STDERR:', job_stderr
        end

        HTTParty.put("http://besdirac01.ihep.ac.cn:9292/jobs/#{job['job_id']}",
            query: { status: 'DONE' }, body: { stdout: Base64.encode64(job_stdout), stderr: Base64.encode64(job_stderr) })

        FileUtils.rm_rf(job_dir)
      end

      HTTParty.delete("http://besdirac01.ihep.ac.cn:9292/job_pools/#{job_pool['id']}")
    end
  end
end
