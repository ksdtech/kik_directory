#!/usr/bin/env ruby

require 'csv'

def canonical_phone(s)
  c = s.gsub(/[^0-9]/, '')
  c[0,3] == '415' ? c[3,7] : c[0,10]
end

ps_phone_keys = [
  :home_phone,
  :mother_cell,
  :father_cell,
  :home2_phone,
  :mother2_cell,
  :father2_cell
]

ps_email_keys = [
  :father_email,
  :mother_email,
  :father2_email,
  :mother2_email
]

marked = { }
data = { }
phone_index = { }
email_index = { }
CSV.foreach('students.txt', :col_sep => "\t", :row_sep => "\n",
  :headers => true, :header_converters => :symbol) do |row|
  sn = row[:student_number]
  marked[sn] = '1'
  data[sn] = row.to_hash
  ps_phone_keys.each do |k|
    phone = row[k]
    if phone
      phone = canonical_phone(phone)
      marked[sn] = phone
      (phone_index[phone] ||= [ ]) << sn
    end
  end
  ps_email_keys.each do |k|
    email = row[k]
    if email
      email = email.strip.downcase
      (email_index[email] ||= [ ]) << sn
    end
  end
end

kik_phone_keys = %w{
  kikdir_f1_home_phone 
  kikdir_f1_cell_phone1 
  kikdir_f1_cell_phone2
  kikdir_f2_home_phone
  kikdir_f2_cell_phone1
  kikdir_f2_cell_phone2
}

kik_email_keys = %w{
  kikdir_f1_email1
  kikdir_f1_email2
  kikdir_f2_email1
  kikdir_f2_email2
}

merge_keys = [
  :student_number,
  :first_name,
  :last_name,
  :grade_level
]

ln = nil
sn = nil
phones = nil
emails = nil
headers = nil
lno = 0
File.open("merged.txt", "w") do |f|
  CSV.foreach('kik_data.txt', :col_sep => "\t", :row_sep => "\n",
    :headers => false) do |row|
    lno += 1
    if headers.nil?
      headers = row.to_a
      ln = headers.index('kikdir_last_name')
      sn = headers.index('kikdir_student_numbers')
      phones = kik_phone_keys.map { |h| headers.index(h) }
      emails = kik_email_keys.map { |h| headers.index(h) }
      f.write((merge_keys.map { |h| h.to_s } + headers).join("\t"))
      f.write("\n")
      next
    end
    all_students = [ ]
    pre_matched = row[sn]
    if pre_matched
      all_students = pre_matched.split(',')
    else
      nphones = 0
      students = nil
      phones.each_with_index do |j, i|
        phone = row[j]
        if !phone.nil? && !phone.empty?
          nphones += 1
          phone = canonical_phone(phone)
          # puts "line #{lno} #{i} phone is #{phone}"
          students = phone_index.fetch(phone, nil)
          break if students
        end
      end
      all_students = all_students + students if students
      students = nil
      emails.each_with_index do |j, i|
        email = row[j]
        if !email.nil? && !email.empty?
          email = email.strip.downcase
          students = email_index.fetch(email, nil)
          break if students
        end
      end
      all_students = all_students + students if students
    end
    if !all_students.empty?
      all_students.uniq.each do |sn|
        f.write((merge_keys.map { |h| data[sn][h] || '' } + row.to_a).join("\t"))
        f.write("\n")
        marked[sn] = nil
      end
    else
      puts("no students matched for line #{lno} #{row[ln]}")
    end
  end
end

marked.each do |sn, v| 
  if v
    puts("no data for student #{sn}, #{data[sn][:first_name]} #{data[sn][:last_name]} (#{data[sn][:grade_level]})")
  end
end