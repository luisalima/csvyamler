require 'yaml'
require 'pry'
require 'set'
require 'pathname'
require 'csv'

class CsvToYaml

  attr_reader :languages, :outpath

  def initialize(folder='.', infile='bla.csv', outpath='out')
    @folder = folder; @infile = infile; @yaml_files = {}; @outpath = outpath
    Dir.mkdir(@outpath) unless File.exists? File.expand_path(outpath)
  end

  def run
    read_all
  end

  def languages
    @languages ||= %w(en nl)
  end

  def yaml_file_for(filename, language)
    @yaml_files[language] ||= {}
    @yaml_files[language][filename] ||= File.open("#{outpath}/#{filename}.#{language.to_s}.yml", "w")
  end

  def close_language_files
    languages.each do |language|
      @yaml_files[language].each { |k, file| file.close }
    end
  end

  def get_index_for(language)
    indexes = {en: 0, nl: 1}
    indexes[language.to_sym]
  end

  def read_all
    filename = 'tmp'
    CSV.foreach(@infile, 'r') do |row|
      path = row[0]; parent=row[1]; level=row[2].to_i; values = row[3..-1]
      if(new_filename(path))
        filename = new_filename(path)
        p "Creating [#{filename}]..."
      else
        languages.each do |language|
          parent = language if parent == 'en'
          value = values[get_index_for(language)] if values
          s = create_yaml_for_path(".#{language.to_s}#{path}", parent, level, value)
          yaml_file_for(filename, language).write(s)
        end
      end
    end
    close_language_files
  end

  def new_filename(path)
    if path && path[0] != '.' && path[0] !=  '#'
      path
    else
      nil
    end
  end

  def create_yaml_for_path(path, parent, level, value)
    return unless path && parent && level != 0
    s = " "*((level-1)*2) + "#{parent}:"
    s += " #{value}" unless value == nil
    "#{s}\n"
  end

end

CsvToYaml.new.run
