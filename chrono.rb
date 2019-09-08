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

require 'json'
require 'net/http'
require 'time'
require 'uri'

require_relative 'data'

ARC_DIGITS = 2
JS_ARRAY_URI = 'http://forumfiles.ru/files/0010/8b/e4/23203.js'
JS_ARRAY_NAME = File.basename(URI.parse(JS_ARRAY_URI).path)
OUTPUT_FILE = '23203.js'

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
SEARCH_FORUMS = {
  'turn1': 41,
  'turn2': 50,
  'turn3': 58,
  'turn4': 43,
  'turn5': 71,
  'turn6': 84,
  'turn7': 95,
  'turn7_open': 93,
  'personal': 63,
  'past': 70,
  'flashback': 68,
  'flashback_open': 44,
  'purgatory': 89
}.freeze
FORUM_BASE_LINK = 'http://codegeass.ru/viewforum.php'

def tz_shift(datetime, tz)
  tz && datetime ? datetime - Rational(tz, 24) : datetime
end

def pick_arc(date)
  ARCS.reverse_each do |key, value|
    return key if value && date >= value
  end

  0
end

def datetime_from_json_values(date_str)
  date_ary = date_str.split(', ').map(&:to_i)

  date_ary[1] += 1 if date_ary[1] # Stupid JS date month starts from 0

  date_ary
end

def datetime_to_json(date)
  "new Date(#{date.year}, " \
           "#{date.month - 1}, " \
           "#{date.day}, " \
           "#{date.hour}, " \
           "#{date.minute})"
end

