class Show < ApplicationRecord

  def self.convert_release_day(last_release_input)
    if last_release_input == 'Today'
      date = Date.today
    elsif last_release_input == 'Yesterday'
      date = Date.yesterday
    else
      date = last_release_input.split('/')
      begin
        date = Date.parse("#{date[2]}-#{date[0]}-#{date[1]}")
      rescue StandardError => e
        date = nil
        release_day = nil
      end
    end
    last_release = date
    release_day = Date::DAYNAMES[date.wday] unless date.nil?
    {last_release: last_release, release_day: release_day}
  end
end

