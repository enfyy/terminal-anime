class Watchlist < ApplicationRecord
  belongs_to :show
  require 'crawler'

  def up_to_date?
    c = Crawler.new
    c.check_for_new_episode(show)
    self.last_ep >= show.ep_count
  end


end
