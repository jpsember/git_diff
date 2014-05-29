#!/usr/bin/env ruby

require 'git_repo'
require_relative 'git_diff/hunk'
require_relative 'git_diff/fileentry'
require_relative 'git_diff/app'

require 'zlib'

EXTENSIONS = 'txt cpp h m mm rb py pbxproj'

HUNK_UNKNOWN = 0
HUNK_SKIPPED = 1
HUNK_ACCEPTED = 2

class GitDiff

  @@text_extensions = nil

  def initialize(commit_name = nil, verbose = false)
    @verbose = verbose
    @commit_name = commit_name
    perform_git_diff()
    parse_git_diff()
  end

  def num_files
    @file_entries.size
  end

  def file_entry(index)
    @file_entries[index]
  end

  def hunk_display(file_entry, hunk, screen_width = 164, horizontal_offset=0)
    a = []
    b = []
    c = []

    width = (screen_width - 8) / 2
    dash_size = screen_width

    line_number = 0
    while line_number < hunk.num_lines
      x = hunk.line(line_number)
      y = x[1..-1]
      z = x[0]

      x2 = nil
      z2 = '?'
      y2 = ''
      if line_number+1 < hunk.num_lines
        x2 = hunk.line(line_number+1)
        z2 = x2[0]
        y2 = x2[1..-1]
      end

      prefix = ''
      prefix = '...| ' if horizontal_offset != 0

      y = prefix + (y[horizontal_offset..-1] || '')
      y2 = prefix + (y2[horizontal_offset..-1] || '')

      if z == '-' && z2 == '+'
        a << y
        b << y2
        # If the only difference is whitespace, indicate as much
        w1 = replace_tabs_line(y)
        w2 = replace_tabs_line(y2)
        if w1.rstrip == w2.rstrip
          c << 'ww'
        else
          c << '++'
        end
        line_number += 1
      else
        case z
        when ' '
          a << y
          b << y
          c << '  '
        when '-'
          a << y
          b << ''
          c << '+.'
        when '+'
          a << ''
          b << y
          c << '.+'
        when '\\'
          a << '(missing linefeed)'
          b << ''
          c << '+.'
        end
      end

      line_number += 1
    end

    z = dash_text(dash_size)
    z += "\n"

    max_lines = 20
    if a.size <= max_lines
      a.size.times do |i|
        x = replace_tabs_line(a[i])
        y = replace_tabs_line(b[i])
        z += pad(x,width)
        z += '   '+c[i]+'   '
        z += pad(y,width)
        z += "\n"
      end
    else
      (max_lines/2).times do |i|
        x = replace_tabs_line(a[i])
        y = replace_tabs_line(b[i])
        z += pad(x,width)
        z += '   '+c[i]+'   '
        z += pad(y,width)
        z += "\n"
      end
      z += "\n"
      z += pad('',width)+"   \:\n"
      z += pad('',width-4) + "(#{a.size - max_lines} lines)\n"
      z += pad('',width)+"   \:\n"
      z += "\n"
      (max_lines/2).times do |j|
        i = a.size  - (max_lines/2) + j
        x = replace_tabs_line(a[i])
        y = replace_tabs_line(b[i])
        z += pad(x,width)
        z += '   '+c[i]+'   '
        z += pad(y,width)
        z += "\n"
      end
    end
    z += "\n"
    fn = File.basename(file_entry.file_name)

    if file_entry.was_deleted?
      fn = "*** Deleted file: " + fn + " ***"
    elsif file_entry.was_created?
      fn = "*** New file: " + fn + " ***"
    end

    z += dash_text(dash_size,fn)
    z
  end


  private


  def read_hunks(file_ent)
    while true
      x = peek
      break if !x || !x.start_with?('@@')
      read_line
      eat(x,'@@')
      eat(x,'-')
      start_line = eat_int(x)
      num_lines = 1
      if eat_if(x,',')
        num_lines = eat_int(x)
      end
      eat(x,'+')
      start_line2 = eat_int(x)
            num_lines2 = 1
            if eat_if(x,',')
              num_lines2 = eat_int(x)
            end
      eat(x,'@@')

      h = Hunk.new(file_ent.file_name, start_line,num_lines,start_line2,num_lines2)

      while true
        x = peek
        break if !x || x.size == 0
        break if (' +-\\'.index(x[0]) == nil)
        h.add_line(x)
        read_line
      end

      file_ent.add_hunk(h)
    end
    raise Exception,"missing hunks" if file_ent.num_hunks == 0
  end

  def prepare_extensions
    if !@@text_extensions
      @@text_extensions = Set.new
      @@tabbed_extensions = Set.new
      EXTENSIONS.split(' ').each do |x1|
        x = '.' + x1
        @@text_extensions << x
      end
    end
  end

  # Perform 'git diff', capture results in @text
  #
  def perform_git_diff
    db = false #|| true
    cmd = 'git diff'
    if @commit_name
      cmd += ' '+@commit_name
    end

    # Use a single line of context
    cmd += ' -U1'

    text,_ = scall(cmd)
    @text = text
    !db || puts("\ncommand: #{cmd}\n#{@text}")
  end

  def peek
    ret = nil
    if @cursor < @lines.size
      ret = @lines[@cursor]
    end
    ret
  end

  def read_line
    x = peek
    raise Exception,"Unexpected end of file" if !x
    @cursor += 1
    x
  end

  def read_git_diff_header
    x = read_line
    raise Exception,"Expected 'diff --git', got: #{x}" if !x.start_with?('diff --git')
  end

  def read_extended_header
    while true
      x = read_line
      break if x.start_with? 'index'
    end
  end

  def read_unified_header
    x = peek

    if x.start_with?('Binary files')
      read_line
      puts "(skipping:  #{x})"

      return nil
    end

    if !(x.start_with?('---') || x.start_with?('+++'))
      return nil
    end

    a_file = read_line
    b_file = read_line
    if (a_file== '--- /dev/null')
      a_file = nil
    else
      apref = '--- a/'
      raise Exception.new("bad unified header: '#{a_file}'") if !a_file.start_with?(apref)
      a_file = a_file[apref.size..-1].rstrip
    end

    if (b_file== '+++ /dev/null')
      b_file = nil
    else
      bpref = '+++ b/'
      raise Exception.new("bad unified header") if !b_file.start_with?(bpref)
      b_file = b_file[bpref.size..-1].rstrip
    end

    if a_file && b_file && a_file != b_file
        raise Exception,"filenames differ; unsupported!  '#{a_file}' '#{b_file}'"
    end

    FileEntry.new(a_file,b_file)
  end

  def eat(str, item)
    raise Exception,"String #{str} doesn't begin with prefix #{item}" if !str.start_with?(item)
    str.slice!(0...item.size)
    str.lstrip!
  end

  def eat_int(str)
    val = str.slice!(/^\d+/)
    str.lstrip!
    val.to_i
  end

  def eat_if(str,item)
    ret = nil
    if  str.start_with?(item)
      ret = item
      eat(str,item)
    end
    ret
  end


  def pad(str,len)
    if str.size > len
      str[0...len-6]+'.|...|'
    else
     str + ' '*(len-str.size)
    end
  end

  def dash_text(width, msg = nil)
    s = '-' * width
    if msg
      msg = '   '+msg+'   '
      cut0 = (width - msg.size)/2
      cut1 = cut0 + msg.size

      s = s[0..cut0-1] + msg + s[cut1..-1]
    end
    s + "\n"
  end

  def parse_git_diff
    @lines = @text.split("\n")
    @cursor = 0
    @file_entries = []

    while true
      break if !peek
      read_git_diff_header
      read_extended_header
      file_ent = read_unified_header
      next if !file_ent
      read_hunks(file_ent)
      # If the file was just created, then it must already be
      # staged; don't add it.
      if file_ent.was_created?
        printf("(skipping file that was created: %s)\n",file_ent.file_name)
        next
      end
      @file_entries << file_ent
    end
  end

  # Fix up whitespace for a single line of text:
  # trim trailing whitespace, and replace tabs with spaces.
  # Trims any trailing linefeeds.
  #
  def replace_tabs_line(x0, tab_width = 2)
    x = x0.rstrip
    y = ''
    x.split("").each do |c|
      if c == "\t"
        j = (y.size+tab_width)
        j -= j % tab_width
        while y.size < j
          y += ' '
        end
        next
      end
      y += c
    end
    y
  end

end

if __FILE__ == $0
  GitDiffApp.new.run
end
