##
# Scraper Class that does all the scraping#
##
require 'logger'

class Scraper

  RES = [480,720,1080]
  URI = 'https://horriblesubs.info'
  SHOW_URI = '/shows/'
  DL_REF_REG = Regexp.new(/(.*)-/)
  EP_REG = Regexp.new(/\A.*-(\d+)\z/)

  ##
  # Constructor
  ##
  def initialize
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.info('[Method-call] initialize')
    @schedule = {}
  end

  ##
  # Method for cheking for new released episodes.
  # @params: hrefs -> hrefs (String) of the shows to be checked (Array)
  # @return: shows (Show) with new released episodes (Array)
  ##
  def check_for_new(hrefs)
    new_episodes = []
    @logger.info('[Method-Call] check_for_new')
    browser = Watir::Browser.new(:chrome, headless:true)

    hrefs.each do |href|
      @logger.info("checking #{href}")
      link = URI + href
      doc = get_html_doc(browser,link)
      entry = doc.css('.hs-shows').css('.release-info').css('tr')
      if entry.first.nil? then entry = retry_get_entry(browser,entry,link) end
      next if entry.first.nil?
      info = entry.first.attr('id')
      ep = EP_REG.match(info)[1].to_i
      s = Show.find_by(href: href)
      if ep == s.ep_count
        @logger.info('[[X]] No new episode out.')
      else
        @logger.info('[[O] There is a new episode out.')
        new_episodes << s
        s.ep_count = ep.to_i
        s.save!
      end
    end
    new_episodes
  end

  ##
  # Method for retrying to get an entry in case Nokogiri fails at parsing for some reason.
  # @params: browser -> an instance of a watir browser (watir browser)
  # @params: entry   -> the entry (Nokogiri node)
  # @params: link    -> link that failed (String)
  # @return: the entry
  ##
  def retry_get_entry(browser,entry,link)
    @logger.info('[Method-Call] retry_get_entry')
    new_entry = entry
    retries = 5
    while new_entry.first.nil? && retries > 0 do
      @logger.info('trying again...')
      show_doc = get_html_doc(browser,link)
      new_entry = show_doc.css('.hs-shows').css('.release-info').css('tr')
      retries -= 1
    end
    if new_entry.first.nil?
      @logger.warn("!!! No Sucess after retries.")
    end
    new_entry
  end

  ##
  # Method for going to a link getting the html document and parsing it.
  # @param: browser -> instance of watir browser.
  # @param: url     -> the url.
  # @return: parsed document
  ##
  def get_html_doc(browser,url)
    @logger.info('[Method-Call] get_html_doc')
    browser.goto(url)
    Nokogiri::HTML.parse(browser.html)
  end

  ##
  # method for retrying getting a title
  ##
  def retry_get_title(browser,tit,link)
    @logger.info('[Method-Call] retry_get_title')
    new_tit = tit
    retries = 5
    while new_tit.first.nil? && retries > 0 do
      @logger.info('trying again...')
      doc = get_html_doc(browser,link)
      new_tit = doc.css('.entry-title')
      retries -= 1
    end
    new_tit
  end

  ##
  # Method for creating a show in the DB from specified href
  # @param: href -> the href.
  # @return: show object that was created.
  ##
  def create_show_from_href(href)
    @logger.info('[Method-Call] create_show_from_href')
    browser = Watir::Browser.new(:chrome, headless:true)
    link = URI + SHOW_URI + href
    doc = get_html_doc(browser,link)
    tit = doc.css('.entry-title')
    if tit.first.nil? then tit = retry_get_title(browser,tit,link) end
    title = tit.first.text
    s = create_show(browser,doc,title,href)
    browser.quit
    s
  end

  ##
  # Method for creating a show entry in the DB.
  # @params: browser -> an instance of a watir browser.
  # @params: link    -> the full link of the show.
  # @params: doc     -> the html document of the site.
  # @params: title   -> the title of the show.
  # @params: href    -> the href of the show.
  # @return: the show object that got created
  ##
  def create_show(browser,doc,title,href)
    @logger.info('[Method-Call] create_show')
    link = URI + SHOW_URI + href
    entry = doc.css('.hs-shows').css('.release-info').css('tr')
    if entry.first.nil? then entry = retry_get_entry(browser,entry,link) end # do some retries
    return nil if entry.first.nil? # still no? ok im out
    info = entry.first.attr('id')
    dl_ref = DL_REF_REG.match(info)[1]
    ep = EP_REG.match(info)[1].to_i
    get_schedule
    wday = @schedule[SHOW_URI + href]
    if wday.nil?
      r_day = 'offseason'
    else
      r_day = Date::DAYNAMES[wday]
    end
    s = Show.new(title: title, dl_ref: dl_ref, href: href, ep_count: ep, release_day: r_day)
    s
  end

  ##
  # Method for scraping every single show off of horriblesubs.info/shows
  # and creating it in the DB.
  ##
  def get_all_shows
    @logger.info('[Method-Call] get_all_shows')
    browser = Watir::Browser.new(:chrome, headless:true)
    shows_link = URI+'/shows/'
    shows_doc = get_html_doc(browser,shows_link)
    show_entries = shows_doc.css('.ind-show').css('a')

    show_array = []
    show_entries.each do |a|
      href = a.attr('href')
      title = a.attr('title')
      href_link = URI+href
      @logger.info("going to #{href_link}")
      show_doc = get_html_doc(browser,href_link)
      unless Show.exists?(href: href)
        s = create_show(browser,href_link,show_doc,title)
        unless s.nil?
          show_array << s
        end
      end
    end
    Show.import show_array
    browser.quit
  end

  def find_release_day(show_ref)
    @logger.info('[Method-Call] find_release_day')
    if @schedule.empty?
      get_schedule
    end
    @schedule[show_ref]
  end

  ##
  # saves the schedule into the hash @schedule[href_of_show]-> [weekday]
  # with weedkay being 7 = sunday, 1 = monday , ...
  ##
  def get_schedule
    @logger.info('[Method-Call] get_schedule')
    browser = Watir::Browser.new(:chrome, headless:true)
    release_link = URI + '/release-schedule'
    release_doc = get_html_doc(browser,release_link)
    browser.quit
    release_entries = release_doc.css('.entry-content').css('.schedule-today-table')
    weekday = 0
    release_entries.each do |table|
      if weekday == 8
        return
      else
        weekday += 1
      end
      shows = table.css('.schedule-page-show')
      shows.each do |s|
        href = s.css('a').attr('href').to_s
        if weekday == 7
          @schedule[href] = 0
        else
          @schedule[href] = weekday
        end
      end
    end
    @schedule
  end



  ##
  # method for collecting all the shownames of the current SeasonShows
  # returns: array of hrefs
  ##
  def get_season_shows
    @logger.info('[Method-Call] get_season_shows')
    browser = Watir::Browser.new(:chrome, headless:true)
    link = URI+'/current-season/'
    name_doc = get_html_doc(browser,link)
    browser.quit
    name_entries = name_doc.css('.ind-show').css('a')
    show_names = Array.new
    name_entries.each do |a|
      show_names << a.attr('href')
    end
    show_names
  end

  ##
  # method for generating the namestring of a show, which is needed for finding the torrent link
  # @param : showname -> name of the show
  # @param : episode  -> epsiode to be downloaded.(String)
  # @param : quality  -> resolution to be downloaded. (int)
  # #
  def generate_dl_class_name(showname,episode,quality)
    @logger.info('[Method-Call] generate_dl_class_name')
    if episode.length == 1
      episode = "0" + episode
    end
    namestring = "#{showname}-#{episode}-#{quality}p"
  end

  ##
  # Method for grabbing the torrent link of the show.
  # @param: show    -> the show object (show)
  # @param: episode -> the episode number to be downloaded (string)
  # @param: quality -> the resolution quality of the show (480,720,1080) (int)
  # @return: the link to the torrent (string)
  ##
  def get_torrent_link(show,episode,quality,timer = 1)
    @logger.info('[Method-Call] get_torrent_link')
    result = nil
    browser = Watir::Browser.new(:chrome ,headless: true)
    link = URI+show.href
    browser.goto(link)
    if episode.length == 1
      ep = "0" + episode
    else
      ep = episode
    end
    browser.input(:class, 'searchbar').send_keys(ep, :enter)
    sleep(timer)
    doc = Nokogiri::HTML.parse(browser.html)
    browser.quit
    if show.ep_count >= episode.to_i
      class_name = generate_dl_class_name(show.dl_ref,episode,quality)
    else
      raise 'That episode is not out yet (or will never be out).'
    end
    @logger.info "searching div with classname: #{class_name}"
    torrent = doc.css('.hs-shows').css("[class~='#{class_name}']").css('.hs-torrent-link').at_css('a')
    unless torrent.nil?
      result = torrent.attr('href')
    end
    if result.nil?
      if timer < 4
        raise 'Can not find the episode even after retries'
      end
      get_torrent_link(show,episode,quality,timer + 1)
    end
    @logger.info("[Success] Look, i found a torrent link : #{result}")
    result
  end

end