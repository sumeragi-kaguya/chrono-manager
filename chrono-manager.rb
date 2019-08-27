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
require 'set'
require 'time'

OUTPUT_FILE = 'tmp.txt'
PURGATORY_LINK = 'http://codegeass.ru/viewforum.php?id=89'
MONTH_REPLACE = {
  'января' => 'Jan',
  'февраля' => 'Feb',
  'марта' => 'Mar',
  'апреля' => 'Apr',
  'мая' => 'May',
  'июня' => 'Jun',
  'июля' => 'Jul',
  'августа' => 'Aug',
  'сентября' => 'Sep',
  'октября' => 'Oct',
  'ноября' => 'Nov',
  'декабря' => 'Dec'
}.freeze
MINIMAL_CHAR_CHRONO_LEN = 2
CHARS = {
  "Рианнон О'Нейл" => 58,
  'Emiya Atsuko' => 216,
  'Emmerich Meyer' => 292,
  'M.M.' => 258,
  'N.N' => 64,
  'Wayne Stranszberg' => 301,
  'Александр Крестовский' => 26,
  'Алексей Ланской' => 253,
  'Анжела Лаврова' => 129,
  'Анна Клемент' => 87,
  'Аня Альстрейм' => 33,
  'Астрид Гудбранд' => 302,
  'Бен Кламски' => 278,
  'Владимир Макаров' => 29,
  'Гвиневра су Британия' => 36,
  'Джино Вайнберг' => 72,
  'Дункан Кэмпбелл' => 71,
  'Зеро' => 1,
  'Иван Полозов' => 265,
  'Кагуя Сумераги' => 49,
  'Каллен Кодзуки' => 3,
  'Каллен Козуки' => 3,
  'Карин нэ Британия' => 189,
  'Кассандра Бота' => 162,
  'Ким Сайрумов' => 300,
  'Кловис ла Британия' => 245,
  'Командующий Кобра' => 270,
  'Константин Уайт' => 297,
  'Ллойд Асплунд' => 10,
  'Лучиано Брэдли' => 167,
  'Марианна Британская' => 273,
  'Марианна ви Британия' => 273,
  'Марика Сореси' => 259,
  'Мария Вуйцик' => 257,
  'Миллай' => 2,
  'Мима' => 258,
  'Митт Траун' => 103,
  'Наннали' => 7,
  'Одиссей ю Британия' => 48,
  'Павел Романов' => 188,
  'Пьер Мао' => 305,
  'Пьер Эжен Мао' => 305,
  'Ренли ла Британия' => 11,
  'Сесиль Круми' => 148,
  'Сольф Кимбли' => 243,
  'Соня Эльтнова' => 277,
  'Станислав Мальченко' => 90,
  'Тянцзы' => 47,
  'Чарльз Британский' => 74,
  'Чарльз зи Британия' => 74,
  'Шарли Фенетт' => 6,
  'Элис Блекберри' => 239,
  'Элис' => 239,
  'Эмия Атсуко' => 216
}.freeze
CHARS_ID = {
  589 => 292,
  603 => 301,
  346 => 216
}
TIMEZONES = {
  'Пендрагон' => 0,
  'Нео-Токио' => 16,
  'Рим, Ватикан' => 8,
  'СБИ, 11 сектор' => 16,
  'Российская Империя, Москва' => 10,
  'Москва' => 10,
  'Санкт-Петербург' => 10,
  'Павлодар' => 13,
  'Сальвадор, Бразилия' => 1,
  '11 сектор' => 16,
  'Священная Британская Империя, 11 сектор' => 16,
  'Восточный Тимор' => 15,
  'Евросоюз, Франция' => 8,
  'Франция' => 8,
  'Мадагаскар' => 10,
  'Британия, герцогство Висконсин' => 1,
  'Висконсин' => 1,
  'Претория' => 9,
  'Евросоюз, Российская Империя, Выборг' => 10,
  'Китай' => 15,
  'Индия, Дели' => 12,
  'Гонконг' => 15,
  'Кронштадт' => 10,
  'Колумбия' => 2,
}.freeze

class HeaderError < ArgumentError
  attr_reader :complaints

  def initialize(complaints, msg = 'Bad header')
    @complaints = complaints
    super(msg)
  end
end

class BadCharRef < ArgumentError
end

