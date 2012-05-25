require 'nokogiri'
require 'optparse'

ABBRS = { 
# Benicia
'CM' => 'Corte Madera',
# Fairfax
'G' => 'Greenbrae',
'K' => 'Kentfield',
'L' => 'Larkspur',
'Lark' => 'Larkspur',
'MV' => 'Mill Valley',
'N' => 'Novato',
# Petaluma 
# Pleasant Hill
# Pt Richmond
# Richmond
# Ross
'SA' => 'San Anselmo',
'SF' => 'San Francisco',
'SR' => 'San Rafael',
# Santa Clara
# Saratoga
# Sausalito
'T' => 'Tiburon',
'Tib' => 'Tiburon' 
}

ERRORS = [ ]
HIGH_FAM = [ nil, 0 ]

class Student
  attr_accessor :first_name, :grade_level
  
  def initialize(fn, g)
    @first_name = fn
    @grade_level = g
  end
  
  def returning?
    @grade_level < 8
  end
  
  def to_s(incr = 0)
    "#{@first_name} (#{Student.grade_to_s(@grade_level + incr)})\n"
  end

  def print_mail_merge(slots, high_count, incr = 0)
    slots[high_count][0] = "#{@first_name} (#{Student.grade_to_s(@grade_level + incr)})"
    high_count + 3
  end

  def self.parse_grade_level(g)
    g == 'K' ? 0 : g.to_i
  end
  
  def self.grade_to_s(g)
    g == 0 ? 'K' : g.to_s
  end  
end

class Family
  attr_accessor :parents, :postal, :emails, :phones, :lno
  
  def initialize(p, line_no)
    @parents = p
    @postal = ''
    @emails = []
    @phones = []
    @lno = line_no
  end
  
  def to_s
    str = "PARENTS: #{@parents}\nADDRESS: #{@postal}\n"
    @emails.each_with_index do |e, i|
      str << "EMAIL [#{i}]: #{e}\n"
    end
    @phones.each_with_index do |p, i|
      str << "PHONE [#{i}]: #{p}\n"
    end
    str
  end
  
  def print_mail_merge(slots, high_count)
    slots[high_count+1][0] = @parents
    next_high = high_count+3
    unless @postal.empty?
      slots[high_count+4][0] = @postal
      next_high = high_count+6
    end
    @emails.each_with_index do |e, i|
      slots[high_count+7+i*3][0] = e
      next_high = high_count+9+i*3
    end
    @phones.each_with_index do |p, i|
      slots[high_count+2+i*3][0] = p
      temp = high_count+3+i*3
      next_high = temp if temp > next_high
    end
    next_high
  end
  
  def print_address
    str = @postal
    unless str.empty?
      addr = str.match(/^(.+),\s+([A-Z].*)\s+([0-9]+)$/)
      if addr
        abbr = addr[2].gsub(/,$/, '').gsub(/\./, '').gsub(/\s+$/, '')
        city = ABBRS.fetch(abbr, abbr)
        str = "#{addr[1]}\n#{city}, CA #{addr[3]}"
      else
        ERRORS.push([str, @lno])
      end
    end
    str
  end
end


class DirectoryEntry
  include Comparable
  attr_accessor :lines, :last_name, :families, :students, :lno
  
  def initialize(ls, line_no)
    @last_name = ls
    @lines = [ ls ]
    @families = []
    @students = []
    @lno = line_no
  end
  
  def postal
    @families.last.postal
  end
  
  def postal=(p)
    @families.last.postal = p.strip
  end
  
  def add_family(p)
    @families.push(Family.new(p.strip, @lno))
  end
  
  def add_email(e)
    @families.last.emails.push(e.strip)
  end
  
  def add_phone(p)
    @families.last.phones.push(p.strip)
  end
  
  def <=>(other)
    last_name <=> other.last_name
  end
  
  def any_returning_students?
    @students.any? { |s| s.returning? }
  end
  
  def to_s(next_year = true)
    str = "LAST_NAME: #{last_name}\n"
    @students.each_with_index do |s, i|
      str << "STUDENT [#{i}]: #{s.to_s(next_year ? 1 : 0)}" unless next_year && !s.returning?
    end
    @families.each_with_index do |f, i|
      str << "FAMILY [#{i}]:\n#{f}"
    end
    str
  end

  def print_mail_merge(next_year = true)
    student_high = 0
    slots = Array.new(48) { |i| ['', i] }
    @students.each_with_index do |s, i|
      student_high = s.print_mail_merge(slots, student_high, next_year ? 1 : 0) unless next_year && !s.returning?
    end
    
    family_high = 0
    @families.each_with_index do |f, i|
      family_high = f.print_mail_merge(slots, family_high)
    end
    family_high = student_high if student_high > family_high
    
    fam = @families.first
    str = ">#{fam.parents}\n#{fam.print_address}\n<"
    i = 0
    str << "#{last_name}\n"
    while (i < family_high) do
      str << "#{slots[i][0]}\t#{slots[i+1][0]}\t#{slots[i+2][0]}\n"
      i += 3
    end
    if family_high > HIGH_FAM[1]
      HIGH_FAM[0] = self
      HIGH_FAM[1] = family_high
    end
    str
  end
