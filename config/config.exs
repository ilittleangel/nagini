import Config

config :logger, level: :debug

if File.exists?('config/secrets.exs') do
  import_config('secrets.exs')
else
  IO.puts('No secrets.exs found')
end
