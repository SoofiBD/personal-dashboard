require "openssl"

class Totp
  ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".freeze
  STEP = 30
  DIGITS = 6
  CODE_PATTERN = /\A\d{6}\z/

  def self.generate_secret(length: 32)
    Array.new(length) { ALPHABET[SecureRandom.random_number(ALPHABET.length)] }.join
  end

  def self.valid?(secret, code, at: Time.current)
    return false unless secret.present? && code.to_s.match?(CODE_PATTERN)

    (-1..1).any? { |offset| ActiveSupport::SecurityUtils.secure_compare(code_for(secret, at: at + offset * STEP), code.to_s) }
  end

  def self.code_for(secret, at: Time.current)
    counter = (at.to_i / STEP)
    digest = OpenSSL::HMAC.digest("SHA1", decode(secret), [counter].pack("Q>"))
    offset = digest.getbyte(-1) & 0x0f
    binary = digest.byteslice(offset, 4).unpack1("N") & 0x7fff_ffff
    format("%0#{DIGITS}d", binary % (10**DIGITS))
  end

  def self.provisioning_uri(account_name:, issuer:, secret:)
    label = ERB::Util.url_encode("#{issuer}:#{account_name}")
    "otpauth://totp/#{label}?secret=#{secret}&issuer=#{ERB::Util.url_encode(issuer)}&algorithm=SHA1&digits=#{DIGITS}&period=#{STEP}"
  end

  def self.decode(secret)
    values = secret.upcase.delete(" ").chars.map { |character| ALPHABET.index(character) }
    raise ArgumentError, "Invalid Base32 secret" if values.any?(&:nil?)

    bits = values.map { |value| value.to_s(2).rjust(5, "0") }.join

    bits.scan(/.{8}/).map { |chunk| chunk.to_i(2).chr }.join
  end
  private_class_method :decode
end
