
# A collection of git hunks for a particular file
#

def split_into_lines(s,remove_cr = true)
  x = s.lines.to_a
  if remove_cr
    x.each do |y|
      y.chomp!
    end
  end
  x
end


class FileEntry

  def initialize(namea, nameb)
    @name_a = namea
    @name_b = nameb
    @hunks = []
  end

  def add_hunk(h)
    @hunks << h
  end

  def num_hunks
    @hunks.size
  end

  def hunk(index)
    @hunks[index]
  end

  def file_name(repo = nil)
    nm = @name_a || @name_b
    if repo
      nm = repo.abs_path(nm)
    end
    nm
  end

  def was_deleted?
    @name_b == nil
  end

  def was_created?
    @name_a == nil
  end

  def revert(repo, hunk_index)
    fname = file_name(repo)

    if was_created?
      # At present, it should not have got here, since
      # we don't process entries for newly-created files.
      FileUtils.rm_rf(fname)
      return
    end

    h = hunk(hunk_index)

    y = []
    h.num_lines.times do |i|
      z = h.line(i)
      c = z[0]
      if c == '-' || c == ' '
        y << z[1..-1]
      end
    end

    if was_deleted?
      x = y
    else
      orig_text = FileUtils.read_text_file(fname)
      x = split_into_lines(orig_text)
      x[h.start_line2-1,h.num_line2()] = y
    end

    x2 = x.join("\n")+"\n"

    FileUtils.write_text_file(fname,x2)
  end

end

