#!/usr/bin/env ruby
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


class Student
  attr_accessor :first_name, :grade_level
  
  def initialize(fn, g)
    @first_name = fn
    @grade_level = g
  end
  
  def returning?
    @grade_level < 8
  end
  
  def grade_to_s(incr = 0)
    Student.grade_to_s(@grade_level + incr)
  end
  
  def to_s(incr = 0)
    "#{@first_name} (#{grade_to_s(incr)})\n"
  end

  def fill_slots(slots, high_count, incr = 0)
    slots[high_count][0] = "#{@first_name} (#{grade_to_s(incr)})"
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
  
  def initialize(prs, p)
    @parser = prs
    @parents = p
    @postal = ''
    @emails = []
    @phones = []
    @lno = @parser.lno
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
  
  def fill_slots(slots, high_count)
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
  
  def address_to_h
    h = { }
    unless @postal.empty?
      addr = @postal.match(/^(.+),\s+([A-Z].*)\s+([0-9]+)$/)
      if addr
        abbr = addr[2].gsub(/,$/, '').gsub(/\./, '').gsub(/\s+$/, '')
        h["street"] = addr[1]
        h["city"] = ABBRS.fetch(abbr, abbr)
        h["zip"] = addr[3]
      else
        h["street"] = @postal
        @parser.log_error([@postal, @lno])
      end
    end
    h
  end
  
  def emails_to_h
    h = { }
    ems = @emails.map { |n| n.gsub(/\s*\(.+$/, '').strip }
    if ems.size > 0
      h["email1"] = ems[0]
    end
    if ems.size > 1
      h["email2"] = ems[1]
    end
    h
  end
  
  def phones_to_h
    h = { }
    @phones.each_with_index do |p, i|
      ptype = 'home'
      numbers = [ ]
      case p
      when /^\(C\).+/
        ptype = 'cell'
        numbers = p.gsub(/^\(C\)\s*/, '').split('/')
      when /^\(W\).+/
        ptype = 'work'
        numbers = p.gsub(/^\(W\)\s*/, '').split('/')
      else
        ptype = 'home'
        numbers[0] = p.strip
      end
      numbers = numbers.map { |n| n.gsub(/\s*\(.+$/, '').strip }
      if ptype == 'home'
        h['home'] = numbers[0]
      else
        if numbers.size > 0
          h["#{ptype}1"] = numbers[0]
        end
        if numbers.size > 1
          h["#{ptype}2"] = numbers[1]
        end
      end
    end
    h
  end
  
  def print_address
    h = address_to_h
    h.key?('street') && h.key?('city') && h.key?('zip') ?
      "#{h['street']}\n#{h['city']}, CA #{h['zip']}" : @postal
  end
end


class DirectoryEntry
  include Comparable
  attr_accessor :lines, :last_name, :families, :students, :lno
  
  def initialize(p, ls)
    @parser = p
    @last_name = ls
    @lines = [ ls ]
    @families = []
    @students = []
    @lno = @parser.lno
    @bump = @parser.bump
  end
  
  def postal
    @families.last.postal
  end
  
  def postal=(p)
    @families.last.postal = p.strip
  end
  
  def add_family(p)
    @families.push(Family.new(@parser, p.strip))
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
  
  def to_s
    @parser.update_stats(@students.size, @families.size)
    
    str = "LAST_NAME: #{last_name}\n"
    @students.each_with_index do |s, i|
      str << "STUDENT [#{i}]: #{s.to_s(@bump ? 1 : 0)}" unless @bump && !s.returning?
    end
    @families.each_with_index do |f, i|
      str << "FAMILY [#{i}]:\n#{f}"
    end
    str
  end
  
  def to_a
    ary = [ ]
    ary.push(['kikdir_last_name', last_name])
    j = 0
    @students.each_with_index do |s, i|
      unless @bump && !s.returning?
        j += 1
        ary.push(["kikdir_s#{j}_first_name", s.first_name])
        ary.push(["kikdir_s#{j}_grade", s.grade_to_s(@bump ? 1 : 0)])
        break if j == 4
      end
    end
    while j < 4
      j += 1
      ary.push(["kikdir_s#{j}_first_name", ''])
      ary.push(["kikdir_s#{j}_grade", ''])
    end
    j = 0
    @families.each_with_index do |f, i|
      j += 1
      h_address = f.address_to_h
      h_emails = f.emails_to_h
      h_phones = f.phones_to_h
      ary.push(["kikdir_f#{j}_parents", f.parents])
      ary.push(["kikdir_f#{j}_street", h_address.fetch('street', '')])
      ary.push(["kikdir_f#{j}_city", h_address.fetch('city', '')])
      ary.push(["kikdir_f#{j}_zip", h_address.fetch('zip', '')])
      ary.push(["kikdir_f#{j}_email1", h_emails.fetch('email1', '')])
      ary.push(["kikdir_f#{j}_email2", h_emails.fetch('email2', '')])
      ary.push(["kikdir_f#{j}_home_phone", h_phones.fetch('home', '')])
      ary.push(["kikdir_f#{j}_work_phone1", h_phones.fetch('work1', '')])
      ary.push(["kikdir_f#{j}_work_phone2", h_phones.fetch('work2', '')])
      ary.push(["kikdir_f#{j}_cell_phone1", h_phones.fetch('cell1', '')])
      ary.push(["kikdir_f#{j}_cell_phone2", h_phones.fetch('cell2', '')])
      break if j == 2
    end
    while j < 2
      ary.push(["kikdir_f#{j}_parents", ''])
      ary.push(["kikdir_f#{j}_street", ''])
      ary.push(["kikdir_f#{j}_city", ''])
      ary.push(["kikdir_f#{j}_zip", ''])
      ary.push(["kikdir_f#{j}_email1", ''])
      ary.push(["kikdir_f#{j}_email2", ''])
      ary.push(["kikdir_f#{j}_home_phone", ''])
      ary.push(["kikdir_f#{j}_work_phone1", ''])
      ary.push(["kikdir_f#{j}_work_phone2", ''])
      ary.push(["kikdir_f#{j}_cell_phone1", ''])
      ary.push(["kikdir_f#{j}_cell_phone2", ''])
      j += 1
    end
    ary
  end

  def print_mail_merge
    student_high = 0
    slots = Array.new(48) { |i| ['', i] }
    @students.each_with_index do |s, i|
      student_high = s.fill_slots(slots, student_high, @bump ? 1 : 0) unless @bump && !s.returning?
    end
    
    family_high = 0
    @families.each_with_index do |f, i|
      family_high = f.fill_slots(slots, family_high)
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
    
    if family_high > family_stats[1]
      family_stats[0] = self
      family_stats[1] = family_high
    end
    
    str << ">\n"
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
    "#{@name} - See #{@see_also}"
  end
end

class DirectoryParser
  attr_accessor :lno, :bump
  
  def initialize(io, v=false, b=true)
    @io = io
    @verbose = v
    @bump = b
    @lno = 0
    @xrefs = { }
    @entries = [ ]
    @cur_entry = nil
    @parts = ['', '', '']
    @errors = [ ]
    @family_stats = [ nil, 0 ]
    @high_student_count = 0
    @high_family_count = 0
  end
    
  def update_stats(student_count, family_count)
    if student_count > @high_student_count
      @high_student_count = student_count
    end
    if family_count > @high_family_count
      @high_family_count = family_count
    end
  end
  
  def log_error(e)
    @errors.push(e)
  end
  
  def print_stats
    STDERR.puts "Max # of students: #{@high_student_count}"
    STDERR.puts "Max # of families: #{@high_family_count}"
    unless @errors.empty?
      STDERR.puts "errors"
      @errors.each do |e|
        STDERR.puts e.inspect
      end
    end
  end
  
  def tab(f)
    header = true
    @entries.sort.each do |ent|
      next if @bump && !ent.any_returning_students?
      ary = ent.to_a
      if header
        f.write(ary.map { |kv| kv[0]}.join("\t"))
        f.write("\n")
        header = false
      end
      f.write(ary.map { |kv| kv[1]}.join("\t"))
      f.write("\n")
     end
  end
  
  def dump(f)
    f.write("XREFS\n")
    @xrefs.keys.sort.each do |ref|
      ary = @xrefs[ref]
      ary.each do |sa|
        f.write(sa.to_s)
        f.write("\n")
      end
    end
    
    f.write("ENTRIES\n")
    @entries.sort.each do |ent|
      next if @bump && !ent.any_returning_students?
      f.write(ent.to_s)
      f.write("\n")
    end
  end
  
  def print_mail_merge(f)
    @entries.sort.each do |ent|
      next if @bump && !ent.any_returning_students?
      f.write(ent.print_mail_merge)
      f.write("\n")
    end
    
    STDERR.puts "#{@family_stats[1]}: #{@family_stats[0].last_name}"
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
            STDERR.puts "new entry for #{line}" if @verbose
            @cur_entry = DirectoryEntry.new(self, line)
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
            STDERR.puts "col #{col}, #{row}: '#{line}'" if @verbose
            if line.match(/@/)
              STDERR.puts "new email" if @verbose
              @cur_entry.add_email(line)
            elsif !line.empty?
              if @cur_entry.families.size == 0 || !@cur_entry.postal.empty?
                STDERR.puts "new family" if @verbose
                @cur_entry.add_family(line)
              else
                STDERR.puts "new postal" if @verbose
                @cur_entry.postal = line
              end
            end
            col = 2
          when 2
            STDERR.puts "col #{col}, #{row}: '#{line}'" if @verbose
            if !line.empty?
              STDERR.puts "new phone" if @verbose
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
          STDERR.puts "NL col #{col}, #{row}: '#{line}'" if @verbose
          stu = line.match(/^(.+)\s*\(([K1-8])\)\s*$/)
          if stu
            STDERR.puts "new student" if @verbose
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
    # STDERR.puts "line parts: #{@parts.join('\n')}" if @verbose && @lno > 0
    @parts = @parts.map { |p| p.strip }
    line_parsed = false
    if !@parts[0].empty?
      see = @parts[0].match(/^(.+) - See (.+)$/)
      if see
        STDERR.puts "\nnew SA: #{@parts[0]}" if @verbose
        sa = SeeAlso.new(see[1], see[2])
        @cur_entry = nil
        (@xrefs[sa.see_also] ||= [ ]).push(sa)
        line_parsed = true
      else
        stu = @parts[0].match(/^(.+)\s*\(([K1-8])\)\s*$/)
        if stu
          STDERR.puts "new student: #{@parts[0]}" if @verbose
          grade_level = Student.parse_grade_level(stu[2])
          @cur_entry.students.push(Student.new(stu[1], grade_level))
        elsif !@parts[1].empty?
          STDERR.puts "\nnew entry: #{@parts[0]}" if @verbose
          @cur_entry = DirectoryEntry.new(self, @parts[0])
          @entries.push(@cur_entry)
        else
          STDERR.puts "discarding (first): #{@parts[0]}" if @verbose
        end
      end
    end
    if !line_parsed
      if @parts[1].match(/@/)
        STDERR.puts "new email: #{@parts[1]}" if @verbose
        @cur_entry.add_email(@parts[1])
      elsif !@parts[1].empty?
        if @cur_entry.families.size == 0 || !@cur_entry.postal.empty?
          STDERR.puts "new family: #{@parts[1]}" if @verbose
          @cur_entry.add_family(@parts[1])
        else
          STDERR.puts "new postal: #{@parts[1]}" if @verbose
          @cur_entry.postal = @parts[1]
        end
      end
      if !@parts[2].empty?
        STDERR.puts "new phone: #{@parts[2]}" if @verbose
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
          # done = true if @verbose && @entries.size == 20
        end
      end
    rescue
      STDERR.puts "error at line #{@lno}, col #{col}, row #{row}: #{$!}"
      raise
    end
  end
end

# Main script

bump = false
format = 'xml'
verb = false
output = 'merge'
opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] <input> <output.txt>"

  opts.on("-b", "--bump", "Bump students up one year") do
    bump = true
  end
  opts.on("-f", "--format FMT", "Format of input file (xml or txt)") do |f|
    format = f
  end
  opts.on("-o", "--output TYPE", "Type of output (merge, dump or tab)") do |o|
    output = o
  end
  opts.on("-v", "--verbose", "Debugging on STDERR") do
    verb = true
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

parser = nil
File.open(ARGV[0], "r") do |f_in|
  if verb
    STDERR.puts(bump ? "printing with students bumped up one year" : "printing without bump")
    STDERR.puts("output type: #{output}")
  end

  case format
  when /txt/
    parser = TabbedTextParser.new(f_in, verb, bump)
  else
    parser = WordXmlParser.new(f_in, verb, bump)
  end
  
  parser.parse

  File.open(ARGV[1], "w") do |f_out|
    case output
    when /merge/
      parser.print_mail_merge(f_out)
    when /tab/
      parser.tab(f_out)
    else
      parser.dump(f_out)
    end
  end
end
  
parser.print_stats
