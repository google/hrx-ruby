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

require_relative 'parse_error'

module HRX::Util # :nodoc:
  class << self
    # Returns `string` as a valid and UTF-8 encoded if possible, or throws an
    # error otherwise.
    #
    # Returns `nil` for `nil`.
    def sanitize_encoding(string)
      return if string.nil?

      string = string.encode("UTF-8")
      return string if string.valid_encoding?

      # If the string isn't valid UTF-8, re-encode it so it throws a useful
      # error message.
      string.b.encode("UTF-8")
    end

    # Scans a single HRX path from `scanner` and returns it.
    #
    # Throws an ArgumentError if no valid path is available to scan. If
    # `assert_done` is `true`, throws an ArgumentError if there's any text after
    # the path.
    def scan_path(scanner, assert_done: true, file: nil)
      start = scanner.pos
      while _scan_component(scanner, file) && scanner.scan(%r{/}); end

      if assert_done && !scanner.eos?
        parse_error(scanner, "Paths may not contain newlines", file: file)
      elsif scanner.pos == start
        parse_error(scanner, "Expected a path", file: file)
      end

      scanner.string.byteslice(start...scanner.pos)
    end

    # Emits an ArgumentError with the given `message` and line and column
    # information from the current position of `scanner`.
    def parse_error(scanner, message, file: nil)
      before = scanner.string.byteslice(0...scanner.pos)
      line = before.count("\n") + 1
      column = (before[/^.*\z/] || "").length + 1

      raise HRX::ParseError.new(message, line, column, file: file)
    end

    # Returns `child` relative to `parent`.
    #
    # Assumes `parent` ends with `/`, and `child` is beneath `parent`.
    #
    # If `parent` is `nil`, returns `child` as-is.
    def relative(parent, child)
      return child unless parent
      child[parent.length..-1]
    end

    private

    # Scans a single HRX path component from `scanner`.
    #
    # Returns whether or not a component could be found, or throws an
    # HRX::ParseError if an invalid component was encountered.
    def _scan_component(scanner, file)
      return unless component = scanner.scan(%r{[^\u0000-\u001F\u007F/:\\]+})
      if component == "." || component == ".."
        scanner.unscan
        parse_error(scanner, "Invalid path component \"#{component}\"", file: file)
      end

      if char = scanner.scan(/[\u0000-\u0009\u000B-\u001F\u007F]/)
        scanner.unscan
        parse_error(scanner, "Invalid character U+00#{char.ord.to_s(16).rjust(2, "0").upcase}", file: file)
      elsif char = scanner.scan(/[\\:]/)
        scanner.unscan
        parse_error(scanner, "Invalid character \"#{char}\"", file: file)
      end

      true
    end
  end
end
