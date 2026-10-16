require "erb"
require "fileutils"

COMPONENTS = {
  "TcpInput" => {
    module_name: "Proxy.Transport.TcpInput",
    function_name: "tcpInput",
    package: "stm-markov-proxy"
  },
  "UnixSocketOutput" => {
    module_name: "Proxy.Transport.UnixSocketOutput",
    function_name: "unixSocketOutput",
    package: "stm-markov-proxy"
  }
}.freeze

PROXY = {
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
}.freeze

GENERATED_DIRECTORY = "generated/raw-tcp-proxy".freeze

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

namespace :raw_tcp_proxy do
  desc "Generate the raw TCP to Unix-socket proxy"
  task :generate do
    input = COMPONENTS.fetch(PROXY.fetch(:input).fetch(:component))
    output = COMPONENTS.fetch(PROXY.fetch(:output).fetch(:component))

    values = PROXY.merge(
      imports: [input, output],
      input_call: component_call(input, PROXY.fetch(:input).fetch(:args)),
      output_call: component_call(output, PROXY.fetch(:output).fetch(:args)),
      dependencies: ["base ^>=4.18.3.0", input.fetch(:package), output.fetch(:package)].uniq
    )

    render(
      "templates/raw-tcp-proxy/Main.hs.erb",
      "#{GENERATED_DIRECTORY}/app/Main.hs",
      values
    )
    render(
      "templates/raw-tcp-proxy/package.cabal.erb",
      "#{GENERATED_DIRECTORY}/#{PROXY.fetch(:package_name)}.cabal",
      values
    )

    File.write(
      "#{GENERATED_DIRECTORY}/cabal.project",
      "packages:\n  .\n  #{GENERATED_DIRECTORY}\n"
    )

    puts "Generated #{PROXY.fetch(:name)} with #{PROXY.fetch(:composition)} composition"
  end

  desc "Build the generated raw TCP proxy"
  task build: :generate do
    sh(
      "cabal",
      "build",
      "--project-file=#{GENERATED_DIRECTORY}/cabal.project",
      "#{PROXY.fetch(:package_name)}:exe:#{PROXY.fetch(:name)}"
    )
  end
end

desc "Generate and build the specialized raw TCP proxy"
task raw_tcp_proxy: "raw_tcp_proxy:build"