def parse_date(date_string)
  date_string = date_string.strip

  case date_string
  when /^\d?\d\.\d?\d\.\d\d$/
    DateTime.strptime(date_string, '%d.%m.%y')
  when /^\d?\d\.\d?\d\.\d{4}$/
    DateTime.strptime(date_string, '%d.%m.%Y')
  when /^\d?\d [^ ]+ \d{4}$/
    date_string.gsub!(Regexp.union(MONTH_REPLACE.keys), MONTH_REPLACE)
    DateTime.strptime(date_string, '%d %b %Y')
  end
end

def parse_time(time_string)
  Time.parse(time_string.strip.gsub('.', ':'))
rescue ArgumentError
  nil
end

def parse_characters(chars_string)
  chars_string = chars_string.gsub(/\(.*?\)/, '').gsub(/&nbsp;/, ' ')
  chars = chars_string.split(/ *, */)

  char_map = {}
  unknowns = []

  chars.each do |char_string|
    char_string.strip!

    if (match = char_string.strip.match(%r{
    <a\ href=".*?\?id=(?<id>\d+)".*?>(?<name>.*?)</a>
    }x))
      char_map[match['name'].strip] = CHARS_ID[match['id'].to_i]
    elsif CHARS[char_string]
      char_map[char_string] = CHARS[char_string]
    else
      unknowns << char_string
    end
  end

  [char_map, unknowns]
end

def parse_tz(location_string)
  tz = TIMEZONES[location_string]

  unless tz
    tz = []
    used_tzs = Set[]
    TIMEZONES.each do |region, timezone|
      next unless location_string.downcase.include?(region.downcase) &&
                  !used_tzs.include?(timezone)

      tz << [timezone, region]
      used_tzs << timezone
    end

    if tz.empty?
      tz = nil
    elsif tz.length == 1
      tz = tz[0]
    end
  end

  tz
end

def process_normal_header(match)
  date = parse_date match['date']
  start_time = parse_time match['start_time']
  end_time = parse_time match['end_time']
  characters, unknown_characters = parse_characters match['chara']
  tz = parse_tz match['location']

  complaints = []

  unless date
    complaints << "Непонятная дата: \"#{match['date']}\""
  end

  unless start_time
    complaints << 'Отлупить за кривое время начала: "' +
                  match['start_time'] + '"'
  end

  unless end_time
    complaints << 'Отлупить за кривое время конца: "' +
                  match['end_time'] + '"'
  end

  unless characters
    complaints << 'Отлупить за кривой список персонажей: \"' +
                  match['chara'] + '"'
  end

  # unless tz
  #   complaints << 'Отлупить за кривое место действия: \"' +
  #                 match['location'] + '"'
  # end

  raise HeaderError.new(complaints), 'Bad Header' unless complaints.empty?

  [date, start_time, end_time, characters, unknown_characters, tz]
end

def process_flashback_header(match)
  date = parse_date match['date']
  characters, unknown_characters = parse_characters match['chara']
  tz = parse_tz match['location']

  complaints = []

  unless date
    complaints << "Непонятная дата: \"#{match['date']}\""
  end

  unless characters
    complaints << 'Отлупить за кривой список персонажей: \"' +
                  match['chara'] + '"'
  end

  # unless tz
  #   complaints << 'Отлупить за кривое место действия: \"' +
  #                 match['location'] + '"'
  # end

  raise HeaderError.new(complaints), 'Bad Header' unless complaints.empty?

  [date, characters, unknown_characters, tz]
end

def pick_tz_guess_string(tz)
  if tz == nil
    'не получилось угадать часовой пояс'
  elsif tz.is_a?(Integer)
    'точное совпадение'
  elsif !tz[0].respond_to?(:length)
    'одно неточное совпадение'
  else
    'несколько неточных совпадений'
  end
end

