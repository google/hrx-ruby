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

require 'hrx'

RSpec.describe HRX do
  subject {HRX.new}

  context "when first initialized" do
    it "has no entries" do
      expect(subject.entries).to be_empty
    end

    it "can have new entries added" do
      file = HRX::File.new("file", "contents")
      subject.entries << file
      expect(subject.entries).to be == [file]
    end
  end

  context "#initialize" do
    it "should forbid boundary_length 0" do
      expect {HRX.new(boundary_length: 0)}.to raise_error(ArgumentError)
    end

    it "should forbid negative boundary_length" do
      expect {HRX.new(boundary_length: -1)}.to raise_error(ArgumentError)
    end
  end

  context "#last_comment=" do
    it "requires the comment to be convertible to UTF-8" do
      expect do
        subject.last_comment = "\xc3\x28".b
      end.to raise_error(Encoding::UndefinedConversionError)
    end

    it "converts a comment to UTF-8" do
      subject.last_comment = "いか".encode("SJIS")
      expect(subject.last_comment).to be == "いか"
    end
  end
end
