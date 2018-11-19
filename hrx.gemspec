Gem::Specification.new do
  s.name = "hrx"
  s.version = "1.0.0"
  s.license = "Apache-2.0"

  s.homepage = "https://github.com/google/hrx-ruby"
  s.summary = "An HRX parser and serializer"
  s.description = "A parser and serializer for the HRX human-readable archive format."
  s.authors = ["Natalie Weizenbaum"]
  s.email = "nweiz@google.com"

  s.files = `git ls-files -z`.split("\x0")

  s.required_ruby_version = ">= 2.0.0"
end
