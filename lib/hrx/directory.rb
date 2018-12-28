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

# A directory in an HRX archive.
class HRX::Directory
  # The comment that appeared before this directory, or `nil` if it had no
  # preceding comment.
  #
  # HRX file contents are always encoded as UTF-8.
  #
  # This string is frozen.
  attr_reader :comment

  # The path to this file, relative to the archive's root, including the
  # trailing `/`.
  #
  # HRX paths are always `/`-separated and always encoded as UTF-8.
  #
  # This string is frozen.
  attr_reader :path

  # Creates a new file with the given paths and comment.
  #
  # Throws an HRX::ParseError if `path` is invalid, or an EncodingError if
  # either argument can't be converted to UTF-8.
  #
  # The `path` may or may not end with a `/`. If it doesn't a `/` will be added.
  def initialize(path, comment: nil)
    @comment = HRX::Util.sanitize_encoding(comment&.clone)&.freeze
    @path = HRX::Util.scan_path(StringScanner.new(HRX::Util.sanitize_encoding(path)))
    @path << "/" unless @path.end_with?("/")
    @path.freeze
  end

  # Like ::new, but doesn't verify that the arguments are valid.
  def self._new_without_checks(path, comment) # :nodoc:
    allocate.tap do |dir|
      dir._initialize_without_checks(path, comment)
    end
  end

  # Like #initialize, but doesn't verify that the arguments are valid.
  def _initialize_without_checks(path, comment) # :nodoc:
    @comment = comment.freeze
    @path = path.freeze
  end

  # Returns a copy of this entry with the path modified to be relative to
  # `root`.
  #
  # If `root` is `nil`, returns this as-is.
  def _relative(root) # :nodoc:
    return self unless root
    HRX::Directory._new_without_checks(HRX::Util.relative(root, path), comment)
  end

  # Returns a copy of this entry with `root` added tothe beginning of the path.
  #
  # If `root` is `nil`, returns this as-is.
  def _absolute(root) # :nodoc:
    return self unless root
    HRX::Directory._new_without_checks(root + path, comment)
  end
end
