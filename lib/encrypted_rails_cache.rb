require 'openssl'
require 'json'

module ActiveSupport
  module Cache
    class RedisCacheStore
      def deserialize_entry(serialized_entry)
        return unless serialized_entry

        data = ::JSON.parse(serialized_entry)

        decode_cipher = OpenSSL::Cipher.new('AES-256-CBC')
        decode_cipher.decrypt
        decode_cipher.key = [Rails.application.secrets.cache_key].pack('H*')
        decode_cipher.iv = Base64.decode64(data['iv'])

        plain = decode_cipher.update(Base64.decode64(data['data']))
        plain = plain + decode_cipher.final

        entry = Marshal.load(plain) rescue serialized_entry
        entry.is_a?(Entry) ? entry : Entry.new(entry)
      end

      def serialize_entry(entry, raw: false)
        blob = if raw
          entry.value.to_s
        else
          Marshal.dump(entry)
        end

        aes = OpenSSL::Cipher.new('AES-256-CBC')
        iv = aes.random_iv
        aes.encrypt
        aes.iv = iv
        aes.key = [Rails.application.secrets.cache_key].pack('H*')

        cipher = aes.update(blob)
        cipher = cipher + aes.final

        data = {
          data: Base64.encode64(cipher),
          iv: Base64.encode64(iv)
        }

        data.to_json
      end
    end
  end
end