end

class SeeAlso
  attr_accessor :name, :see_also
  
  def initialize(n, sa)
    @name = n
    @see_also = sa
  end
  
  def to_s
    "#{@name} - See #{@see_also}\n"
  end
end

class DirectoryParser
  def initialize(io, d=false)
    @debug = d
    @io = io
    @lno = 0
    @xrefs = { }
    @entries = [ ]
    @cur_entry = nil
    @parts = ['', '', '']
  end
  
  
  def dump(next_year = true)
    STDERR.puts "XREFS"
    @xrefs.keys.sort.each do |ref|
      STDERR.puts @xrefs[ref].to_s
    end
    
    STDERR.puts "ENTRIES"
    @entries.sort.each do |ent|
      next if next_year && !ent.any_returning_students?
      STDERR.puts ent.to_s
      STDERR.puts
    end
  end
  
  def print_mail_merge(f, next_year = true)
    @entries.sort.each do |ent|
      next if next_year && !ent.any_returning_students?
      f.write(ent.print_mail_merge)
      f.write("\n")
    end
  end
end

class TabbedTextParser < DirectoryParser
  def parse
    row = 0
    col = 0
    begin
      while (raw_line = @io.gets)
        @lno += 1
        raw_line.strip!
        line = raw_line.dup
        rectype = 'RS'
        m = line.match(/^\<([A-Z]{2})\/\>(.*)$/)
        if m
          rectype = m[1]
          line = m[2]
        end
        case rectype
        when /RS/
          see = line.match(/^(.+) - See (.+)$/)
          if see
            sa = SeeAlso.new(see[1], see[2])
            @cur_entry = nil
            row = 0
            col = 0
            (@xrefs[sa.see_also] ||= [ ]).push(sa)
          else
            STDERR.puts "new entry for #{line}" if @debug
            @cur_entry = DirectoryEntry.new(line, @lno)
            row = 0
            col = 0
            @entries.push(@cur_entry)
            col += 1
          end
        when /FS/
          case col
          when 0
            if !line.empty?
              raise "FS in col 0, row #{row}: '#{line}'"
            end
            col = 1
          when 1
            STDERR.puts "col #{col}, #{row}: '#{line}'" if @debug
            if line.match(/@/)
              STDERR.puts "new email" if @debug
              @cur_entry.add_email(line)
            elsif !line.empty?
              if @cur_entry.families.size == 0 || !@cur_entry.postal.empty?
                STDERR.puts "new family" if @debug
                @cur_entry.add_family(line)
              else
                STDERR.puts "new postal" if @debug
                @cur_entry.postal = line
              end
            end
            col = 2
          when 2
            STDERR.puts "col #{col}, #{row}: '#{line}'" if @debug
            if !line.empty?
              STDERR.puts "new phone" if @debug
              @cur_entry.add_phone(line)
            end
            col = 0
            row += 1
          end
        when /NL/
          if col != 0
            col = 0
            row += 1
          end
          STDERR.puts "NL col #{col}, #{row}: '#{line}'" if @debug
          stu = line.match(/^(.+)\s*\(([K1-8])\)\s*$/)
          if stu
            STDERR.puts "new student" if @debug
            grade_level = Student.parse_grade_level(stu[2])
            @cur_entry.students.push(Student.new(stu[1], grade_level))
          elsif !line.empty?
            raise "discarding!"
          end
          col = 1
        end
      end
    rescue
      STDERR.puts "error at line #{@lno}, col #{col}, row #{row}: '#{raw_line}'"
      raise
    end
  end
