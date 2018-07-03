class Show < ApplicationRecord

  def self.convert_release_day(last_release_input)
    date = last_release_input.split('/')
    date = Date.parse("#{date[2]}-#{date[0]}-#{date[1]}")
    last_release = date
    release_day = Date::DAYNAMES[date.wday]
    {last_release: last_release, release_day: release_day}
  end

end
