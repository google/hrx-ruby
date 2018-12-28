# HRX (Human Readable Archive)

This gem is a parser and serializer for the [HRX format][].

[HRX format]: https://github.com/google/hrx

```ruby
# Load an archive from a path on disk. You can also parse it directly from a
# string using HRX::Archive.parse, or create an empty archive using
# HRX::Archive.new.
archive = HRX::Archive.load("path/to/archive.hrx")

# You can read files directly from an archive as though it were a filesystem.
puts archive.read("dir/file.txt")

# You can also write to files. Writing to a file implicitly creates any
# directories above it. You can also overwrite an existing file.
archive.write("dir/new.txt", "New file contents!\n")

# You can access HRX::File or HRX::Directory objects directly using
# HRX::Archive#[]. Unlike HRX::Archive#read(), this will just return nil if the
# entry isn't found.
archive["dir/file.txt"] # => HRX::File

# You can add files to the end of the archive using HRX::Archive#<< or
# HRX::Archive#add. If you pass `before:` or `after:`, you can control where in
# the archive they're added.
archive << HRX::File.new("dir/newer.txt", "Newer file contents!\n")

# Write the file back to disk. You can also use HRX::Archive#to_hrx to serialize
# the archive to a string.
archive.write!("path/to/archive.hrx")
```

## Executable

This gem also comes with an `hrx` command-line executable. Use `hrx help` to
learn about what it can do!

This is not an officially supported Google product.
