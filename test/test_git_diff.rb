#!/usr/bin/env ruby

require 'js_base/test'
require 'git_diff'

class TestGitDiff < Test::Unit::TestCase

    # These commands built a git repository with a bit of a history,
    # within the current directory.
    #
  @@cmds_start = <<-eos
##################################
git init
cp Lincoln1 foo
mkdir alpha
cp Lincoln2 alpha/bar
mkdir alpha/beta
echo "Gettysburg" > alpha/beta/delta
git add *
git commit -m 'initial commit'
cp Lincoln1 alpha/bar
git rm foo
git commit -am 'second commit'
echo "Gettysburg" > foo2
cat Lincoln1 >> alpha/bar
git add foo2
git commit -am 'third commit'
cp Lincoln1 alpha/beta/delta
##################################
eos

  def setup
    enter_test_directory
    new_dir = 'myrepo'
    FileUtils.mkdir_p(new_dir)
    Dir.chdir(new_dir)
    FileUtils.cp('../../lincoln1.txt','Lincoln1')
    FileUtils.cp('../../lincoln2.txt','Lincoln2')

    @swizzler = Swizzler.new
    @swizzler.add("BackupSet","get_home_dir"){".."}

    @swizzler.add('TextEditor','edit') do
      path = self.path
      x = FileUtils.read_text_file(path)
      x << "These lines are new,\nadded by our swizzled edit operation\n"
      FileUtils.write_text_file(path,x)
    end
    scalls(@@cmds_start)
  end

  def teardown
    @swizzler.remove_all
    leave_test_directory
  end

  def record(message="", prefix=nil, args_str='')
    IORecorder.new(prefix).perform do
      puts
      printf("Recording unit test; %s (prefix=%s, arguments=%s)\n",message,prefix,args_str)
      GitDiffApp.new().run(args_str.split)
      puts
    end
  end

  def test_1
    record("Calling with depth 0")
  end

  def test_depth_1
    record("Calling with depth 1",nil,'-d 1')
  end

  def test_no_forget
    record("First of repeated call",'no_forget_1','-d 1')
    record("Second of repeated call, should remember",'no_forget_2','-d 1')
  end

  def test_forget
    record("First of repeated call, will forget",'forget_1','-d 1')
    record("First of repeated call, now forgetting",'forget_2','-f -d 1')
  end

  def test_revert
    record("Revert 'delta' file test")
  end

end