end

class WordXmlParser < DirectoryParser
  NSHASH = {'w' => "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
  
  def do_line(first)
    # STDERR.puts "line parts: #{@parts.join('\n')}" if @debug && @lno > 0
    @parts = @parts.map { |p| p.strip }
    line_parsed = false
    if !@parts[0].empty?
      see = @parts[0].match(/^(.+) - See (.+)$/)
      if see
        STDERR.puts "\nnew SA: #{@parts[0]}" if @debug
        sa = SeeAlso.new(see[1], see[2])
        @cur_entry = nil
        (@xrefs[sa.see_also] ||= [ ]).push(sa)
        line_parsed = true
      else
        stu = @parts[0].match(/^(.+)\s*\(([K1-8])\)\s*$/)
        if stu
          STDERR.puts "new student: #{@parts[0]}" if @debug
          grade_level = Student.parse_grade_level(stu[2])
          @cur_entry.students.push(Student.new(stu[1], grade_level))
        elsif !@parts[1].empty?
          STDERR.puts "\nnew entry: #{@parts[0]}" if @debug
          @cur_entry = DirectoryEntry.new(@parts[0], @lno)
          @entries.push(@cur_entry)
        else
          STDERR.puts "discarding (first): #{@parts[0]}" if @debug
        end
      end
    end
    if !line_parsed
      if @parts[1].match(/@/)
        STDERR.puts "new email: #{@parts[1]}" if @debug
        @cur_entry.add_email(@parts[1])
      elsif !@parts[1].empty?
        if @cur_entry.families.size == 0 || !@cur_entry.postal.empty?
          STDERR.puts "new family: #{@parts[1]}" if @debug
          @cur_entry.add_family(@parts[1])
        else
          STDERR.puts "new postal: #{@parts[1]}" if @debug
          @cur_entry.postal = @parts[1]
        end
      end
      if !@parts[2].empty?
        STDERR.puts "new phone: #{@parts[2]}" if @debug
        @cur_entry.add_phone(@parts[2])
      end
    end
    @parts = ['', '', '']
    @lno += 1
  end
  
  def parse
    row = 0
    col = 0
    done = false
    begin
      doc = Nokogiri::XML(@io)
      first = true
      doc.xpath('//w:body/w:p', NSHASH).each do |para|
        if @parts.any? { |p| !p.strip.empty? }
          do_line(first) 
        end
        break if done
        first = true
        row = 0
        col = 0
        # STDERR.puts "para"
        para.xpath('./w:r', NSHASH).each do |range|
          if range.at('./w:tab', NSHASH)
            col += 1
          end
          if col == 3 || range.at('./w:br', NSHASH)
            if @parts.any? { |p| !p.strip.empty? }
              do_line(first) 
              first = false
            end
            row += 1
            col = 0
          end
          t = range.xpath('./w:t', NSHASH).text
          if range.at('.//w:caps', NSHASH)
            t = t.upcase
          end
          @parts[col] << t
          # done = true if @debug && @entries.size == 20
        end
      end
    rescue
      STDERR.puts "error at line #{@lno}, col #{col}, row #{row}: #{$!}"
      raise
    end
  end
end

# Main script

format = 'xml'
opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] <input> <output.txt>"

  opts.on("-f", "--format", "Format of input file (xml or txt)") do |f|
    format = f
  end
  opts.on_tail("-h", "--help", "Show this help message") do 
    puts opts
    exit
  end
end

opts.parse!
if ARGV.size < 2
  puts opts
  exit
end

File.open(ARGV[0], "r") do |f_in|
  parser = nil
  case format
  when /txt/
    parser = TabbedTextParser.new(f_in)
  else
    parser = WordXmlParser.new(f_in, true)
  end
  parser.parse
  File.open(ARGV[1], "w") do |f_out|
    parser.print_mail_merge(f_out)
  end
end
  
STDERR.puts "#{HIGH_FAM[1]}: #{HIGH_FAM[0].last_name}"
unless ERRORS.empty?
  STDERR.puts "ERRORS"
  ERRORS.each do |e|
    STDERR.puts e.inspect
  end
end
