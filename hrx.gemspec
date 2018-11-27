Gem::Specification.new do |s|
  s.name = "hrx"
  s.version = "1.0.0"
  s.license = "Apache-2.0"

  s.homepage = "https://github.com/google/hrx-ruby"
  s.summary = "An HRX parser and serializer"
  s.description = "A parser and serializer for the HRX human-readable archive format."
  s.authors = ["Natalie Weizenbaum"]
  s.email = "nweiz@google.com"

  s.files = `git ls-files -z`.split("\x0")

  # Depend on this exact version because we're relying on its private API until
  # spectator/linked-list#5 is fixed.
  s.add_runtime_dependency "linked-list", "0.0.12"

  s.required_ruby_version = ">= 2.3.0"
end