def episodes_to_json_by_arc(episodes)
  episodes_grouped = episodes.group_by(&:arc)
  episodes_str = +"var datach = {\n"

  first = true
  episodes_grouped.each do |arc, eps|
    episodes_str << ",\n" unless first
    first = false
    episodes_str << %(  "#{arc}": [\n)
    episodes_str << eps.each
                       .map(&:to_json)
                       .join(",\n")
                       .each_line
                       .map { |line| '    ' + line }
                       .join
    episodes_str << "\n  ]"
  end

  episodes_str << "\n}"

  episodes_str
end

class ChronoEntry
  attr_reader :timeless, :name, :id, :start, :end, :chara, :tz, :arc, :done

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
      elsif line.start_with? 'Дата:'
        init_params[:start] = DateTime.strptime(
          line.delete_prefix('Дата:').strip,
          '%d.%m.%Y'
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

    init_params[:timeless] = !init_params.key?(:end_)

    init_params[:start] = tz_shift(init_params[:start], init_params[:tz])
    init_params[:end_] = tz_shift(init_params[:end_], init_params[:tz])

    init_params[:done] = true

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
                 end_: nil,
                 chara:,
                 tz:,
                 done:)
    @timeless = timeless
    @name = name
    @id = id
    @start = start
    @end = end_ || start
    @chara = chara
    @tz = tz
    @done = done

    @arc = pick_arc(@start)
  end

  def update(timeless: nil,
             name: nil,
             id: nil,
             start: nil,
             end_: nil,
             chara: nil,
             tz: nil,
             done: nil)
    @timeless = timeless unless timeless.nil?
    @name = name unless name.nil?
    @id = id unless id.nil?
    @start = start unless start.nil?
    @end = end_ || start unless end_.nil? && start.nil?
    @chara = chara unless chara.nil?
    @tz = tz unless tz.nil?
    @done = done unless done.nil?
  end

  def ==(other)
    other.is_a?(ChronoEntry) && instance_variables.map do |v|
      send(:instance_variable_get, v) == other.send(:instance_variable_get, v)
    end.all?
  end

  def html
    unless @timeless
      <<~HTML
        <p id="#{@id}"></p>
        <script type="text/javascript">
        setepisode(#{@id},#{@start.day},"#{MONTHS[@start.month]}",#{@start.hour},#{@start.minute},#{@end.hour},#{@end.minute},#{@tz},#{JSON.dump(@name)},0,#{@chara.join(',')},1);
        </script>
      HTML
    else
      char_list = @chara.map do |char_chrono_id|
        %(<a href="http://codegeass.ru/pages/id#{'%02d' % char_chrono_id}">) +
          %(#{CGI.escapeHTML CHARS[char_chrono_id]}</a>)
      end.join(', ')

      <<~HTML
        <div class="chep">
        <div class="chtime1">#{@start.day} #{MONTHS[@start.month]} #{@start.year} года</div>
        <div class="chepname"><a href="http://codegeass.ru/viewtopic.php?id=#{@id}">#{CGI.escapeHTML(@name)}</a></div>
        <div class="chcast">#{char_list}</div>
        <div class="chstat">Завершен</div>
        </div>
      HTML
    end
  end

  def to_json
    <<~JSON.chomp
      {"id": #{@id},
       "start": #{datetime_to_json(@start)},
       "end": #{@end == @start ? 'null' : datetime_to_json(@end)},
       "tz": #{@tz},
       "turn": #{@arc},
       "name": #{JSON.dump(@name)},
       "mode": 0,
       "chara": #{@chara},
       "done": #{@done}
      }
    JSON
  end
end

def read_js_episodes
  Net::HTTP.start('forumfiles.ru') do |http|
    response = http.get(JS_ARRAY_URI)
    json = response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)
    json = json.delete_prefix('var datach = ')
    json.gsub!(/new Date\(((?:-?\d+(?:, )?)+)\)/, '"\1"')
    x = JSON.parse(json)
    x.values.flatten.map do |params|
      ChronoEntry.new(
        name: params['name'],
        id: params['id'],
        start: DateTime.new(*datetime_from_json_values(params['start'])),
        end_: if params['end']
                DateTime.new(*datetime_from_json_values(params['end']))
              end,
        chara: params['chara'],
        tz: params['tz'],
        done: params['done']
      )
    end
  end
end

def parse_datetime(date_string, time_string)
  date_string = date_string.strip

  case date_string
  when /^\d?\d\.\d?\d\.\d\d$/
    format = '%d.%m.%y'
  when /^\d?\d\.\d?\d\.\d{4}$/
    format = '%d.%m.%Y'
  when /^\d?\d [^ ]+ \d{4}$/
    date_string.gsub!(Regexp.union(MONTH_REPLACE.keys), MONTH_REPLACE)
    format = '%d %b %Y'
  end

  return nil unless format

  if time_string
    time_string = time_string.strip.gsub('.', ':')

    if (match = time_string.match(/^\d\d:\d\d:\d\d/))
      format += ' %H:%M:%S'
      time_string = match[0]
    elsif (match = time_string.match(/^\d\d:\d\d/))
      format += ' %H:%M'
      time_string = match[0]
    else
      time_string = nil
    end
  end

  date_string << " #{time_string}" if time_string

  DateTime.strptime(date_string, format)
end

def parse_characters(chars_string)
  chars_string = chars_string.gsub(/\(.*?\)/, '').gsub(/&nbsp;/, ' ')
  chars = chars_string.split(/ *, */)

  char_list = []
  unknowns = []

  chars.each do |char_string|
    char_string.strip!

    if (match = char_string.strip.match(%r{
    <a\ href=".*?\?id=(?<id>\d+)".*?>(?<name>.*?)</a>
    }x))
      # Resolve via chrono id!
      char_list << CHARS_BACK[char_string]
    elsif CHARS_BACK[char_string]
      char_list << CHARS_BACK[char_string]
    else
      unknowns << char_string
    end
  end

  [char_list, unknowns]
end

def parse_tz(location_string)
  tz = location_string[/PND\+(\d+)/, 1]

  tz ||= TIMEZONES[location_string]

  unless tz
    tz = []
    TIMEZONES.each do |region, timezone|
      next if tz.include?(timezone) ||
              !location_string.downcase.include?(region.downcase)

      tz << timezone
    end

    tz = tz.length == 1 ? tz[0] : nil
  end

  tz
end

def parse_episode_page(page)
  normal_header_rx = %r{
    1\.\ ?Дата:\ *(?<date>.+?)(?:года)?\ *\.?<br\ />.*?
    2\.\ ?Время\ старта:\ *(?<start_time>.+?)\ *\.?<br\ />.*?
    3\.\ ?Время\ окончания:\ *(?<end_time>.+?)\ *\.?<br\ />.*
    5\.\ ?Персонажи:\ *(?<chara>.+?)\ *\.?\ *<br\ />.*
    6\.\ ?Место\ действия:\ *(?<location>.+?)\ *\.?<br\ />.*
  }x
  flashback_header_rx = %r{
    1\.\ ?Дата:\ *(?<date>.+?)(?:года)?\ *\.?<br\ />.*?
    2\.\ ?Персонажи:\ *(?<chara>.+?)\ *\.?<br\ />.*
    3\.\ ?Место\ действия:\ *(?<location>.+?)\ *\.?<br\ />.*
  }x

  in_header = false
  params = {}

  page.each_line do |line|
    if params[:done].nil? && params[:name].nil?
      if (match = line.match(
        /^FORUM\.set\('topic', \{ "subject": "(.*?)", "closed": "(\d)",/
      ))
        params[:name] = match[1][/(?:([?\d.-]+)\. )?(.*)/, 2]
        params[:done] = match[2].to_i == 1
        next
      end
    elsif !in_header
      if (match = line.match(/<div id="p([0-9]+)" class="post(?: (topicpost|altstyle))?"/))
        in_header = match[2] == 'topicpost'
        next
      end
    else
      line.gsub!(%r{</?strong>}, '')
      match = line.match(normal_header_rx) || line.match(flashback_header_rx)
    end

    next unless match

    params[:start], params[:end_] =
      if match.names.include?('start_time')
        [parse_datetime(match['date'], match['start_time']),
         parse_datetime(match['date'], match['end_time'])]
      else
        [parse_datetime(match['date'], nil),
         nil]
      end

    params[:chara], unknown_characters = parse_characters match['chara']
    params[:tz] = parse_tz(match['location']) || 0

    params[:start] = tz_shift(params[:start], params[:tz])
    params[:end_] = tz_shift(params[:end_], params[:tz])

    break
  end

  params
end

def update_active_episodes(episodes)
  Net::HTTP.start('codegeass.ru') do |http|
    episodes.each do |episode|
      next if episode.done

      response = http.get("http://codegeass.ru/viewtopic.php?id=#{episode.id}")
      body = response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)
      episode_data = parse_episode_page(body)
      episode.update(episode_data)
    end
  end
end

def get_all_episode_ids
  episode_ids = []

  Net::HTTP.start('codegeass.ru') do |http|
    SEARCH_FORUMS.each_value do |value|
      page = 1
      last_page = false

      until last_page
        response = http.get("#{FORUM_BASE_LINK}?id=#{value}&p=#{page}")

        body = response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)

        body.each_line do |line|
          if !last_page && (match = line.match(%r{
            <h2>
              <span\ class="item1">Тем<\/span>
              \ <span\ class="item2">
                [0-9]+\ страница\ ([0-9]+)\ из\ ([0-9]+)
              </span>
            </h2>
          }x))
            last_page = match[1] == match[2]
          end

          if (match = line.match(%r{
            <div\ class="tclcon">
              .*
              <a\ href="http://codegeass.ru/viewtopic.php\?id=(\d+)">
          }x))
            episode_id = match[1].gsub('&amp;', '&').to_i
            episode_ids << episode_id
          end
        end

        page += 1
      end
    end
  end

  episode_ids
end

def add_new_episodes(episodes)
  known_episode_ids = episodes.each.map(&:id)
  new_episode_ids = get_all_episode_ids - known_episode_ids

  Net::HTTP.start('codegeass.ru') do |http|
    new_episode_ids.each do |episode_id|
      response = http.get("http://codegeass.ru/viewtopic.php?id=#{episode_id}")
      body = response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)

      data = parse_episode_page(body)
      data[:id] = episode_id

      begin
        episode = ChronoEntry.new(data)
      rescue ArgumentError, NoMethodError
        p data
      end
    end
  end
end

def main
  episodes = read_js_episodes
  update_active_episodes(episodes)
  add_new_episodes(episodes)

  episodes.sort_by! do |item|
    arc_sort = item.arc.zero? ? 10**ARC_DIGITS - 1 : item.arc
    arc_sort = format("%0#{ARC_DIGITS}d", arc_sort)
    "#{arc_sort} #{item.start} #{item.name}"
  end

  File.open(OUTPUT_FILE, 'w') do |file|
    file.puts episodes_to_json_by_arc(episodes).encode(Encoding::Windows_1251)
  end
end

main if $PROGRAM_NAME == __FILE__
