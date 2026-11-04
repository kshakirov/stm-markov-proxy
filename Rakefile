require "erb"
require "fileutils"
require "json"
require "open3"

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

PROXIES = Dir["scenarios/*.json"].sort.to_h do |path|
  proxy = JSON.parse(File.read(path), symbolize_names: true)
  unless proxy.fetch(:name).match?(/\A[a-z][a-z0-9-]*\z/)
    raise ArgumentError, "Invalid executable name in #{path}"
  end
  [File.basename(path, ".json").to_sym, proxy]
end.freeze

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
  if proxy.fetch(:composition) == "duplex_iteration"
    unless proxy.fetch(:input).fetch(:component) == "TcpInput" &&
           proxy.fetch(:output).fetch(:component) == "UnixSocketOutput"
      raise ArgumentError, "duplex_iteration requires TcpInput and UnixSocketOutput"
    end
    values = proxy.merge(
      host_literal: haskell_literal(proxy.fetch(:host)),
      socket_path_literal: haskell_literal(proxy.fetch(:socket_path)),
      dependencies: ["base ^>=4.18.3.0", "async >= 2.2 && < 2.3", "stm-markov-proxy"]
    )
    main_template = "templates/duplex-proxy/Main.hs.erb"
  else
    raise ArgumentError, "Unsupported composition" unless proxy.fetch(:composition) == "kleisli"
    input = COMPONENTS.fetch(proxy.fetch(:input).fetch(:component))
    output = COMPONENTS.fetch(proxy.fetch(:output).fetch(:component))

    values = proxy.merge(
      imports: [input, output],
      input_call: component_call(input, proxy.fetch(:input).fetch(:args)),
      output_call: component_call(output, proxy.fetch(:output).fetch(:args)),
      dependencies: ["base ^>=4.18.3.0", input.fetch(:package), output.fetch(:package)].uniq
    )
    main_template = "templates/raw-tcp-proxy/Main.hs.erb"
  end

  render(
    main_template,
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
      binary, status = Open3.capture2(
        "cabal", "list-bin",
        "--project-file=#{generated_directory}/cabal.project",
        "#{proxy.fetch(:package_name)}:exe:#{proxy.fetch(:name)}"
      )
      raise "Cannot locate compiled binary" unless status.success?

      FileUtils.mkdir_p("bin")
      destination = "bin/#{proxy.fetch(:name)}"
      FileUtils.cp(binary.strip, destination, preserve: true)
      puts "Binary: #{destination}"
    end
  end

  desc "Generate and build #{proxy.fetch(:name)}"
  task task_name => "#{task_name}:build"
end

desc "Build a scenario: rake 'build[mzls_proxy]'"
task :build, [:scenario] do |_, args|
  scenario = args[:scenario].to_s.to_sym
  raise ArgumentError, "Unknown scenario: #{args[:scenario]}" unless PROXIES.key?(scenario)

  Rake::Task["#{scenario}:build"].invoke
end
