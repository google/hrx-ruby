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

require_relative 'util'

# A file in an HRX archive.
class HRX::File
  # The comment that appeared before this file, or `nil` if it had no
  # preceding comment.
  #
  # HRX comments are always encoded as UTF-8.
  #
  # This string is frozen.
  attr_reader :comment

  # The path to this file, relative to the archive's root.
  #
  # HRX paths are always `/`-separated and always encoded as UTF-8.
  #
  # This string is frozen.
  attr_reader :path

  # The contents of the file.
  #
  # HRX file contents are always encoded as UTF-8.
  #
  # This string is frozen.
  attr_reader :content

  # Creates a new file with the given path, content, and comment.
  #
  # Throws an HRX::ParseError if `path` is invalid, or an EncodingError if any
  # argument can't be converted to UTF-8.
  def initialize(path, content, comment: nil)
    @comment = HRX::Util.sanitize_encoding(comment&.clone)&.freeze
    @path = HRX::Util.scan_path(StringScanner.new(HRX::Util.sanitize_encoding(path))).freeze

    if @path.end_with?("/")
      raise HRX::ParseError.new("path \"#{path}\" may not end with \"/\"", 1, path.length - 1)
    end

    @content = HRX::Util.sanitize_encoding(content.clone).freeze
  end

  # Like ::new, but doesn't verify that the arguments are valid.
  def self._new_without_checks(path, content, comment) # :nodoc:
    allocate.tap do |file|
      file._initialize_without_checks(path, content, comment)
    end
  end

  # Like #initialize, but doesn't verify that the arguments are valid.
  def _initialize_without_checks(path, content, comment) # :nodoc:
    @comment = comment.freeze
    @path = path.freeze
    @content = content.freeze
  end

  # Returns a copy of this entry with the path modified to be relative to
  # `root`.
  #
  # If `root` is `nil`, returns this as-is.
  def _relative(root) # :nodoc:
    return self unless root
    HRX::File._new_without_checks(HRX::Util.relative(root, path), content, comment)
  end

  # Returns a copy of this entry with `root` added tothe beginning of the path.
  #
  # If `root` is `nil`, returns this as-is.
  def _absolute(root) # :nodoc:
    return self unless root
    HRX::File._new_without_checks(root + path, content, comment)
  end
end
