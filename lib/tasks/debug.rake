namespace :debug do
  task run: :environment do
    require 'crawler'
    c = Crawler.new
    c.get_torrent_link(97,440)
  end
end