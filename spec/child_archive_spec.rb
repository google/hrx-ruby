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

RSpec.describe HRX::Archive, "as a child" do
  let(:parent) {HRX::Archive.parse(<<END)}
<===> before
file before dir

<===> dir/top
top-level child

<===> dir/sub/mid
mid-level child

<===> dir/sub/dir/
<===> interrupt
interruption not in dir

<===> dir/sub/lower/bottom
bottom-level child

<===> after
file after dir
END

  let(:child) {parent.child_archive("dir")}

  context "#entries" do
    it "is frozen" do
      expect do
        child.entries << HRX::Directory.new("dir")
      end.to raise_error(RuntimeError)
    end

    it "should only contain entries in the directory" do
      expect(child.entries.length).to be == 4
      expect(child.entries[0].path).to be == "top"
      expect(child.entries[1].path).to be == "sub/mid"
      expect(child.entries[2].path).to be == "sub/dir/"
      expect(child.entries[3].path).to be == "sub/lower/bottom"
    end

    it "should reflect changes to the child archive" do
      child << HRX::File.new("another", "")
      expect(child.entries.length).to be == 5
      expect(child.entries.last.path).to be == "another"
    end

    it "should reflect changes to the parent archive" do
      parent << HRX::File.new("dir/another", "")
      expect(child.entries.length).to be == 5
      expect(child.entries.last.path).to be == "another"
    end
  end

  context "#[]" do
    it "should return a top-level entry" do
      expect(child["top"].path).to be == "top"
      expect(child["top"].content).to be == "top-level child\n"
    end

    it "should return a nested entry" do
      expect(child["sub/lower/bottom"].path).to be == "sub/lower/bottom"
      expect(child["sub/lower/bottom"].content).to be == "bottom-level child\n"
    end

    it "should return an explicit directory" do
      expect(child["sub/dir"].path).to be == "sub/dir/"
      expect(child["sub/dir"]).not_to respond_to(:content)
    end

    it "shouldn't return a file that isn't in the directory" do
      expect(child["interrupt"]).to be_nil
    end

    it "should reflect changes to the child archive" do
      child << HRX::File.new("another", "another contents\n")
      expect(child["another"].path).to be == "another"
      expect(child["another"].content).to be == "another contents\n"
    end

    it "should reflect changes to the parent archive" do
      parent << HRX::File.new("dir/another", "another contents\n")
      expect(child["another"].path).to be == "another"
      expect(child["another"].content).to be == "another contents\n"
    end
  end

  context "#read" do
    it "should read a top-level file" do
      expect(child.read("top")).to be == "top-level child\n"
    end

    it "should read a nested file" do
      expect(child.read("sub/lower/bottom")).to be == "bottom-level child\n"
    end

    it "shouldn't read a file that isn't in the directory" do
      expect {child.read("interrupt")}.to(
        raise_error(HRX::Error, 'There is no file at "interrupt"'))
    end

    it "should reflect changes to the child archive" do
      child << HRX::File.new("another", "another contents\n")
      expect(child.read("another")).to be == "another contents\n"
    end

    it "should reflect changes to the parent archive" do
      parent << HRX::File.new("dir/another", "another contents\n")
      expect(child.read("another")).to be == "another contents\n"
    end
  end

  context "#child_archive" do
    let(:grandchild) {child.child_archive("sub")}

    it "should access an even more nested entry" do
      expect(grandchild.read("mid")).to be == "mid-level child\n"
    end

    it "should reflect changes in the parent archive" do
      parent << HRX::File.new("dir/sub/another", "another contents\n")
      expect(grandchild.entries.length).to be == 4
      expect(grandchild.entries.last.path).to be == "another"
      expect(grandchild.read("another")).to be == "another contents\n"
    end

    it "should propagate changes to the parent archive" do
      grandchild << HRX::File.new("another", "another contents\n")
      expect(parent.entries.length).to be == 8
      expect(parent.entries.last.path).to be == "dir/sub/another"
      expect(parent.read("dir/sub/another")).to be == "another contents\n"
    end
  end

  context "#write" do
    before(:each) {child.write("another", "another contents\n")}

    it "should be visible in the child archive" do
      expect(child.entries.length).to be == 5
      expect(child.entries.last.path).to be == "another"
      expect(child.read("another")).to be == "another contents\n"
    end

    it "should be visible in the parent archive" do
      expect(parent.entries.length).to be == 8
      previous_path = "dir/" + child.entries[-2].path
      new_index = parent.entries.find_index {|e| e.path == previous_path} + 1
      expect(parent.entries[new_index].path).to be == "dir/another"
      expect(parent.read("dir/another")).to be == "another contents\n"
    end
  end

  context "#delete" do
    context "for a single file" do
      before(:each) {child.delete("top")}

      it "should be visible in the child archive" do
        expect(child.entries.length).to be == 3
        expect(child["top"]).to be_nil
      end

      it "should be visible in the parent archive" do
        expect(parent.entries.length).to be == 6
        expect(parent["dir/top"]).to be_nil
      end
    end

    context "recursively" do
      before(:each) {child.delete("sub", recursive: true)}

      it "should be visible in the child archive" do
        expect(child.entries.length).to be == 1
        expect(child["sub/mid"]).to be_nil
        expect(child["sub/dir"]).to be_nil
        expect(child["sub/lower/bottom"]).to be_nil
      end

      it "should be visible in the parent archive" do
        expect(parent.entries.length).to be == 4
        expect(child["dir/sub/mid"]).to be_nil
        expect(child["dir/sub/dir"]).to be_nil
        expect(child["dir/sub/lower/bottom"]).to be_nil
      end
    end
  end

  context "#last_comment=" do
    before(:each) {child.last_comment = "comment\n"}

    it "sets the #last_comment field" do
      expect(child.last_comment).to be == "comment\n"
    end

    it "affects the child's #to_hrx" do
      expect(child.to_hrx).to end_with("<===>\ncomment\n")
    end

    it "doesn't affect the parent's #to_hrx" do
      expect(parent.to_hrx).not_to include("\ncomment\n")
    end
  end

  context "#add" do
    context "with no position" do
      before(:each) {child.add(HRX::File.new("another", "another contents\n"))}

      it "should be visible in the child archive" do
        expect(child.entries.length).to be == 5
        expect(child.entries.last.path).to be == "another"
        expect(child.read("another")).to be == "another contents\n"
      end

      it "should be visible in the parent archive" do
        expect(parent.entries.length).to be == 8
        expect(parent.entries.last.path).to be == "dir/another"
        expect(parent.read("dir/another")).to be == "another contents\n"
      end
    end

    context "with a position" do
      before(:each) do
        child.add(HRX::File.new("another", "another contents\n"), after: "sub/mid")
      end

      it "should be visible in the child archive" do
        expect(child.entries.length).to be == 5
        new_index = child.entries.find_index {|e| e.path == "sub/mid"} + 1
        expect(child.entries[new_index].path).to be == "another"
        expect(child.read("another")).to be == "another contents\n"
      end

      it "should be visible in the parent archive" do
        expect(parent.entries.length).to be == 8
        new_index = parent.entries.find_index {|e| e.path == "dir/sub/mid"} + 1
        expect(parent.entries[new_index].path).to be == "dir/another"
        expect(parent.read("dir/another")).to be == "another contents\n"
      end
    end
  end

  context "#to_hrx" do
    it "should only serialize entries in the directory" do
      expect(child.to_hrx).to be == <<END
<===> top
top-level child

<===> sub/mid
mid-level child

<===> sub/dir/
<===> sub/lower/bottom
bottom-level child
END
    end

    it "should reflect changes to the child archive" do
      child << HRX::File.new("another", "")
      expect(child.to_hrx).to be == <<END
<===> top
top-level child

<===> sub/mid
mid-level child

<===> sub/dir/
<===> sub/lower/bottom
bottom-level child

<===> another
END
    end

    it "should reflect changes to the parent archive" do
      parent << HRX::File.new("dir/another", "")
      expect(child.to_hrx).to be == <<END
<===> top
top-level child

<===> sub/mid
mid-level child

<===> sub/dir/
<===> sub/lower/bottom
bottom-level child

<===> another
END
    end
  end
end
