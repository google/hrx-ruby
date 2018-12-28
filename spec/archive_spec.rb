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

require 'rspec/temp_dir'

require 'hrx'

RSpec.describe HRX::Archive do
  subject {HRX::Archive.new}

  context "::load" do
    include_context "uses temp dir"

    it "parses a file from disk" do
      File.write("#{temp_dir}/archive.hrx", <<END, mode: "wb")
<===> file
contents
END

      archive = HRX::Archive.load("#{temp_dir}/archive.hrx")
      expect(archive.entries.length).to be == 1
      expect(archive.entries.last.path).to be == "file"
      expect(archive.entries.last.content).to be == "contents\n"
    end

    it "parses a file as UTF-8" do
      File.write("#{temp_dir}/archive.hrx", "<===> 👭\n", mode: "wb")
      archive = HRX::Archive.load("#{temp_dir}/archive.hrx")
      expect(archive.entries.last.path).to be == "👭"
    end

    it "parses a file as UTF-8 despite Encoding.default_external" do
      File.write("#{temp_dir}/archive.hrx", "<===> föö\n", mode: "wb")

      with_external_encoding("iso-8859-1") do
        archive = HRX::Archive.load("#{temp_dir}/archive.hrx")
        expect(archive.entries.last.path).to be == "föö"
      end
    end

    it "fails to parse a file that's invalid UTF-8" do
      File.write("#{temp_dir}/archive.hrx", "<===> \xc3\x28\n".b, mode: "wb")
      expect {HRX::Archive.load("#{temp_dir}/archive.hrx")}.to raise_error(EncodingError)
    end

    it "includes the filename in parse errors" do
      File.write("#{temp_dir}/archive.hrx", "wrong", mode: "wb")
      expect {HRX::Archive.load("#{temp_dir}/archive.hrx")}.to raise_error(HRX::ParseError, /archive\.hrx/)
    end
  end

  context "when first initialized" do
    it "has no entries" do
      expect(subject.entries).to be_empty
    end

    context "#read" do
      it "fails for any path" do
        expect {subject.read("path")}.to raise_error(HRX::Error)
      end
    end

    context "#write" do
      before(:each) {subject.write("path", "contents\n")}

      it "adds a file to the end of the archive" do
        expect(subject.entries.last.path).to be == "path"
        expect(subject.entries.last.content).to be == "contents\n"
      end

      it "adds a file that's readable by name" do
        expect(subject.read("path")).to be == "contents\n"
      end
    end

    context "#child_archive" do
      it "fails for any path" do
        expect {subject.child_archive("path")}.to raise_error(HRX::Error)
      end
    end
  end

  context "#initialize" do
    it "should forbid boundary_length 0" do
      expect {HRX::Archive.new(boundary_length: 0)}.to raise_error(ArgumentError)
    end

    it "should forbid negative boundary_length" do
      expect {HRX::Archive.new(boundary_length: -1)}.to raise_error(ArgumentError)
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
      end.to raise_error(EncodingError)
    end

    it "requires the comment to be valid UTF-8" do
      expect do
        subject.last_comment = "\xc3\x28"
      end.to raise_error(EncodingError)
    end

    it "converts a comment to UTF-8" do
      subject.last_comment = "いか".encode("SJIS")
      expect(subject.last_comment).to be == "いか"
    end
  end

  context "with files and directories in the archive" do
    subject {HRX::Archive.parse(<<END)}
<===> file
file contents

<===> dir/
<===>
comment contents

<===> super/sub
sub contents

<===> very/deeply/
<===> very/deeply/nested/file
nested contents

