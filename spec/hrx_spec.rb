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
  end

  context "#initialize" do
    it "should forbid boundary_length 0" do
      expect {HRX.new(boundary_length: 0)}.to raise_error(ArgumentError)
    end

    it "should forbid negative boundary_length" do
      expect {HRX.new(boundary_length: -1)}.to raise_error(ArgumentError)
    end
  end

  context "#entries" do
    it "is frozen" do
      expect do
        subject.entries << HRX::Directory.new("dir")
      end.to raise_error(RuntimeError)
    end

    it "reflects new entries" do
      expect(subject.entries).to be_empty
      dir = HRX::Directory.new("dir")
      subject << dir
      expect(subject.entries).to be == [dir]
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

  context "with files and directories in the archive" do
    subject {HRX.parse(<<END)}
<===> file
file contents

<===> dir/
<===> super/sub
sub contents
END

    context "#[]" do
      it "doesn't return an empty path" do
        expect(subject[""]).to be_nil
      end

      it "doesn't return a path that's not in the archive" do
        expect(subject["non/existent/file"]).to be_nil
      end

      it "doesn't return an implicit directory" do
        expect(subject["super"]).to be_nil
      end

      it "doesn't return a file wih a slash" do
        expect(subject["super/sub/"]).to be_nil
      end

      it "returns a file at the root level" do
        expect(subject["file"].content).to be == "file contents\n"
      end

      it "returns a file in a directory" do
        expect(subject["super/sub"].content).to be == "sub contents\n"
      end

      it "returns an explicit directory" do
        expect(subject["dir"].path).to be == "dir/"
      end

      it "returns an explicit directory with a leading slash" do
        expect(subject["dir/"].path).to be == "dir/"
      end
    end

    context "#add" do
      it "adds a file to the end of the archive" do
        file = HRX::File.new("other", "")
        subject << file
        expect(subject.entries.last).to be == file
      end

      it "adds a file in an existing directory to the end of the archive" do
        file = HRX::File.new("dir/other", "")
        subject << file
        expect(subject.entries.last).to be == file
      end

      it "allows an implicit directory to be made explicit" do
        dir = HRX::Directory.new("super")
        subject << dir
        expect(subject.entries.last).to be == dir
      end

      it "throws an error for a duplicate file" do
        expect do
          subject << HRX::File.new("file", "")
        end.to raise_error(HRX::Error, '"file" defined twice')
      end

      it "throws an error for a duplicate directory" do
        expect do
          subject << HRX::Directory.new("dir")
        end.to raise_error(HRX::Error, '"dir/" defined twice')
      end

      it "throws an error for a file with a directory's name" do
        expect do
          subject << HRX::File.new("dir", "")
        end.to raise_error(HRX::Error, '"dir" defined twice')
      end

      it "throws an error for a file with an implicit directory's name" do
        expect do
          subject << HRX::File.new("super", "")
        end.to raise_error(HRX::Error, '"super" defined twice')
      end

      it "throws an error for a directory with a file's name" do
        expect do
          subject << HRX::Directory.new("file")
        end.to raise_error(HRX::Error, '"file/" defined twice')
      end

      context "with :before" do
        it "adds the new entry before the given file" do
          subject.add HRX::File.new("other", ""), before: "super/sub"
          expect(subject.entries[2].path).to be == "other"
        end

        it "adds the new entry before the given directory" do
          subject.add HRX::File.new("other", ""), before: "dir/"
          expect(subject.entries[1].path).to be == "other"
        end

        it "adds the new entry before the given directory without a /" do
          subject.add HRX::File.new("other", ""), before: "dir"
          expect(subject.entries[1].path).to be == "other"
        end

        it "fails if the path can't be found" do
          expect do
            subject.add HRX::File.new("other", ""), before: "asdf"
          end.to raise_error(HRX::Error, 'There is no entry named "asdf"')
        end

        it "fails if the path is an implicit directory" do
          expect do
            subject.add HRX::File.new("other", ""), before: "super"
          end.to raise_error(HRX::Error, 'There is no entry named "super"')
        end

        it "fails if a trailing slash is used for a file" do
          expect do
            subject.add HRX::File.new("other", ""), before: "file/"
          end.to raise_error(HRX::Error, 'There is no entry named "file/"')
        end
      end

      context "with :after" do
        it "adds the new entry after the given file" do
          subject.add HRX::File.new("other", ""), after: "super/sub"
          expect(subject.entries[3].path).to be == "other"
        end

        it "adds the new entry after the given directory" do
          subject.add HRX::File.new("other", ""), after: "dir/"
          expect(subject.entries[2].path).to be == "other"
        end

        it "adds the new entry after the given directory without a /" do
          subject.add HRX::File.new("other", ""), after: "dir"
          expect(subject.entries[2].path).to be == "other"
        end

        it "fails if the path can't be found" do
          expect do
            subject.add HRX::File.new("other", ""), after: "asdf"
          end.to raise_error(HRX::Error, 'There is no entry named "asdf"')
        end

        it "fails if the path is an implicit directory" do
          expect do
            subject.add HRX::File.new("other", ""), after: "super"
          end.to raise_error(HRX::Error, 'There is no entry named "super"')
        end

        it "fails if a trailing slash is used for a file" do
          expect do
            subject.add HRX::File.new("other", ""), after: "file/"
          end.to raise_error(HRX::Error, 'There is no entry named "file/"')
        end
      end
    end
  end

  context "#to_hrx" do
    it "writes a file's name and contents" do
      subject << HRX::File.new("file", "contents\n")
      expect(subject.to_hrx).to be == <<END
