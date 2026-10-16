require "erb"
require "fileutils"

COMPONENTS = {
  "TcpInput" => {
    module_name: "Proxy.Transport.TcpInput",
    function_name: "tcpInput",
    package: "stm-markov-proxy"
  },
  "NamedPipeOutput" => {
    module_name: "Proxy.Transport.NamedPipeOutput",
    function_name: "namedPipeOutput",
    package: "stm-markov-proxy"
  },
  "UnixSocketOutput" => {
    module_name: "Proxy.Transport.UnixSocketOutput",
    function_name: "unixSocketOutput",
    package: "stm-markov-proxy"
  }
}.freeze

PROXIES = {
  raw_tcp_proxy: {
    name: "raw-tcp-proxy",
    package_name: "raw-tcp-proxy-generated",
    composition: :kleisli,
    input: {
      component: "TcpInput",
      args: ["127.0.0.1", 9300]
    },
    output: {
      component: "UnixSocketOutput",
      args: ["/tmp/chaindb-proxy-test.sock"]
    }
  },
  raw_tcp_pipe_proxy: {
    name: "raw-tcp-pipe-proxy",
    package_name: "raw-tcp-pipe-proxy-generated",
    composition: :kleisli,
    input: {
      component: "TcpInput",
      args: ["127.0.0.1", 9300]
    },
    output: {
      component: "NamedPipeOutput",
      args: ["/tmp/chaindb-proxy-test.pipe"]
    }
  }
}.freeze

def haskell_literal(value)
  case value
  when String
    value.inspect
  when Integer
    value.to_s
  else
    raise ArgumentError, "Unsupported Haskell literal: #{value.inspect}"
  end
end

def component_call(component, args)
  function_name = component.fetch(:function_name)
  arguments = args.map { |argument| haskell_literal(argument) }
  ([function_name] + arguments).join(" ")
end

def render(template_path, output_path, values)
  template = ERB.new(File.read(template_path), trim_mode: "-")
  FileUtils.mkdir_p(File.dirname(output_path))
  File.write(output_path, template.result_with_hash(values))
end

def generate_proxy(proxy, generated_directory)
  input = COMPONENTS.fetch(proxy.fetch(:input).fetch(:component))
  output = COMPONENTS.fetch(proxy.fetch(:output).fetch(:component))

  values = proxy.merge(
    imports: [input, output],
    input_call: component_call(input, proxy.fetch(:input).fetch(:args)),
    output_call: component_call(output, proxy.fetch(:output).fetch(:args)),
    dependencies: ["base ^>=4.18.3.0", input.fetch(:package), output.fetch(:package)].uniq
  )

  render(
    "templates/raw-tcp-proxy/Main.hs.erb",
    "#{generated_directory}/app/Main.hs",
    values
  )
  render(
    "templates/raw-tcp-proxy/package.cabal.erb",
    "#{generated_directory}/#{proxy.fetch(:package_name)}.cabal",
    values
  )

  File.write(
    "#{generated_directory}/cabal.project",
    "packages:\n  .\n  #{generated_directory}\n"
  )

  puts "Generated #{proxy.fetch(:name)} with #{proxy.fetch(:composition)} composition"
end

PROXIES.each do |task_name, proxy|
  generated_directory = "generated/#{proxy.fetch(:name)}"

  namespace task_name do
    desc "Generate #{proxy.fetch(:name)}"
    task :generate do
      generate_proxy(proxy, generated_directory)
    end

    desc "Build #{proxy.fetch(:name)}"
    task build: :generate do
      sh(
        "cabal",
        "build",
        "--project-file=#{generated_directory}/cabal.project",
        "#{proxy.fetch(:package_name)}:exe:#{proxy.fetch(:name)}"
      )
    end
  end

  desc "Generate and build #{proxy.fetch(:name)}"
  task task_name => "#{task_name}:build"
end
