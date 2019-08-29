#!/usr/bin/env ruby
# frozen_string_literal: true

# chrono-manager: codegeass.ru chronology manager.
# Copyright (c) 2019 Sumeragi Kaguya <nyalice _at_ technologist.com>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

require 'net/http'
require 'time'

INPUT_FILE = 'tmp.txt'

class ChronoEntry
  def self.from_string(string)
    init_params = {}

    string.each_line do |line|
      if line.start_with? 'Название:'
        init_params[:name] = line
                             .delete_prefix('Название:')
                             .strip
                             .split(nil, 2)
                             .last
      elsif line.start_with? 'Id темы:'
        init_params[:id] = line.delete_prefix('Id темы:').strip.to_i
      elsif line.start_with? 'Начало:'
        init_params[:start] = DateTime.strptime(
          line.delete_prefix('Начало:').strip,
          '%d.%m.%Y %H:%M'
        )
      elsif line.start_with? 'Конец:'
        init_params[:end_] = DateTime.strptime(
          line.delete_prefix('Конец:').strip,
          '%d.%m.%Y %H:%M'
        )
      elsif line.start_with? 'Персонажи:'
        chara_string = line[/Персонажи: \[?(\d+(?:, \d+)*)?\]?/, 1]
        init_params[:chara] = if chara_string
                                chara_string.split(', ').map(&:to_i)
                              else
                                []
                              end
      elsif line.start_with? 'Часовой пояс:'
        tz_candidates = line
                        .gsub(/\[(\d+), ".*?"\]/, '\1')
                        .scan(/\d+/)
                        .map(&:to_i)

        raise ArgumentError, 'Ambiguous timezone' if
          tz_candidates.length > 1
        raise ArgumentError, 'No timezone on timezone line' if
          tz_candidates.empty?

        init_params[:tz] = tz_candidates.first
      end
    end

    init_params[:timeless] = !init_params.key?(:start)

    begin
      new(init_params)
    rescue ArgumentError
      nil
    end
  end

  def initialize(timeless: false,
                 name:,
                 id:,
                 start:,
                 end_:,
                 chara:,
                 tz:)
    @timeless = timeless
    @name = name
    @id = id
    @start = start
    @end = end_
    @chara = chara
    @tz = tz
  end
end

def read_input_file
  entries = []
  entry = String.new

  File.foreach(INPUT_FILE) do |line|
    line.chomp!

    if line == '------'
      entry = ChronoEntry.from_string(entry)
      entries << entry if entry
      entry = String.new
      next
    end

    entry << "\n" << line unless line.empty?
  end

  pp entries
end

def main
  raw_entries = read_input_file
  pp raw_entries
end

main if $PROGRAM_NAME == __FILE__
