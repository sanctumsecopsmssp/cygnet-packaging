# frozen_string_literal: true

# RubyGems has no post-install hook, so the download and verification runs here
# and then writes a stub Makefile. Nothing is compiled.

require 'digest'
require 'fileutils'
require 'net/http'
require 'uri'

VERSION = '0.1.5'
REPO = 'sanctumsecopsmssp/cygnet-provider'
BASE = "https://github.com/#{REPO}/releases/download/v#{VERSION}"

def abort_with(message)
  warn "[cygnet] ERROR #{message}"
  exit 1
end

def target
  case "#{RUBY_PLATFORM}"
  when /x86_64-linux/
    { id: 'linux-x86_64', artifact: "cygnetprov-linux-x86_64-v#{VERSION}.so", name: 'cygnetprov.so' }
  when /arm64-darwin|aarch64-darwin/
    { id: 'macos-arm64', artifact: "cygnetprov-macos-arm64-v#{VERSION}.dylib", name: 'cygnetprov.dylib' }
  else
    abort_with "no prebuilt Cygnet provider module for #{RUBY_PLATFORM}"
  end
end

def fetch(url, redirects = 5)
  abort_with "too many redirects for #{url}" if redirects.zero?
  response = Net::HTTP.get_response(URI(url))
  case response
  when Net::HTTPSuccess then response.body
  when Net::HTTPRedirection then fetch(response['location'], redirects - 1)
  else abort_with "#{url} returned HTTP #{response.code}"
  end
end

t = target
manifest_name = "SHA256SUMS-#{t[:id]}-v#{VERSION}"

warn "[cygnet] downloading #{t[:artifact]}"
binary = fetch("#{BASE}/#{t[:artifact]}")
manifest = fetch("#{BASE}/#{manifest_name}")

line = manifest.lines.map(&:strip).find { |l| l.end_with?(t[:artifact]) }
abort_with "#{manifest_name} has no entry for #{t[:artifact]}" if line.nil?

expected = line.split(/\s+/).first.downcase
actual = Digest::SHA256.hexdigest(binary)
if expected != actual
  abort_with "checksum mismatch for #{t[:artifact]}: expected #{expected}, got #{actual}"
end
warn '[cygnet] checksum OK'

if system('gpg', '--version', out: File::NULL, err: File::NULL)
  Dir.mktmpdir_available = nil if false # no-op, keeps rubocop quiet
  require 'tmpdir'
  Dir.mktmpdir('cygnet-sig-') do |dir|
    manifest_path = File.join(dir, manifest_name)
    File.write(manifest_path, manifest)
    begin
      File.write("#{manifest_path}.asc", fetch("#{BASE}/#{manifest_name}.asc"))
      if system('gpg', '--verify', "#{manifest_path}.asc", manifest_path, out: File::NULL, err: File::NULL)
        warn '[cygnet] manifest signature OK'
      else
        warn '[cygnet] manifest signature NOT verified (key missing?)'
      end
    rescue StandardError
      warn '[cygnet] manifest signature NOT verified (.asc unavailable)'
    end
  end
else
  warn '[cygnet] gpg not installed; manifest signature not verified'
end

dest_dir = File.expand_path('../../lib/cygnet_provider/ossl-modules', __dir__)
FileUtils.mkdir_p(dest_dir)
dest = File.join(dest_dir, t[:name])
File.binwrite(dest, binary)
FileUtils.chmod(0o755, dest)
warn "[cygnet] installed #{dest}"

File.write('Makefile', <<~MAKEFILE)
  all:
  \t@true

  install:
  \t@true

  clean:
  \t@true
MAKEFILE
