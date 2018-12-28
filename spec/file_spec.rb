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

require_relative 'validates_path'

RSpec.describe HRX::File, "#initialize" do
  let(:constructor) {lambda {|path| HRX::File.new(path, "")}}
  include_examples "validates paths"

  it "requires the path to be convertible to UTF-8" do
    expect do
      HRX::File.new("\xc3\x28".b, "")
    end.to raise_error(EncodingError)
  end

  it "requires the path to be valid UTF-8" do
    expect do
      HRX::File.new("\xc3\x28", "")
    end.to raise_error(EncodingError)
  end

  it "requires the content to be convertible to UTF-8" do
    expect do
      HRX::File.new("file", "\xc3\x28".b)
    end.to raise_error(EncodingError)
  end

  it "requires the content to be valid UTF-8" do
    expect do
      HRX::File.new("file", "\xc3\x28")
    end.to raise_error(EncodingError)
  end

  it "requires the comment to be convertible to UTF-8" do
    expect do
      HRX::File.new("file", "", comment: "\xc3\x28".b)
    end.to raise_error(EncodingError)
  end

  it "requires the comment to be valid UTF-8" do
    expect do
      HRX::File.new("file", "", comment: "\xc3\x28")
    end.to raise_error(EncodingError)
  end

  it "forbids a path with a trailing slash" do
    expect {HRX::File.new("file/", "")}.to raise_error(HRX::ParseError)
  end

  it "forbids a path with a newline" do
    expect {HRX::File.new("fi\nle", "")}.to raise_error(HRX::ParseError)
  end

  context "with arguments that are convertible to UTF-8" do
    subject do
      ika = "いか".encode("SJIS")
      HRX::File.new(ika, ika, comment: ika)
    end

    it("converts #path") {expect(subject.path).to be == "いか"}
    it("converts #content") {expect(subject.content).to be == "いか"}
    it("converts #comment") {expect(subject.comment).to be == "いか"}
  end
end
