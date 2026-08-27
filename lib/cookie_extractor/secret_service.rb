require 'dbus'
require 'timeout'
require 'json'

module CookieExtractor
  class SecretService

    # https://specifications.freedesktop.org/secret-service/latest/
    SECRETS_SERVICE   = "org.freedesktop.secrets"
    SECRETS_PATH      = "/org/freedesktop/secrets"
    SERVICE_INTERFACE = "org.freedesktop.Secret.Service"
    PROMPT_INTERFACE  = "org.freedesktop.Secret.Prompt"

    class Error < RuntimeError; end
    class TimeoutError < Error; end

    def initialize(timeout: 60)
      @timeout = timeout
      @bus = DBus.session_bus
    end

    def secrets(attributes)
      Timeout.timeout(@timeout) do
        service = @bus.service(SECRETS_SERVICE).object(SECRETS_PATH)[SERVICE_INTERFACE]

        output, session_path = service.OpenSession("plain", []) # algorithm, input

        unlocked, locked = service.SearchItems(attributes)

        unless locked.empty?
          unlocked2, prompt_path = service.Unlock(locked)
          if prompt_path != "/"
            dismissed, unlocked3 = show_prompt(prompt_path, attributes)
            unlocked2 += unlocked3
          end
          unlocked += unlocked2
        end
        return [] if unlocked.empty?

        read_secrets = service.GetSecrets(unlocked, session_path).first

        return read_secrets.values.map { |secret| secret[2].pack("C*") }.uniq # session, parameters, [value], content_type
      end
    rescue DBus::Error
      raise Error.new("Failed to get secret from Secret Service!")
    rescue Timeout::Error
      raise TimeoutError.new("Timeout while waiting for Secret Service")
    end

    def show_prompt(prompt_path, attributes)
      prompt = @bus.service(SECRETS_SERVICE).object(prompt_path)[PROMPT_INTERFACE]
      prompt.Prompt("") # window-id
      wait_for_signal(prompt, "Completed")
    rescue Timeout::Error
      raise TimeoutError.new("Timeout while waiting for secret unlock => #{attributes.to_json}")
    end

    def wait_for_signal(interface, signal_name)
      main = DBus::Main.new
      main << @bus

      result = nil
      interface.on_signal(signal_name) do |*args|
        result = args
        main.quit
      end

      Timeout.timeout(@timeout / 2) { main.run }
      result
    end

  end
end
