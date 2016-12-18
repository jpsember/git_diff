require 'backup_set'
require 'js_base/text_editor'

class GitDiffApp

  def initialize
    @gitdiff = nil
  end

  def save_backups
    @gitdiff.num_files().times do |i|
      fe = @gitdiff.file_entry(i)
      next if fe.was_deleted?
      fname = fe.file_name
      @backups.backup_file(fname)
    end
  end

  def get_hunk_for(hashcode)
    File.join(@backups.backup_dir,"hunk_#{hashcode}.txt")
  end

  # Remove any skipped flags (but not accepted)
  def remove_skipped(forget_all = false)
    bl = Dir.entries(@backups.backup_dir)
    bl.each do |x|
      next if x == '.' || x == '..'
      next if !x.start_with?('hunk_')
      y = File.join(@backups.backup_dir,x)
      q = FileUtils.read_text_file(y)
      st = q.to_i
      if (st < HUNK_ACCEPTED || forget_all)
        FileUtils.rm_rf(y)
      end
    end
  end

  def get_hunk_status(hashcode)
    st = HUNK_UNKNOWN
    f = get_hunk_for(hashcode)
    if File.exists?(f)
      q = FileUtils.read_text_file(f)
      st = q.to_i
    end
    st
  end

  def build_gitdiff
    if !@gitdiff
      @gitrepo = GitRepo.new
      rev_name = @gitrepo.past_commit_name(-1-@revdistance)
      @gitdiff = GitDiff.new(rev_name, @verbose)
    end
    @gitdiff
  end

  def mark_hunk(hash_code, value)
    hf = get_hunk_for(hash_code)
    FileUtils.write_text_file(hf,value.to_s)
  end

  def run(argv = nil)
    argv = ARGV if !argv

    alternate = false

    p = Trollop::Parser.new do
      opt :forget, "forget any previously accepted differences"
      opt :distance, "revision distance from previous commit",:default =>0
      opt :verbose, "verbose operation"
      opt :showdir, "show backup directory and exit"
      opt :sublime, "use sublime, and not vi, for edits"
    end

    options = Trollop::with_standard_exception_handling p do
      p.parse argv
    end

    raise Exception,"extra arguments" if p.leftovers.size > 0
    @quit_flag = false

    @revdistance = options[:distance]
    @verbose = options[:verbose]
    @sublime = options[:sublime]

    build_gitdiff

    @backups = BackupSet.new('gitdiff',@gitrepo.basedir)
    if options[:showdir]
      puts @backups.backup_dir
      return
    end

    save_backups

    # Throw out any 'skipped' files
    remove_skipped(options[:forget])

    file_index = 0
    hunk_index = 0
    skip_file_index = nil
    horizontal_offset = 0
    scroll_amount = 20
    reset_scroll = true

    # We repeat this loop until we run out of hunks, or we're told to quit
    #
    while !@quit_flag
      if !@gitdiff
        file_index = 0
        hunk_index = 0
        build_gitdiff
        reset_scroll = true
      end
      break if file_index >= @gitdiff.num_files
      file_ent = @gitdiff.file_entry(file_index)
      if hunk_index >= file_ent.num_hunks
        hunk_index = 0
        file_index += 1
        next
      end
      if reset_scroll
        horizontal_offset = 0
      end
      reset_scroll = true

      h = file_ent.hunk(hunk_index)
      fn = file_ent.file_name(@gitrepo)
      hstr = fn + h.to_s
      hunk_hash = Zlib::crc32(hstr)

      # Has user already dealt with this hunk?
      if get_hunk_status(hunk_hash) != HUNK_UNKNOWN
        hunk_index += 1
        next
      end

      if skip_file_index == file_index
        mark_hunk(hunk_hash,HUNK_SKIPPED)
        next
      end

      print "\n\n\n"
      # Print different number linefeeds each time so user
      # knows he's making progress
      if alternate
        print "\n"
      end
      alternate ^= true

      x = @gitdiff.hunk_display(file_ent,h,horizontal_offset)
      puts x

      while !@quit_flag
        valid = true

        print("a)ccept, e)dit, R)evert, s)kip, S)kipfile, q)uit, ag)ain: ")
        cmd = RubyBase.get_user_char('q')
        puts

        case cmd
        when '-'
          horizontal_offset = [0,horizontal_offset - scroll_amount].max
          reset_scroll = false
        when '='
          horizontal_offset = [250,horizontal_offset + scroll_amount].min
          reset_scroll = false
        when 'a'
          mark_hunk(hunk_hash,2)
        when 'e'
          if file_ent.was_deleted?
            puts "File was deleted! Try reverting it first."
            valid = false
          else
          editor = TextEditor.new(fn)
          editor.line_number = h.start_line2 + 1 # Put at line that probably contains the change
          editor.edit
          @gitdiff = nil
          end
        when 'R'
          file_ent.revert(@gitrepo,hunk_index)
          @gitdiff = nil
        when 'q'
          @quit_flag = true
        when 'g'
          # Just display results and repeat
        when 's'
          mark_hunk(hunk_hash,HUNK_SKIPPED)
        when 'S'
          mark_hunk(hunk_hash,HUNK_SKIPPED)
          skip_file_index = file_index
        else
          valid = false
          puts "Invalid choice!"
        end
        break if valid
      end
    end
  end
end
