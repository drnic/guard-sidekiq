require 'guard'
require 'guard/guard'

module Guard
  class Sidekiq < Guard

    DEFAULT_SIGNAL = :QUIT
    DEFAULT_QUEUE = '*'.freeze
    DEFAULT_CONCURRENCY = 1

    # Allowable options are:
    #  - :environment  e.g. 'test'
    #  - :queue e.g. '*'
    #  - :timeout e.g. 5
    #  - :concurrency, e.g. 20
    #  - :verbose e.g. true
    #  - :stop_signal e.g. :QUIT or :SIGQUIT
    def initialize(watchers = [], options = {})
      @options = options
      @pid = nil
      @stop_signal = options[:stop_signal] || DEFAULT_SIGNAL
      @options[:queue] ||= DEFAULT_QUEUE
      @options[:concurrency] ||= DEFAULT_CONCURRENCY
      @options[:verbose] = @options.fetch(:verbose, true)
      super
    end

    def start
      stop
      UI.info 'Starting up sidekiq...'
      UI.info [ cmd, env.map{|v| v.join('=')} ].join(' ')

      # launch Sidekiq worker
      @pid = spawn(env, cmd)
    end

    def stop
      if @pid
        UI.info 'Stopping sidekiq...'
        ::Process.kill @stop_signal, @pid
        begin
          Timeout.timeout(15) do
            ::Process.wait @pid
          end
        rescue Timeout::Error
          UI.info 'Sending SIGKILL to sidekiq, as it\'s taking too long to shutdown.'
          ::Process.kill :KILL, @pid
          ::Process.wait @pid
        end
        UI.info 'Stopped process sidekiq'
      end
    rescue Errno::ESRCH
      UI.info 'Guard::Sidekiq lost the Sidekiq worker subprocess!'
    ensure
      @pid = nil
    end

    # Called on Ctrl-Z signal
    def reload
      UI.info 'Restarting sidekiq...'
      restart
    end

    # Called on Ctrl-/ signal
    def run_all
      true
    end

    # Called on file(s) modifications
    def run_on_change(paths)
      restart
    end

    def restart
      stop
      start
    end

    private

    def cmd
      command = ['bundle exec sidekiq']

      # trace setting
      command << "--queue #{@options[:queue]}"
      command << "--verbose" if @options[:verbose]
      command << "--environment #{@options[:environment]}"  if @options[:environment]
      command << "--timeout #{@options[:timeout]}"          if @options[:timeout]
      command << "--concurrency #{@options[:concurrency]}"

      command.join(' ')
    end

  end
end