<===> last
the last file
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

    context "#read" do
      it "throws for an empty path" do
        expect {subject.read("")}.to raise_error(HRX::Error, 'There is no file at ""')
      end

      it "throws for a path that's not in the archive" do
        expect {subject.read("non/existent/file")}.to(
          raise_error(HRX::Error, 'There is no file at "non/existent/file"'))
      end

      it "throws for an implicit directory" do
        expect {subject.read("super")}.to raise_error(HRX::Error, 'There is no file at "super"')
      end

      it "throws for a file wih a slash" do
        expect {subject.read("super/sub/")}.to(
          raise_error(HRX::Error, 'There is no file at "super/sub/"'))
      end

      it "throws for a directory" do
        expect {subject.read("dir")}.to raise_error(HRX::Error, '"dir/" is a directory')
      end

      it "returns the contents of a file at the root level" do
        expect(subject.read("file")).to be == "file contents\n"
      end

      it "returns the contents of a file in a directory" do
        expect(subject.read("super/sub")).to be == "sub contents\n"
      end
    end

    context "#glob" do
      it "returns nothing for an empty glob" do
        expect(subject.glob("")).to be_empty
      end

      it "returns nothing for a path that's not in the archive" do
        expect(subject.glob("non/existent/file")).to be_empty
      end

      it "doesn't return implicit directories" do
        expect(subject.glob("super")).to be_empty
      end

      it "doesn't return a file with a slash" do
        expect(subject.glob("super/sub/")).to be_empty
      end

      it "doesn't return an explicit directory without a leading slash" do
        expect(subject.glob("dir")).to be_empty
      end

      it "returns a file at the root level" do
        result = subject.glob("file")
        expect(result.length).to be == 1
        expect(result.first.path).to be == "file"
      end

      it "returns a file in a directory" do
        result = subject.glob("super/sub")
        expect(result.length).to be == 1
        expect(result.first.path).to be == "super/sub"
      end

      it "returns an explicit directory" do
        result = subject.glob("dir/")
        expect(result.length).to be == 1
        expect(result.first.path).to be == "dir/"
      end

      it "returns all matching files at the root level" do
        result = subject.glob("*")
        expect(result.length).to be == 2
        expect(result.first.path).to be == "file"
        expect(result.last.path).to be == "last"
      end

      it "returns all matching files in a directory" do
        result = subject.glob("super/*")
        expect(result.length).to be == 1
        expect(result.first.path).to be == "super/sub"
      end

      it "returns all matching entries recursively in a directory" do
        result = subject.glob("very/**/*")
        expect(result.length).to be == 2
        expect(result.first.path).to be == "very/deeply/"
        expect(result.last.path).to be == "very/deeply/nested/file"
      end

      it "respects glob flags" do
        result = subject.glob("FILE", File::FNM_CASEFOLD)
        expect(result.length).to be == 1
        expect(result.first.path).to be == "file"
      end
    end

    context "#child_archive" do
      it "throws for an empty path" do
        expect {subject.child_archive("")}.to raise_error(HRX::Error, 'There is no directory at ""')
      end

      it "throws for a path that's not in the archive" do
        expect {subject.child_archive("non/existent/dir")}.to(
          raise_error(HRX::Error, 'There is no directory at "non/existent/dir"'))
      end

      it "throws for a file" do
        expect {subject.child_archive("super/sub")}.to(
          raise_error(HRX::Error, '"super/sub" is a file'))
      end

      context "for an explicit directory with no children" do
        let(:child) {subject.child_archive("dir")}

        it "returns an empty archive" do
          expect(child.entries).to be_empty
        end

        it "serializes to an empty string" do
          expect(child.to_hrx).to be_empty
        end

        it "doesn't return the root directory" do
          expect(child[""]).to be_nil
          expect(child["/"]).to be_nil
          expect(child["dir"]).to be_nil
        end
      end
    end

    context "#write" do
      it "validates the path" do
        expect {subject.write("super/./sub", "")}.to raise_error(HRX::ParseError)
      end

      it "rejects a path that ends in a slash" do
        expect {subject.write("file/", "")}.to raise_error(HRX::ParseError)
      end

      it "fails if a parent directory is a file" do
        expect {subject.write("file/sub", "")}.to raise_error(HRX::Error)
      end

      it "fails if the path is an explicit directory" do
        expect {subject.write("dir", "")}.to raise_error(HRX::Error)
      end

      it "fails if the path is an implicit directory" do
        expect {subject.write("super", "")}.to raise_error(HRX::Error)
      end

      context "with a top-level file" do
        before(:each) {subject.write("new", "new contents\n")}

        it "adds to the end of the archive" do
          expect(subject.entries.last.path).to be == "new"
          expect(subject.entries.last.content).to be == "new contents\n"
        end

        it "adds a file that's readable by name" do
          expect(subject.read("new")).to be == "new contents\n"
        end
      end

      context "with a file in a new directory tree" do
        before(:each) {subject.write("new/sub/file", "new contents\n")}

        it "adds to the end of the archive" do
          expect(subject.entries.last.path).to be == "new/sub/file"
          expect(subject.entries.last.content).to be == "new contents\n"
        end

        it "adds a file that's readable by name" do
          expect(subject.read("new/sub/file")).to be == "new contents\n"
        end
      end

      context "with a file in an explicit directory" do
        before(:each) {subject.write("dir/new", "new contents\n")}

        it "adds to the end of the directory" do
          new_index = subject.entries.find_index {|e| e.path == "dir/"} + 1
          expect(subject.entries[new_index].path).to be == "dir/new"
          expect(subject.entries[new_index].content).to be == "new contents\n"
        end

        it "adds a file that's readable by name" do
          expect(subject.read("dir/new")).to be == "new contents\n"
        end
      end

      context "with a file in an implicit directory" do
        before(:each) {subject.write("super/another", "new contents\n")}

        it "adds to the end of the directory" do
          new_index = subject.entries.find_index {|e| e.path == "super/sub"} + 1
          expect(subject.entries[new_index].path).to be == "super/another"
          expect(subject.entries[new_index].content).to be == "new contents\n"
        end

        it "adds a file that's readable by name" do
          expect(subject.read("super/another")).to be == "new contents\n"
        end
      end

      context "with a file in an implicit directory that's not a sibling" do
        before(:each) {subject.write("very/different/nesting", "new contents\n")}

        it "adds after its cousin" do
          new_index = subject.entries.find_index {|e| e.path == "very/deeply/nested/file"} + 1
          expect(subject.entries[new_index].path).to be == "very/different/nesting"
          expect(subject.entries[new_index].content).to be == "new contents\n"
        end

        it "adds a file that's readable by name" do
          expect(subject.read("very/different/nesting")).to be == "new contents\n"
        end
      end

      context "with an existing filename" do
        let (:old_index) {subject.entries.find_index {|e| e.path == "super/sub"}}
        before(:each) {subject.write("super/sub", "new contents\n")}

        it "overwrites that file" do
          expect(subject.read("super/sub")).to be == "new contents\n"
        end

        it "uses the same location as that file" do
          expect(subject.entries[old_index].path).to be == "super/sub"
          expect(subject.entries[old_index].content).to be == "new contents\n"
        end

        it "removes the comment" do
          expect(subject.entries[old_index].comment).to be_nil
        end
      end

      context "with a comment" do
        it "writes the comment" do
          subject.write("new", "", comment: "new comment\n")
          expect(subject["new"].comment).to be == "new comment\n"
        end

        it "overwrites an existing comment" do
          subject.write("super/sub", "", comment: "new comment\n")
          expect(subject["super/sub"].comment).to be == "new comment\n"
        end

        it "re-uses an existing comment with :copy" do
          subject.write("super/sub", "", comment: :copy)
          expect(subject["super/sub"].comment).to be == "comment contents\n"
        end

        it "ignores :copy for a new file" do
          subject.write("new", "", comment: :copy)
          expect(subject["new"].comment).to be_nil
        end
      end
    end

    context "#delete" do
      it "throws an error if the file doesn't exist" do
        expect {subject.delete("nothing")}.to(
          raise_error(HRX::Error, '"nothing" doesn\'t exist'))
      end

      it "throws an error if the file is in a directory that doesn't exist" do
        expect {subject.delete("does/not/exist")}.to(
          raise_error(HRX::Error, '"does/not/exist" doesn\'t exist'))
      end

      it "throws an error if a file has a trailing slash" do
        expect {subject.delete("file/")}.to raise_error(HRX::Error, '"file/" is a file')
      end

      it "refuses to delete an implicit directory" do
        expect {subject.delete("super/")}.to(
          raise_error(HRX::Error, '"super/" is not an explicit directory and recursive isn\'t set'))
      end

      it "deletes a top-level file" do
        length_before = subject.entries.length
        subject.delete("file")
        expect(subject["file"]).to be_nil
        expect(subject.entries.length).to be == length_before - 1
      end

      it "deletes a nested file" do
        length_before = subject.entries.length
        subject.delete("super/sub")
        expect(subject["super/sub"]).to be_nil
        expect(subject.entries.length).to be == length_before - 1
      end

      it "deletes an explicit directory without a slash" do
        length_before = subject.entries.length
        subject.delete("dir")
        expect(subject["dir/"]).to be_nil
        expect(subject.entries.length).to be == length_before - 1
      end

      it "deletes an explicit directory with a slash" do
        length_before = subject.entries.length
        subject.delete("dir/")
        expect(subject["dir/"]).to be_nil
        expect(subject.entries.length).to be == length_before - 1
      end

      it "deletes an explicit directory with children" do
        length_before = subject.entries.length
        subject.delete("very/deeply")
        expect(subject["very/deeply"]).to be_nil
        expect(subject.entries.length).to be == length_before - 1
      end

      it "recursively deletes an implicit directory" do
        length_before = subject.entries.length
        subject.delete("very/", recursive: true)
        expect(subject["very/deeply"]).to be_nil
        expect(subject["very/deeply/nested/file"]).to be_nil
        expect(subject.entries.length).to be == length_before - 2
      end

      it "recursively deletes an explicit directory" do
        length_before = subject.entries.length
        subject.delete("very/deeply", recursive: true)
        expect(subject["very/deeply"]).to be_nil
        expect(subject["very/deeply/nested/file"]).to be_nil
        expect(subject.entries.length).to be == length_before - 2
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

  context "with physically distant files in the same directory" do
    subject {HRX::Archive.parse(<<END)}
