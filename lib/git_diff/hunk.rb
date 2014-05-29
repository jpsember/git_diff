# A git 'hunk', representing a unit of modification for a file
#
class Hunk
  attr_reader :filename, :start_line1, :num_line1, :start_line2, :num_line2

  def initialize(filename, start_ln_1, num_ln_1, start_ln_2, num_ln_2)
    @filename = filename
    @start_line1 = start_ln_1
    @num_line1 = num_ln_1
    @start_line2 = start_ln_2
    @num_line2 = num_ln_2
    @lines = []
  end

  def add_line(x)
    @lines << x
  end

  def to_s
    s = "#{start_line1}/#{start_line2}/#{@lines}"
    s
  end

  def num_lines
    @lines.size
  end

  def line(index)
    @lines[index]
  end

  def new_file?
    @start_line1 == 0
  end

  def deleted_file?
    @start_line2 == 0
  end

end

