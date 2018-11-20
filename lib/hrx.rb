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

require 'set'
require 'strscan'

require_relative 'hrx/file'
require_relative 'hrx/directory'
require_relative 'hrx/parse_error'

# An HRX archive.
class HRX
  class << self
    # Parses an HRX file's text.
    #
    # If `file` is passed, it's used as the file name for error reporting.
    def parse(text, file: nil)
      text = text.encode("UTF-8")
      return new if text.empty?

      scanner = StringScanner.new(text)
      unless boundary = scanner.scan(/<=+>/)
        HRX::Util.parse_error(scanner, "Expected boundary", file: file)
      end
      boundary_length = boundary.length - 2
      hrx = HRX.new(boundary_length: boundary_length)
      boundary_regexp = /^<={#{boundary_length}}>/m

      entries_by_path = {}
      loop do
        if scanner.scan(/\n/)
          if comment_plus_boundary = scanner.scan_until(boundary_regexp)
            comment = comment_plus_boundary[0...-boundary_length - 3]
          else
            hrx.last_comment = scanner.rest
            return hrx
          end
        end

        unless scanner.scan(/ /)
          HRX::Util.parse_error(scanner, "Expected space", file: file)
        end

        path = HRX::Util.scan_path(scanner, assert_done: false, file: file)
        unless scanner.scan(/\n/)
          HRX::Util.parse_error(scanner, "Expected newline", file: file)
        end

        if path.end_with?("/")
          error = hrx._add_entry HRX::Directory._new_without_checks(path, comment)
          HRX::Util.parse_error(scanner, error, file: file) if error

          return hrx if scanner.eos?
          next if scanner.scan(boundary_regexp)
          HRX::Util.parse_error(scanner, "Expected boundary", file: file)
        end

        if content_plus_boundary = scanner.scan_until(boundary_regexp)
          content = content_plus_boundary[0...-boundary_length - 3]
          error = hrx._add_entry HRX::File._new_without_checks(path, content, comment)
          HRX::Util.parse_error(scanner, error, file: file) if error
        else
          error = hrx._add_entry HRX::File._new_without_checks(path, scanner.rest, comment)
          HRX::Util.parse_error(scanner, error, file: file) if error
          return hrx
        end
      end
    end
  end

  # An array of the HRX::File and/or HRX::Directory objects that this archive
  # contains.
  #
  # This array can be mutated to adjust the contents of the archive.
  attr_reader :entries

  # The last comment in the document, or `nil` if it has no final comment.
  #
  # HRX comments are always encoded as UTF-8.
  attr_reader :last_comment

  # Creates a new, empty archive.
  #
  # The `boundary_length` is the number of `=` signs to include in the boundary
  # when #to_hrx is called, unless a file already contains that boundary.
  def initialize(boundary_length: 3)
    if boundary_length && boundary_length < 1
      raise ArgumentError.new("boundary_length must be 1 or greater")
    end

    @boundary_length = boundary_length
    @entries = []
    @entries_by_path = {}
  end

  # Sets the text of the last comment in the document.
  #
  # Throws an Encoding::UndefinedConversionError if `comment` can't be converted
  # to UTF-8.
  def last_comment=(comment)
    @last_comment = comment.encode("UTF-8")
  end

  # Returns this archive, serialized to text in HRX format.
  def to_hrx
    buffer = String.new.encode("UTF-8")
    boundary = "<#{"=" * _choose_boundary_length}>"

    entries.each_with_index do |e, i|
      buffer << boundary << "\n" << e.comment << "\n" if e.comment
      buffer << boundary << " " << e.path << "\n"
      if e.respond_to?(:content) && !e.content.empty?
        buffer << e.content
        buffer << "\n" unless i == entries.length - 1
      end
    end
    buffer << boundary << "\n" << last_comment << "\n" if last_comment

    buffer.freeze
  end

  # Adds `entry` to this archive.
  #
  # Returns an error message if the entry conflicts with an existing entry, or
  # `nil` otherwise.
  #
  # :nodoc:
  def _add_entry(entry)
    path = entry.path.split("/")
    path.pop if path.last.empty?

    parent = path[0...-1].inject(@entries_by_path) do |hash, component|
      return "\"#{hash[component].path}\" defined twice" if hash[component].is_a?(HRX::File)
      hash[component] ||= {}
    end

    return "\"#{entry.path}\" defined twice" if parent[path.last].is_a?(HRX::File)

    if entry.is_a?(HRX::Directory)
      dir = (parent[path.last] ||= {})
      return "\"#{entry.path}\" defined twice" if dir[:dir]
      dir[:dir] = entry
    else
      return "\"#{entry.path}\" defined twice" if parent.has_key?(path.last)
      parent[path.last] = entry
    end

    @entries << entry

    nil
  end

  private

  # Returns a boundary length for a serialized archive that doesn't conflict
  # with any of the files that archive contains.
  def _choose_boundary_length
    forbidden_boundary_lengths = Set.new
    entries.each do |e|
      [
        (e.content if e.respond_to?(:content)),
        e.comment
      ].each do |text|
        next unless text
        text.scan(/^<(=+)>/m).each do |(equals)|
          forbidden_boundary_lengths << equals.length
        end
      end
    end

    boundary_length = @boundary_length
    while forbidden_boundary_lengths.include?(boundary_length)
      boundary_length += 1
    end
    boundary_length
  end
end
