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

RSpec.describe "hrx create", type: :aruba do
  before :each do
    write_file("file1.txt", "contents 1\n")
    write_file("file2.txt", "contents 2\n")

    write_file("sub/file1.txt", "sub contents 1\n")
    write_file("sub/file2.txt", "sub contents 2\n")
    write_file("sub/.file.txt", "sub dot contents\n")
  end

  it "creates an empty HRX file" do
    run_command_and_stop "bin/hrx create archive.hrx"

    expect("archive.hrx").to have_file_content("")
  end

  it "creates an HRX file with the given contents" do
    run_command_and_stop "bin/hrx create archive.hrx file1.txt file2.txt"

    expect("archive.hrx").to have_file_content <<END
<===> file1.txt
contents 1

<===> file2.txt
contents 2
END
  end

  it "creates an HRX file with everything in a directory" do
    run_command_and_stop "bin/hrx create archive.hrx sub"

    expect("archive.hrx").to have_file_content <<END
<===> sub/.file.txt
sub dot contents

<===> sub/file1.txt
sub contents 1

<===> sub/file2.txt
sub contents 2
END
  end

  it "writes filenames relative to --root" do
    run_command "bin/hrx create --root sub archive.hrx sub"

    expect("archive.hrx").to have_file_content <<END
<===> .file.txt
sub dot contents

<===> file1.txt
sub contents 1

<===> file2.txt
sub contents 2
END
  end

  context "fails gracefully for" do
    it "an input file that doesn't exist" do
      run_command "bin/hrx create archive.hrx no-file.txt", fail_on_error: false
      expect(last_command_started).not_to be_successfully_executed
      expect(last_command_started.stderr).not_to include_a_stack_trace
    end

    it "an archive in a directory that doesn't exist" do
      run_command "bin/hrx create no-dir/archive.hrx file1.txt", fail_on_error: false
      expect(last_command_started).not_to be_successfully_executed
      expect(last_command_started.stderr).not_to include_a_stack_trace
    end

    it "an input file that's not in the working directory" do
      cd "sub"

      run_command "bin/hrx create archive.hrx ../file1.txt", fail_on_error: false
      expect(last_command_started).not_to be_successfully_executed
      expect(last_command_started.stderr).not_to include_a_stack_trace
    end

    it "an input file that's not in the root directory" do
      run_command "bin/hrx create --root sub archive.hrx file1.txt", fail_on_error: false
      expect(last_command_started).not_to be_successfully_executed
      expect(last_command_started.stderr).not_to include_a_stack_trace
    end

    it "an input file that's not valid UTF-8" do
      write_file "invalid-file.txt", "\xc3\x28\n".b
      run_command "bin/hrx create archive.hrx invalid-file.txt", fail_on_error: false
      expect(last_command_started).not_to be_successfully_executed
      expect(last_command_started.stderr).not_to include_a_stack_trace
    end

    it "an input file with an invalid path" do
      touch "foo:bar.txt"
      run_command "bin/hrx create archive.hrx foo:bar.txt", fail_on_error: false
      expect(last_command_started).not_to be_successfully_executed
      expect(last_command_started.stderr).not_to include_a_stack_trace
    end
  end
end
