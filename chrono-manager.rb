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

purgatory_link = 'http://codegeass.ru/viewforum.php?id=89'
month_replace = {
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
}

def parse_date(date_string)
  date_string = date_string.strip

  case date_string
  when /^\d?\d\.\d?\d\.\d\d$/
    DateTime.strptime(date_string, '%d.%m.%y')
  when /^\d?\d\.\d?\d\.\d{4}$/
    DateTime.strptime(date_string, '%d.%m.%Y')
  when /^\d?\d [^ ]+ \d{4}$/
    date_string.gsub!(Regexp.union(month_replace.keys), month_replace)
    DateTime.strptime(date_string, '%d %b %Y')
  end
end

if $PROGRAM_NAME == __FILE__
  Net::HTTP.start('codegeass.ru') do |http|
    episodes = []

    link = purgatory_link
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
      link = purgatory_link + "&p=#{page}"
    end

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
            5\.\ ?Персонажи:\ *(?<chara>.+?)\ *\.?<br\ />.*
            6\.\ ?Место\ действия:\ *(?<location>.+?)\ *\.?<br\ />.*
          }x))

            date = parse_date match['date']
            begin
              start_time = Time.parse(match['start_time'].strip.gsub('.', ':'))
              end_time = Time.parse(match['end_time'].strip.gsub('.', ':'))
              characters = match['chara'].split(/, ?/)
              location = match['location']
            rescue ArgumentError
              puts <<~EOS
              Плохое оформление шапки эпизода #{episode_name} #{episode_link}
              #{match.named_captures.to_s.gsub(/(".*?"=>".*?"), /, '\1' + "\n ")}
              EOS
              next
            end

            puts episode_name
            puts "Дата: #{date.strftime('%d.%m.%Y')}"
            puts "Начало: #{start_time.strftime('%H:%M')}"
            puts "Конец: #{end_time.strftime('%H:%M')}"
            puts "Персонажи: #{characters}"
            puts "Место: #{location}"
          elsif (match = line.gsub(%r{</?strong>}, '').match(%r{
            1\.\ ?Дата:\ *(?<date>.+?)(?:года)?\ *\.?<br\ />.*?
            2\.\ ?Персонажи:\ *(?<chara>.+?)\ *\.?<br\ />.*
            3\.\ ?Место\ действия:\ *(?<location>.+?)\ *\.?<br\ />.*
          }x))

            begin
              date_string = match['date'].strip
              case date_string
              when /^\d?\d\.\d?\d\.\d\d$/
                date = DateTime.strptime(date_string, '%d.%m.%y')
              when /^\d?\d\.\d?\d\.\d{4}$/
                date = DateTime.strptime(date_string, '%d.%m.%Y')
              when /^\d?\d [^ ]+ \d{4}$/
                date_string.gsub!(Regexp.union(month_replace.keys), month_replace)
                date = DateTime.strptime(date_string, '%d %b %Y')
              else
                raise ArgumentError
              end

              characters = match['chara'].split(/, ?/)
              location = match['location']
            rescue ArgumentError
              puts <<~BAD_HEADER
                Плохое оформление шапки эпизода #{episode_name} #{episode_link}
                #{match.named_captures.to_s.gsub(/(".*?"=>".*?"), /, '\1' + "\n ")}
              BAD_HEADER
              next
            end

            puts episode_name
            puts "Дата: #{date.strftime('%d.%m.%Y')}"
            puts "Персонажи: #{characters}"
            puts "Место: #{location}"
          end
        end
      end
      puts
    end
  end
end