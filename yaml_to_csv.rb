require 'yaml'
require 'pry'
require 'set'
require 'pathname'
require 'csv'

class YamlToCsv

  attr_reader :input_path, :languages, :all_yamls, :outfile
  attr_writer :yaml_structure

  def initialize(input_path='in', languages=%i(en nl), outfile='bla.csv')
    @input_path = input_path; @languages = languages
    @all_yamls = {}
    @outfile = outfile
    @file = csv_file
  end

  def run
    write_to_csv("#path", "parent", "level", *@languages)
    filenames = read_filenames
    filenames.each do |filename|
      write_to_csv(filename)
      languages.each { |language| all_yamls[language] = read_yaml_structure_from_file(filename, language)}
      depth_first_traversal(all_yamls[:en])
    end
    close_csv_file
  end

  protected

  def csv_file
    @file ||= CSV.open(@outfile, 'wb')
    @file
  end

  def close_csv_file
    @file.close
  end

  def write_to_csv(*row)
    csv_file << (Array.new) << row
  end

  # fetch a record from a hash based on a path
  def fetch_record_from_path(path, hash, language)
    pathlets = path.split('.')
    pathlets = [language.to_s] + pathlets[2..-1]
    pathlets.each { |pathlet| hash = hash[pathlet] }
    "\"#{hash}\""
  end

  def remove_language_from(path)
    "."+path.split(".")[2..-1].join('.') if path && path.length >= 1
  end

  def write_node(parent, path, level)
    write_to_csv(remove_language_from(path), parent, level)
  end

  def yaml_for(language)
    all_yamls[language]
  end

  def write_leaf(value, parent, path, level)
    records = languages.inject([]) { |acc, language| acc << fetch_record_from_path(path, yaml_for(language), language) }
    write_to_csv(remove_language_from(path), parent, level, *records)
  end

  def depth_first_traversal(h, parent=nil, path="", level=0)
    if h.kind_of? String
      write_leaf(h, parent, path, level)
    elsif h.kind_of?(Hash)
      write_node(parent, path, level)
      h.each do |parent, new_h|
        depth_first_traversal(new_h, parent, "#{path}.#{parent}", level+1)
      end
    end
  end

  def read_filenames
    filenames = Dir.entries(input_path).select {|entry| entry =~ /.yml\z/}.inject([]) {|accum, entry| filename = entry.match(/(.+).(en|nl).yml\z/)[1]; accum += [filename] }
    filenames = Set.new(filenames).to_a
  end

  def read_yaml_structure_from_file(filename, language)
    full_path = "#{input_path}/#{filename}.#{language}.yml"
    yaml = File.open(full_path).read if Pathname(full_path).exist?
    YAML.load(yaml)
  end

end

YamlToCsv.new.run
