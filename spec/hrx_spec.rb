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

  context "#to_hrx" do
    it "writes a file's name and contents" do
      subject.entries << HRX::File.new("file", "contents\n")
      expect(subject.to_hrx).to be == <<END
<===> file
contents
END
    end

    it "adds a newline to a middle file with a newline" do
      subject.entries << HRX::File.new("file 1", "contents 1\n")
      subject.entries << HRX::File.new("file 2", "contents 2\n")
      expect(subject.to_hrx).to be == <<END
<===> file 1
contents 1

<===> file 2
contents 2
END
    end

    it "adds a newline to a middle file without a newline" do
      subject.entries << HRX::File.new("file 1", "contents 1")
      subject.entries << HRX::File.new("file 2", "contents 2\n")
      expect(subject.to_hrx).to be == <<END
<===> file 1
contents 1
<===> file 2
contents 2
END
    end

    it "writes empty files" do
      subject.entries << HRX::File.new("file 1", "")
      subject.entries << HRX::File.new("file 2", "")
      expect(subject.to_hrx).to be == <<END
<===> file 1
<===> file 2
END
    end

    it "doesn't add a newline to the last file" do
      subject.entries << HRX::File.new("file", "contents")
      expect(subject.to_hrx).to be == "<===> file\ncontents"
    end

    it "writes a directory" do
      subject.entries << HRX::Directory.new("dir")
      expect(subject.to_hrx).to be == "<===> dir/\n"
    end

    it "writes a comment on a file" do
      subject.entries << HRX::File.new("file", "contents\n", comment: "comment")
      expect(subject.to_hrx).to be == <<END
<===>
comment
<===> file
contents
END
    end

    it "writes a comment on a directory" do
      subject.entries << HRX::Directory.new("dir", comment: "comment")
      expect(subject.to_hrx).to be == <<END
<===>
comment
<===> dir/
END
    end

    it "uses a different boundary length to avoid conflicts" do
      subject.entries << HRX::File.new("file", "<===>\n")
      expect(subject.to_hrx).to be == <<END
<====> file
<===>
END
    end

    it "uses a different boundary length to avoid conflicts in comments" do
      subject.entries << HRX::File.new("file", "", comment: "<===>")
      expect(subject.to_hrx).to be == <<END
<====>
<===>
<====> file
END
    end

    it "uses a different boundary length to avoid multiple conflicts" do
      subject.entries << HRX::File.new("file", <<END)
<===>
<====> foo
<=====>
END
      expect(subject.to_hrx).to be == <<END
<======> file
<===>
<====> foo
<=====>
END
    end

    it "uses a different boundary length to avoid multiple conflicts in multiple files" do
      subject.entries << HRX::File.new("file 1", "<===>\n")
      subject.entries << HRX::File.new("file 2", "<====>\n")
      subject.entries << HRX::File.new("file 3", "<=====>\n")
      expect(subject.to_hrx).to be == <<END
<======> file 1
<===>

<======> file 2
<====>

<======> file 3
<=====>
END
    end

    context "with an explicit boundary length" do
      subject {HRX.new(boundary_length: 1)}

      it "uses it if possible" do
        subject.entries << HRX::File.new("file", "contents\n")
        expect(subject.to_hrx).to be == <<END
<=> file
contents
END
      end

      it "doesn't use it if it conflicts" do
        subject.entries << HRX::File.new("file", "<=>\n")
        expect(subject.to_hrx).to be == <<END
<==> file
<=>
END
      end
    end
  end
end
