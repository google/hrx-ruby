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

RSpec.describe HRX, ".parse" do
  it "parses an empty file" do
    expect(HRX::Archive.parse("").entries).to be_empty
  end

  it "converts the file to UTF-8" do
    hrx = HRX::Archive.parse("<===> いか\n".encode("SJIS"))
    expect(hrx.entries.first.path).to be == "いか"
  end

  it "requires the file to be convetible to UTF-8" do
    expect do
      HRX::Archive.parse("<===> \xc3\x28\n".b)
    end.to raise_error(EncodingError)
  end

  context "with a single file" do
    subject {HRX::Archive.parse(<<END)}
<===> file
contents
END

    it "parses one entry" do
      expect(subject.entries.length).to be == 1
    end

    it "parses the filename" do
      expect(subject.entries.first.path).to be == "file"
    end

    it "parses the contents" do
      expect(subject.entries.first.content).to be == "contents\n"
    end

    it "parses contents without a newline" do
      hrx = HRX::Archive.parse("<===> file\ncontents")
      expect(hrx.entries.first.content).to be == "contents"
    end

    it "parses contents with boundary-like sequences" do
      hrx = HRX::Archive.parse(<<END)
<===> file
<==>
inline <===>
<====>
END
      expect(hrx.entries.first.content).to be == <<END
<==>
inline <===>
<====>
END
    end

    context "with a comment" do
      subject {HRX::Archive.parse(<<END)}
<===>
comment
<===> file
contents
END

      it "parses one entry" do
        expect(subject.entries.length).to be == 1
      end

      it "parses the filename" do
        expect(subject.entries.first.path).to be == "file"
      end

      it "parses the contents" do
        expect(subject.entries.first.content).to be == "contents\n"
      end

      it "parses the comment" do
        expect(subject.entries.first.comment).to be == "comment"
      end
    end
  end

  context "with multiple files" do
    subject {HRX::Archive.parse(<<END)}
<===> file 1
contents 1

<===> file 2
contents 2
END

    it "parses two entries" do
      expect(subject.entries.length).to be == 2
    end

    it "parses the first filename" do
      expect(subject.entries.first.path).to be == "file 1"
    end

    it "parses the first contents" do
      expect(subject.entries.first.content).to be == "contents 1\n"
    end

    it "parses the second filename" do
      expect(subject.entries.last.path).to be == "file 2"
    end

    it "parses the second contents" do
      expect(subject.entries.last.content).to be == "contents 2\n"
    end

    it "allows an explicit parent directory" do
      hrx = HRX::Archive.parse(<<END)
<===> dir/
<===> dir/file
contents
END

      expect(hrx.entries.last.content).to be == "contents\n"
    end

    it "parses contents without a newline" do
      hrx = HRX::Archive.parse(<<END)
<===> file 1
contents 1
<===> file 2
contents 2
END
      expect(hrx.entries.first.content).to be == "contents 1"
    end

    it "parses contents with boundary-like sequences" do
      hrx = HRX::Archive.parse(<<END)
<===> file 1
<==>
inline <===>
<====>

<===> file 2
contents
END
      expect(hrx.entries.first.content).to be == <<END
<==>
inline <===>
<====>
END
    end

    context "with a comment" do
      subject {HRX::Archive.parse(<<END)}
<===> file 1
contents 1

<===>
comment
<===> file 2
contents 2
END

      it "parses two entries" do
        expect(subject.entries.length).to be == 2
      end

      it "parses the first filename" do
        expect(subject.entries.first.path).to be == "file 1"
      end

      it "parses the first contents" do
        expect(subject.entries.first.content).to be == "contents 1\n"
      end

      it "parses the second filename" do
        expect(subject.entries.last.path).to be == "file 2"
      end

      it "parses the second contents" do
        expect(subject.entries.last.content).to be == "contents 2\n"
      end

      it "parses the comment" do
        expect(subject.entries.last.comment).to be == "comment"
      end
    end
  end

  it "parses a file that only contains a comment" do
    expect(HRX::Archive.parse(<<END).last_comment).to be == "contents\n"
