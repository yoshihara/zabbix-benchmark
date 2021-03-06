require 'singleton'
require 'yaml'
require 'yaml/store'
require 'fileutils'

class BenchmarkConfig
  include Singleton

  attr_accessor :uri, :login_user, :login_pass, :max_retry_count
  attr_accessor :num_hosts, :hosts_step, :shuffle_hosts
  attr_accessor :host_group, :template_name, :custom_agents
  attr_accessor :warmup_duration, :measurement_duration
  attr_accessor :clear_db_on_every_step
  attr_accessor :write_throughput_result_file, :config_output_path, :histories
  attr_accessor :zabbix_log_file, :zabbix_log_directory, :rotate_zabbix_log
  attr_accessor :default_command
  attr_accessor :history_data, :history_duration_for_read
  attr_accessor :read_latency, :read_throughput

  SECONDS_IN_HOUR = 60 * 60
  ITEM_UPDATE_INTERVAL = 5

  def initialize
    @uri = "http://localhost/zabbix/"
    @login_user = "Admin"
    @login_pass = "zabbix"
    @max_retry_count = 2
    @num_hosts = 10
    @hosts_step = 0
    @shuffle_hosts = false
    @host_group = "Linux servers"
    @template_name = "Template_Linux_5sec"
    @custom_agents = []
    @default_agents = 
      [
       { "ip_address" => "127.0.0.1", "port" => 10050 },
      ]
    @zabbix_log_file = "/tmp/zabbix_server.log"
    @zabbix_log_directory = "output/log"
    @rotate_zabbix_log = false
    @write_throughput_result_file = "output/result-write-throughput.csv"
    @config_output_path = "output/config.yml"
    @histories = []
    @warmup_duration = 60
    @measurement_duration = 60
    @clear_db_on_every_step = false
    @default_command = "run"
    @history_data = {
      "begin_time" => nil,
      "end_time"   => nil,
      "num_hosts"  => 40,
      "fill_time"  => SECONDS_IN_HOUR,
    }
    @history_duration_for_read = {
      "min"  => 60,
      "max"  => 600,
      "step" => 60,
    }
    @read_latency = {
      "try_count"        => 10,
      "result_file"      => "output/result-read-latency.csv",
      "log_file"         => "output/log/read-latency.log",
    }
    @read_throughput = {
      "num_threads"      => 10,
      "history_group"    => "item", # "host" or "item"
      "result_file"      => "output/result-read-throughput.csv",
      "log_file"         => "output/log/read-throughput.log",
    }
  end

  def load_file(path)
    config_items = YAML.load_file(path)
    config_items.each do |key, value|
      obj = send("#{key}")
      if obj.instance_of?(Hash)
        obj.merge!(value)
      else
        send("#{key}=", value)
      end
    end
  end

  def export(path = nil)
    path ||= @config_output_path

    FileUtils.mkdir_p(File.dirname(path))

    db = YAML::Store.new(path)
    db.transaction do
      config_variables.each do |variable|
        key = variable.delete("@")
        db[key] = instance_variable_get(variable)
      end
    end
  end

  def agents
    if @custom_agents.empty?
      @default_agents
    else
      @custom_agents
    end
  end

  def agents=(agents)
    @custom_agents = agents
  end

  def step
    if @hosts_step > 0 and @hosts_step < @num_hosts
      @hosts_step
    elsif @num_hosts > 0
      @num_hosts
    else
      1
    end
  end

  def reset
    initialize
    self
  end

  private
  def config_variables
    ignore_variables = ["@config_output_path", "@default_agents"]
    variables = instance_variables.collect { |variable| variable.to_s }
    variables -= ignore_variables
    variables.sort
  end
end
