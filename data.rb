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

JS_CHARACTERS_URI = 'http://codegeass.ru/pages/chronology'

def read_js_characters
  chara_map = nil

  Net::HTTP.start('codegeass.ru') do |http|
    response = http.get(JS_CHARACTERS_URI)
    body = response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)

    chara_array = nil

    body.each_line do |line|
      line.chomp!
      chara_array = line[/^var allnames = new Array\((.*)\);$/, 1]
      break if chara_array
    end

    chara_array.gsub!(/(^|[^\\])'/, '\1"')
    chara_array = JSON.parse("[#{chara_array}]")
    chara_map = chara_array.drop(1).map.with_index(1) { |x, i| [i, x] }.to_h
  end

  chara_map
end

ARCS = {
  0 => nil,
  1 => DateTime.new(2017, 7, 14, 23),
  2 => DateTime.new(2017, 9, 1),
  3 => DateTime.new(2017, 10, 1),
  4 => DateTime.new(2017, 10, 16),
  5 => DateTime.new(2017, 11, 1),
  6 => DateTime.new(2017, 12, 1),
  7 => DateTime.new(2018, 1, 1)
}.freeze

CHARS = read_js_characters.freeze
CHARS_BACK = CHARS.invert.merge(
  'Arthur Lehman' => 289,
  'C.C' => 4,
  'C.C.' => 4,
  'Emiya Atsuko' => 216,
  'Emmerich Meyer' => 292,
  'Frederic Lennox' => 268,
  'Lakshmi Trishna Neru' => 269,
  'M.M' => 258,
  'M.M.' => 258,
  'N.N' => 64,
  'N.N.' => 64,
  'Wayne Stranszberg' => 301,
  'Алекс Кросс' => 26,
  'Алексей Ланской' => 253,
  'Анжела Лаврова' => 129,
  'Анна Клемент' => 87,
  'Аня Альстрейм' => 33,
  'Астрид Гудбранд' => 302,
  'Бен Кламски' => 278,
  'Владимир Макаров' => 29,
  'Габриэлла Британская' => 299,
  'Габриэль Паттел' => 270,
  'Гвиневра су Британия' => 36,
  'Джино Вайнберг' => 72,
  'Дункан' => 71,
  'Зеро' => 1,
  'Иван Полозов' => 265,
  'Сумераги Кагуя' => 49,
  'Каллен Кодзуки' => 3,
  'Каллен Козуки' => 3,
  'Карин нэ Британия' => 189,
  'Карл Воллен' => 177,
  'Кассандра Бота' => 162,
  'Ким Сайрумов' => 300,
  'Кловис ла Британия' => 245,
  'Командующий Кобра' => 270,
  'Константин Уайт' => 297,
  'Куруруги Сузаку' => 5,
  'Лелуш' => 1,
  'Ллойд Асплунд' => 10,
  'Лучиано Брэдли' => 167,
  'Марианна Британская' => 273,
  'Марианна ви Британия' => 273,
  'Марика Сореси' => 259,
  'Мария Вуйцик' => 257,
  'Миллай' => 2,
  'Mima' => 258,
  'Митт Траун' => 103,
  'Наннали' => 7,
  'Наннали Британская' => 7,
  'Одиссей ю Британия' => 48,
  'Павел Романов' => 188,
  'Пьер Мао' => 305,
  'Пьер Эжен Мао' => 305,
  'Ренли' => 11,
  'Ренли Британский' => 11,
  "Рианнон О'Нейл" => 58,
  'Рубен Эшфорд' => 236,
  'Сесиль Круми' => 148,
  'Сольф Кимбли' => 243,
  'Соня Эльтнова' => 277,
  'Станислав Мальченко' => 90,
  'Тянцзы' => 47,
  'Фэйт Уоллер' => 128,
  'Чарльз Британский' => 74,
  'Чарльз зи Британия' => 74,
  'Химера' => 282,
  'Шарам' => 283,
  'Шарли Фенетт' => 6,
  'Элис Блекберри' => 239,
  'Элис' => 239,
  'Эмия Атсуко' => 216
).freeze

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
