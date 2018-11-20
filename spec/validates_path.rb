# coding: utf-8
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

RSpec.shared_examples "validates paths" do
  # Specifies that the given `path`, described by `description`, is allowed.
  def self.allows_a_path_that(description, path)
    it "allows a path that #{description}" do
      expect { constructor[path] }.not_to raise_error
    end
  end

  # Specifies that the given `path`, described by `description`, is not allowed.
  def self.forbids_a_path_that(description, path)
    it "forbids a path that #{description}" do
      expect { constructor[path] }.to raise_error(HRX::ParseError)
    end
  end

  allows_a_path_that "contains one component", "foo"
  allows_a_path_that "contains multiple components", "foo/bar/baz"
  allows_a_path_that "contains three dots", "..."
  allows_a_path_that "starts with a dot", ".foo"
  allows_a_path_that "contains non-alphanumeric characters", '~`!@#$%^&*()_-+= {}[]|;"\'<,>.?'
  allows_a_path_that "contains non-ASCII characters", "☃"

  forbids_a_path_that "is empty", ""
  forbids_a_path_that 'is "."', "."
  forbids_a_path_that 'is ".."', ".."
  forbids_a_path_that "is only a separator", "/"
  forbids_a_path_that "begins with a separator", "/foo"
  forbids_a_path_that "contains multiple separators in a row", "foo//bar"
  forbids_a_path_that "contains an invalid component", "foo/../bar"

  [*0x00..0x09, *0x0B..0x1F, 0x3A, 0x5C, 0x7F].each do |c|
    forbids_a_path_that "contains U+00#{c.to_s(16).rjust(2, "0")}", "fo#{c.chr}o"
  end
end
