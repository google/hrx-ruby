# Copyright 2018 Google Inc
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

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
  s.executables << "hrx"

  s.add_runtime_dependency "linked-list", "~> 0.0.13"
  s.add_runtime_dependency "thor", "~> 0.20"
  s.required_ruby_version = ">= 2.3.0"
end
