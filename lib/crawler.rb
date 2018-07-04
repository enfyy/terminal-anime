class Crawler
  RES = [480,720,1080]
  URI = 'https://horriblesubs.info'
  EP_URI_EXT = '/api.php?method=getshows&type=show&mode=filter&'

  ##
  # Constructor
  ##
  def initialize
    @schedule = {}
  end

  def episode_link(show_id, ep_num)
    URI + EP_URI_EXT + "showid=#{show_id}&value=#{ep_num}"
  end

  def get_torrent_link(show_id,ep_num)
    doc = get_html_doc(episode_link(show_id, ep_num))
    if doc.css('body').first.content == 'Nothing was found'
      return 'Episode is not on horriblesubs.info :('
    else
      show = Show.find_by(hs_id: show_id)
      wl = Watchlist.find_by(show: show)
      unless show.nil? || wl.nil?
        link = doc.css("##{ep_num}-#{wl.resolution_pref}").css('.hs-torrent-link')&.first.children.first.attr('href')
        if link.nil?
          link = doc.css("##{ep_num}-#{wl.resolution_pref}").css('.hs-magnet-link')&.first.children.first.attr('href')
        end
        return link
      end
    end
  end

  def show_link(href)
    URI + "/shows/#{href}"
  end

  def get_show_id(doc)
    doc.css('.entry-content').css('script').first.content.gsub('var hs_showid = ','')
  end

  def get_show_title(doc)
    doc.css('.entry-title').first.content
  end

  def get_episode_count(doc)
    doc.css('.hs-shows').children.first&.attr('id')
  end

  def get_latest_release_date(doc)
    doc.css('.hs-shows').children.first.css('.rls-date').first.content
  end

  def check_for_new_episode(show)
    doc = get_html_doc(show_link(show.href))
    current_ep = get_episode_count(doc)
    if show.ep_count < current_ep.to_i
      show.ep_count = current_ep.to_i
      show.save!
    end
  end

  ##
  # Method for creating a show in the DB from specified href
  # @param: href -> the href.
  # @return: show object that was created.
  ##
  def create_show_from_href(href)
    doc = get_html_doc(show_link(href))
    release_info = Show.convert_release_day(get_latest_release_date(doc))

    show = Show.new(title:        get_show_title(doc),
                    ep_count:     get_episode_count(doc),
                    hs_id:        get_show_id(doc),
                    last_release: release_info[:last_release],
                    release_day:  release_info[:release_day],
                    href:         href)
    show.save!
    show
  end

  ##
  # Method for going to a link getting the html document and parsing it.
  # @param: browser -> instance of watir browser.
  # @param: url     -> the url.
  # @return: parsed document
  ##
  def get_html_doc(url)
    browser = Watir::Browser.new(:chrome, headless:true)
    browser.goto(url)
    doc = Nokogiri::HTML.parse(browser.html)
    browser.close
    doc
  end

end