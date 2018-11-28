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

require_relative 'error'

# An error caused by an HRX file failing to parse correctly.
class HRX::ParseError < HRX::Error
  # The 1-based line of the document on which the error occurred.
  attr_reader :line

  # The 1-based column of the line on which the error occurred.
  attr_reader :column

  # The file which failed to parse, or `nil` if the filename isn't known.
  attr_reader :file

  def initialize(message, line, column, file: nil)
    super(message)
    @line = line
    @column = column
    @file = file
  end

  def to_s
    buffer = String.new("Parse error on line #{line}, column #{column}")
    buffer << " of #{file}" if file
    buffer << ": #{super.to_s}"
  end
end