if $PROGRAM_NAME == __FILE__
  file = File.open(OUTPUT_FILE, 'w')

  Net::HTTP.start('codegeass.ru') do |http|
    episodes = []

    link = PURGATORY_LINK
    page = 1
    last_page = false

    until last_page
      response = http.get(link)

      body = response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)

      body.each_line do |line|
        if !last_page && (match = line.match(%r{<h2><span class="item1">Тем<\/span> <span class="item2">[0-9]+ страница ([0-9]+) из ([0-9]+)</span></h2>}))
          last_page = match[1] == match[2]
        end

        if (match = line.match(%r{<td class="tcr"><a href="(http://codegeass.ru/viewtopic.php\?[^"#&]+)(?:[^"]*)">([^<]+)</a>}))
          episode_link = match[1].gsub('&amp;', '&')
          episodes << episode_link
        end
      end

      page += 1
      link = PURGATORY_LINK + "&p=#{page}"
    end

    i = 0

    errors = []
    first = true

    episodes.each do |episode_link|
      topic_id = episode_link[/\?id=([0-9]+)/, 1].to_i
      episode_name = nil

      page = http.get(episode_link)
      body = page.body.encode(Encoding::UTF_8, Encoding::Windows_1251)

      in_header = false
      body.each_line do |line|
        if !episode_name && (match = line.match(%r{<h1><span>(.+)</span></h1>}))
          episode_name = match[1]
        end

        if episode_name && (match = line.match(/<div id="p([0-9]+)" class="post(?: (topicpost|altstyle))?"/))
          in_header = match[2] == 'topicpost'
          next
        end

        if in_header
          if (match = line.gsub(%r{</?strong>}, '').match(%r{
            1\.\ ?Дата:\ *(?<date>.+?)(?:года)?\ *\.?<br\ />.*?
            2\.\ ?Время\ старта:\ *(?<start_time>.+?)\ *\.?<br\ />.*?
            3\.\ ?Время\ окончания:\ *(?<end_time>.+?)\ *\.?<br\ />.*
            5\.\ ?Персонажи:\ *(?<chara>.+?)\ *\.?\ *<br\ />.*
            6\.\ ?Место\ действия:\ *(?<location>.+?)\ *\.?<br\ />.*
          }x))
            i += 1 # TODO: remove

            begin
              (date, start_time, end_time, characters, unknown_characters, tz) =
                process_normal_header(match)
            rescue HeaderError => e
              errors << <<~BAD_HEADER
                Плохое оформление шапки эпизода #{episode_name} #{episode_link}
                #{e.complaints.join("\n")}
              BAD_HEADER
              next
                #{match.named_captures.to_s.gsub(/(".*?"=>".*?"), /, '\1' + "\n ")}
            end

            file.puts "\n------\n\n" unless first
            first = false
            file.puts "Название: #{episode_name}"
            file.puts "Ссылка: #{episode_link}"
            file.puts "Id темы: #{topic_id}"
            file.puts "Дата: #{date.strftime('%d.%m.%Y')}"
            file.puts "Начало: #{start_time.strftime('%H:%M')}"
            file.puts "Конец: #{end_time.strftime('%H:%M')}"
            file.puts "Персонажи: #{characters.values} (#{characters.keys})"
            file.puts 'Неизвестные персонажи (возможно, стоит их добавить): ' \
                 "#{unknown_characters}" if !unknown_characters.empty?
            file.puts "Место: #{match['location']}"
            file.puts "Часовой пояс: #{tz ? tz : 'nil'} (#{pick_tz_guess_string(tz)})"
          elsif (match = line.gsub(%r{</?strong>}, '').match(%r{
            1\.\ ?Дата:\ *(?<date>.+?)(?:года)?\ *\.?<br\ />.*?
            2\.\ ?Персонажи:\ *(?<chara>.+?)\ *\.?<br\ />.*
            3\.\ ?Место\ действия:\ *(?<location>.+?)\ *\.?<br\ />.*
          }x))
            i += 1 # TODO: remove

            begin
              date, characters, unknown_characters, tz =
                process_flashback_header(match)
            rescue HeaderError => e
              errors << <<~BAD_HEADER
                Плохое оформление шапки эпизода #{episode_name} #{episode_link}
                #{e.complaints.join("\n")}
              BAD_HEADER
              next
                #{match.named_captures.to_s.gsub(/(".*?"=>".*?"), /, '\1' + "\n ")}
            end

            file.puts "\n------\n\n" unless first
            first = false
            file.puts "Название: #{episode_name}"
            file.puts "Ссылка: #{episode_link}"
            file.puts "Id темы: #{topic_id}"
            file.puts "Дата: #{date.strftime('%d.%m.%Y')}"
            file.puts "Персонажи: #{characters.values} (#{characters.keys})"
            file.puts 'Неизвестные персонажи (возможно, стоит их добавить): ' \
                 "#{unknown_characters}" if !unknown_characters.empty?
            file.puts "Место: #{match['location']}"
            file.puts "Часовой пояс: #{tz} (#{pick_tz_guess_string(tz)})"
          end
        end
      end
    end
    file.puts "\n------\n\n"
    file.puts errors.join("\n\n")
    file.puts "\n------\n\n"
    pp i
  end
end