<===> dir/super/sub1
sub1 contents

<===> base 1
<===> dir/other/child1
child1 contents

<===> base 2
<===> dir/super/sub2
sub2 contents

<===> base 3
<===> dir/other/child2
child2 contents

<===> base 4
<===> dir/super/sub3
sub3 contents

<===> base 5
END

    context "#write" do
      context "with a file in an implicit directory" do
        before(:each) {subject.write("dir/other/new", "new contents\n")}

        it "adds after the last file in the directory" do
          new_index = subject.entries.find_index {|e| e.path == "dir/other/child2"} + 1
          expect(subject.entries[new_index].path).to be == "dir/other/new"
          expect(subject.entries[new_index].content).to be == "new contents\n"
        end

        it "adds a file that's readable by name" do
          expect(subject.read("dir/other/new")).to be == "new contents\n"
        end
      end

      context "with a file in an implicit directory that's not a sibling" do
        before(:each) {subject.write("dir/another/new", "new contents\n")}

        it "adds to the end of the directory" do
          new_index = subject.entries.find_index {|e| e.path == "dir/super/sub3"} + 1
          expect(subject.entries[new_index].path).to be == "dir/another/new"
          expect(subject.entries[new_index].content).to be == "new contents\n"
        end

        it "adds a file that's readable by name" do
          expect(subject.read("dir/another/new")).to be == "new contents\n"
        end
      end
    end
  end

  context "#to_hrx" do
    it "returns the empty string for an empty file" do
      expect(subject.to_hrx).to be_empty
    end

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
      subject {HRX::Archive.new(boundary_length: 1)}

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

  context "#write!" do
    include_context "uses temp dir"

    it "saves the archive to disk" do
      subject << HRX::File.new("file", "file contents\n")
      subject << HRX::File.new("super/sub", "sub contents\n")
      subject.write!("#{temp_dir}/archive.hrx")

      expect(File.read("#{temp_dir}/archive.hrx", mode: "rb")).to be == <<END
<===> file
file contents

<===> super/sub
sub contents
END
    end

    it "saves the archive as UTF-8" do
      subject << HRX::File.new("👭", "")
      subject.write!("#{temp_dir}/archive.hrx")
      expect(File.read("#{temp_dir}/archive.hrx", mode: "rb")).to be == "<===> \xF0\x9F\x91\xAD\n".b
    end

    it "saves the archive as UTF-8 despite Encoding.default_external" do
      with_external_encoding("iso-8859-1") do
        subject << HRX::File.new("föö", "")
        subject.write!("#{temp_dir}/archive.hrx")
        expect(File.read("#{temp_dir}/archive.hrx", mode: "rb")).to(
          be == "<===> f\xC3\xB6\xC3\xB6\n".b)
      end
    end
  end
end
