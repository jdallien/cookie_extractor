require 'openssl'
require_relative 'secret_service'

module CookieExtractor

  # Reference:
  # * https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/os_crypt/async/browser/os_crypt_async.cc
  # * https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/os_crypt/async/common/encryptor.cc
  class ChromeCookieDecryptor

    def initialize(app: nil, secrets: [])
      app = :chrome unless app
      @providers = []
      @providers << V10KeyProvider.new(secrets: secrets)
      @providers << SecretKeyProvider.new(app, secrets: secrets)
      @providers << SecretPortalKeyProvider.new(app, secrets: secrets)
    end

    def decrypt(data, &block)
      @providers.each do |provider|
        value = provider.decrypt(data, &block)
        return value unless value.nil?
      end
      raise "Don't know how to decrypt '#{data.byteslice(0, 3)}'"
    end

    class KeyProvider
      SALT = 'saltysalt'.freeze
      ALGORITHM = 'AES-128-CBC'
      KEY_LENGTH = 16
      IV = ' ' * 16

      def initialize(secrets: [])
        @custom_secrets = secrets
      end

      def decrypt(data, &block)
        if data.start_with?(self.class::TAG)
          tag_length = self.class::TAG.length
          ciphertext = data.byteslice(tag_length, data.bytesize - tag_length)
          custom_keys.each do |key|
            value = decrypt_value(ciphertext, key)
            next if value.nil?
            next if block_given? && !yield(value)
            return value
          end
          keys.each do |key|
            value = decrypt_value(ciphertext, key)
            next if value.nil?
            next if block_given? && !yield(value)
            return value
          end
          raise "Failed to decrypt Chrome #{self.class::TAG} cookie!"
        else
          nil
        end
      end

      def decrypt_value(ciphertext, key)
        cipher = OpenSSL::Cipher.new(self.class::ALGORITHM)
        cipher.decrypt
        cipher.key = key
        cipher.iv = self.class::IV
        cipher.update(ciphertext) + cipher.final
      rescue OpenSSL::Cipher::CipherError
        # wrong key
      end

      def secret_key(secret)
        pbkdf2(secret, 1)
      end

      def custom_keys
        @custom_keys ||= @custom_secrets.map { |secret| secret_key(secret) }
      end

      def keys
        @keys ||= secrets.map { |secret| secret_key(secret) }
      end

      def secrets
        raise NotImplementedError.new("Unimplemented Chrome #{self.class.name.split('::').last} #{self.class::TAG}")
      end

      def pbkdf2(secret, iterations)
        OpenSSL::KDF.pbkdf2_hmac(secret, salt: SALT, iterations: iterations, length: KEY_LENGTH, hash: OpenSSL::Digest::SHA1.new)
      end

      def encrypt(plaintext, secret)
        self.class::TAG + encrypt_value(plaintext, secret_key(secret))
      end

      def encrypt_value(plaintext, key)
        cipher = OpenSSL::Cipher.new(self.class::ALGORITHM)
        cipher.encrypt
        cipher.key = key
        cipher.iv = self.class::IV
        cipher.update(plaintext) + cipher.final
      end
    end

    # https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/os_crypt/async/browser/posix_key_provider.cc
    class V10KeyProvider < KeyProvider
      TAG = "v10"
      def secrets
        ["peanuts"]
      end

      def encrypt(plaintext)
        super(plaintext, secrets.first)
      end
    end

    # https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/os_crypt/async/browser/freedesktop_secret_key_provider.cc
    class SecretKeyProvider < KeyProvider
      TAG = "v11"
      def initialize(app, secrets: [], secret_service: nil)
        super(secrets: secrets)
        @app = app
        @secret_service = secret_service
      end

      def secret_service
        @secret_service ||= SecretService.new
      end

      def secrets
        secrets = []
        items = [
          { "user" => key_name(@app) },  # KDE / KWallet
          { "application" => @app.to_s } # GNOME etc
        ]
        items.each do |attrs|
          secrets += secret_service.secrets(attrs)
        end
        raise "Failed to find secret #{items.flat_map.map(&:values).join(' / ')}" if secrets.empty?
        secrets
      end

      def key_name(app)
        case app.to_sym
        when :chrome
          "Chrome Safe Storage"
        when :chromium
          "Chromium Safe Storage"
        else
          # Fallback
          "Chromium Safe Storage"
        end
      end
    end

    # https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/os_crypt/async/browser/secret_portal_key_provider.cc
    class SecretPortalKeyProvider < KeyProvider
      TAG = "v12"
      def initialize(app, secrets: [])
        super(secrets: secrets)
        @app = app
      end

      def secrets
        # TODO
        super
      end
    end

  end
end
