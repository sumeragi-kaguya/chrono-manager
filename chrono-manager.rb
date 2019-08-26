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

    pp episodes
  end
end