<===>
contents
END
  end

  it "parses a file that only contains a comment with boundary-like sequences" do
    expect(HRX::Archive.parse(<<HRX).last_comment).to be == <<CONTENTS
<===>
<==>
inline <===>
<====>
HRX
<==>
inline <===>
<====>
CONTENTS
  end

  context "with a file and a trailing comment" do
    subject {HRX::Archive.parse(<<END)}
<===> file
contents

<===>
comment
END

    it "parses one entry" do
      expect(subject.entries.length).to be == 1
    end

    it "parses the filename" do
      expect(subject.entries.first.path).to be == "file"
    end

    it "parses the contents" do
      expect(subject.entries.first.content).to be == "contents\n"
    end

    it "parses the trailing comment" do
      expect(subject.last_comment).to be == "comment\n"
    end
  end

  context "with a single directory" do
    subject {HRX::Archive.parse("<===> dir/\n")}

    it "parses one entry" do
      expect(subject.entries.length).to be == 1
    end

    it "parses a directory" do
      expect(subject.entries.first).to be_a(HRX::Directory)
    end

    it "parses the filename" do
      expect(subject.entries.first.path).to be == "dir/"
    end
  end

  it "serializes in source order" do
    hrx = HRX::Archive.parse(<<END)
<===> foo
<===> dir/bar
<===> baz
<===> dir/qux
END

    expect(hrx.to_hrx).to be == <<END
<===> foo
<===> dir/bar
<===> baz
<===> dir/qux
END
  end

  it "serializes with the source boundary" do
    hrx = HRX::Archive.parse("<=> file\n")
    expect(hrx.to_hrx).to be == "<=> file\n"
  end

  let(:constructor) {lambda {|path| HRX::Archive.parse("<===> #{path}\n")}}
  include_examples "validates paths"

  context "forbids an HRX file that" do
    # Specifies that the given HRX archive, with the given human-readable
    # description, can't be parsed.
    def self.that(description, text, message)
      it description do
        expect {HRX::Archive.parse(text)}.to raise_error(HRX::ParseError, message)
      end
    end

    that "doesn't start with a boundary", "file\n", /Expected boundary/
    that "starts with an unclosed boundary", "<== file\n", /Expected boundary/
    that "starts with an unopened boundary", "==> file\n", /Expected boundary/
    that "starts with a malformed boundary", "<> file\n", /Expected boundary/
    that "has a directory with contents", "<===> dir/\ncontents", /Expected boundary/

    that "has duplicate files", "<=> file\n<=> file\n", /"file" defined twice/
    that "has duplicate directories", "<=> dir/\n<=> dir/\n", %r{"dir/" defined twice}
    that "has file with the same name as a directory", "<=> foo/\n<=> foo\n", /"foo" defined twice/
    that "has file with the same name as an earlier implicit directory", "<=> foo/bar\n<=> foo\n", /"foo" defined twice/
    that "has file with the same name as a later implicit directory", "<=> foo\n<=> foo/bar\n", /"foo" defined twice/

    context "has a boundary that" do
      that "isn't followed by a space", "<=>file\n", /Expected space/
      that "isn't followed by a path", "<=> \n", /Expected a path/
      that "has a file without a newline", "<=> file", /Expected newline/
    end

    context "has a middle boundary that" do
      that "isn't followed by a space", "<=> file 1\n<=>file 2\n", /Expected space/
      that "isn't followed by a path", "<=> file 1\n<=> \n", /Expected a path/
      that "has a file without a newline", "<=> file 1\n<=> file", /Expected newline/
    end

    context "has multiple comments that" do
      that "come before a file", <<END, /Expected space/
<=>
comment 1
<=>
comment 2
<=> file
END

      that "come after a file", <<END, /Expected space/
<=> file
<=>
comment 1
<=>
comment 2
END

      that "appear on their own", <<END, /Expected space/
<=>
comment 1
<=>
comment 2
END
    end
  end
end
