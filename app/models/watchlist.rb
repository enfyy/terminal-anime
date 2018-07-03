class Watchlist < ApplicationRecord
  belongs_to :show

  def up_to_date?
    self.last_ep >= show.ep_count
  end
end