<===> file
contents
END
    end

    it "adds a newline to a middle file with a newline" do
      subject << HRX::File.new("file 1", "contents 1\n")
      subject << HRX::File.new("file 2", "contents 2\n")
      expect(subject.to_hrx).to be == <<END
<===> file 1
contents 1

<===> file 2
contents 2
END
    end

    it "adds a newline to a middle file without a newline" do
      subject << HRX::File.new("file 1", "contents 1")
      subject << HRX::File.new("file 2", "contents 2\n")
      expect(subject.to_hrx).to be == <<END
<===> file 1
contents 1
<===> file 2
contents 2
END
    end

    it "writes empty files" do
      subject << HRX::File.new("file 1", "")
      subject << HRX::File.new("file 2", "")
      expect(subject.to_hrx).to be == <<END
<===> file 1
<===> file 2
END
    end

    it "doesn't add a newline to the last file" do
      subject << HRX::File.new("file", "contents")
      expect(subject.to_hrx).to be == "<===> file\ncontents"
    end

    it "writes a directory" do
      subject << HRX::Directory.new("dir")
      expect(subject.to_hrx).to be == "<===> dir/\n"
    end

    it "writes a comment on a file" do
      subject << HRX::File.new("file", "contents\n", comment: "comment")
      expect(subject.to_hrx).to be == <<END
<===>
comment
<===> file
contents
END
    end

    it "writes a comment on a directory" do
      subject << HRX::Directory.new("dir", comment: "comment")
      expect(subject.to_hrx).to be == <<END
<===>
comment
<===> dir/
END
    end

    it "uses a different boundary length to avoid conflicts" do
      subject << HRX::File.new("file", "<===>\n")
      expect(subject.to_hrx).to be == <<END
<====> file
<===>
END
    end

    it "uses a different boundary length to avoid conflicts in comments" do
      subject << HRX::File.new("file", "", comment: "<===>")
      expect(subject.to_hrx).to be == <<END
<====>
<===>
<====> file
END
    end

    it "uses a different boundary length to avoid multiple conflicts" do
      subject << HRX::File.new("file", <<END)
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
      subject << HRX::File.new("file 1", "<===>\n")
      subject << HRX::File.new("file 2", "<====>\n")
      subject << HRX::File.new("file 3", "<=====>\n")
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
        subject << HRX::File.new("file", "contents\n")
        expect(subject.to_hrx).to be == <<END
<=> file
contents
END
      end

      it "doesn't use it if it conflicts" do
        subject << HRX::File.new("file", "<=>\n")
        expect(subject.to_hrx).to be == <<END
<==> file
<=>
END
      end
    end
  end
end
