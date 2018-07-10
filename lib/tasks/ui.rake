require 'crawler'

namespace :anime do

  MENU_OPTION_1 = Paint['Check for Updates','#F00057']
  MENU_OPTION_2 = Paint['Mark Episodes as seen','#DD0463']
  MENU_OPTION_3 = Paint['Add to Watchlist','#CB086F']
  MENU_OPTION_4 = Paint['Show Watchlist','#B90C7B']
  MENU_OPTION_5 = Paint['Remove from Watchlist','#A71188']
  MENU_OPTION_6 = Paint['Change Show Resolution','#951594']
  MENU_OPTION_7 = Paint['Help','#8319A0']
  MENU_OPTION_8 = Paint['Credits','#711DAC']
  MENU_OPTION_9 = Paint['Exit','#5F22B9']

  task ui: :environment do
    @exit_flag = false
    main_menu
  end

  def main_menu
    CLI::UI::StdoutRouter.enable
    @mainframe = CLI::UI::Frame
    @mainframe.open('Horrible Terminal') do
      CLI::UI::Prompt.ask('Pick a option:') do |handler|
        handler.option(MENU_OPTION_1) { |selection| update_menu }
        handler.option(MENU_OPTION_2) { |selection| mark_ep_menu }
        handler.option(MENU_OPTION_3) { |selection| add_menu }
        handler.option(MENU_OPTION_4) { |selection| print_menu }
        handler.option(MENU_OPTION_5) { |selection| remove_menu }
        handler.option(MENU_OPTION_6) { |selection| resolution_menu }
        handler.option(MENU_OPTION_7) { |selection| print_help }
        handler.option(MENU_OPTION_8) { |selection| credit }
        handler.option(MENU_OPTION_9) { |selection| @exit_flag = true }
      end
    end
    main_menu unless @exit_flag
  end

  def mark_ep_menu
    CLI::UI::Frame.open(Paint['Mark Episodes as seen','#F77669', :bright, :underline], color: CLI::UI::Color.lookup(:red)) do
      CLI::UI::Prompt.ask('Choose Show') do |handler|
        Watchlist.joins(:show).order('title DESC').each do |watch|
          tit = Paint[watch.show.title,'#ff005d']
          handler.option("#{tit}"){ep_count_update_menu(watch); return}
        end
        handler.option('Cancel'){return}
      end
    end
  end

  def update_menu
    max = max_show_title_length
    c = Crawler.new
    CLI::UI::Frame.open(Paint['Available Updates:','#F77669', :bright, :underline], color: CLI::UI::Color.lookup(:yellow)) do
      puts "#{Paint['Title'.ljust(max), '#ff005d']}" +
           " || #{Paint['Episode', '#8700ff']} || " +
           "#{Paint['Torrent Link','#00fff2']}"
      CLI::UI::Frame.divider('')
      Watchlist.all.each do |watch|
        unless watch.up_to_date?
          link = nil
          CLI::UI::Spinner.spin("Fetching torrent link of [#{watch.show.title}] ") do |spinner|
            link = c.get_torrent_link(watch.show.hs_id, watch.last_ep + 1)
          end
          puts "#{Paint[watch.show.title.ljust(max), '#ff005d']} || " +
               "#{Paint[(watch.last_ep + 1).to_s.ljust(7), '#8700ff']} || " +
               "#{Paint[link,'#00fff2']}"
        end
      end
    end
  end

  def ep_count_update_menu(watch)
    input = CLI::UI.ask('Leave empty to increase by one or type number').to_s
    if input.empty?
      watch.last_ep = watch.last_ep + 1
    else
      watch.last_ep = input.to_i
    end
    watch.save
    puts(Paint["Updated. New Last Seen Episode: [#{watch.last_ep}]",:green, :bright])
  end

  def resolution_menu
    max = max_show_title_length
    CLI::UI::Frame.open(Paint['Update Resolution','#F77669', :bright, :underline], color: CLI::UI::Color.lookup(:yellow)) do
      CLI::UI::Prompt.ask('Which show do you want to update ?') do |handler|
        Watchlist.joins(:show).order('title DESC').each do |watch|
          tit = Paint[watch.show.title.ljust(max),'#ff005d']
          handler.option("#{tit}"){ res_update_menu(watch); return }
        end
        handler.option('Cancel'){return}
      end
    end
  end

  def res_update_menu(watchlist_entry)
    CLI::UI::Frame.open(Paint['Update Resolution','#F77669', :bright, :underline], color: CLI::UI::Color.lookup(:green)) do
      CLI::UI::Prompt.ask("Which Resolution do you prefer for #{watchlist_entry.show.title}?") do |handler|
        handler.option('480p') { watchlist_entry.resolution_pref = '480p'; watchlist_entry.save; return }
        handler.option('720p') { watchlist_entry.resolution_pref = '720p'; watchlist_entry.save; return }
        handler.option('1080p'){ watchlist_entry.resolution_pref = '1080p'; watchlist_entry.save; return }
        handler.option('Cancel') { return }
      end
    end
  end

  def max_show_title_length
    max_title_length = 5
    Watchlist.all.each do |watch|
      show_title = watch.show.title
      max_title_length = show_title.length if show_title.length > max_title_length
    end
    max_title_length
  end

  def remove_menu
    max = max_show_title_length
    CLI::UI::Frame.open(Paint['Remove from Watchlist','#F77669', :bright, :underline], color: CLI::UI::Color.lookup(:yellow)) do
      CLI::UI::Prompt.ask('Which show do you want to remove ?') do |handler|
        Watchlist.joins(:show).order('title DESC').each do |watch|
          tit = Paint[watch.show.title.ljust(max),'#ff005d']
          handler.option("#{tit}"){watch.delete; return}
        end
        handler.option('Cancel'){return}
      end
    end
  end

  def print_menu
    max = max_show_title_length
    CLI::UI::Frame.open(Paint['This is your Watchlist','#F77669', :bright, :underline], color: CLI::UI::Color.lookup(:yellow)) do

      puts " #{Paint['#','#ffffff']}  || #{Paint['Title'.ljust(max),'#ff005d']} || #{Paint['Latest Ep','#00fff2']} " +
               "|| #{Paint['Last Seen Ep','#8700ff']} || #{Paint['Release Day','#ED8E31']} ||" +
               " #{Paint['Preferred Resolution','#00fff2']} || #{Paint['Last Release','#44ff95']}"
      CLI::UI::Frame.divider('')
      Watchlist.joins(:show).order('title DESC').each.with_index(1) do |watch,index|
        ind = Paint[index.to_s.ljust(3),'#ffffff']
        tit = Paint[watch.show.title.ljust(max),'#ff005d']
        lep = Paint[watch.last_ep.to_s.ljust(12),'#8700ff']
        rep = Paint[watch.show.ep_count.to_s.ljust(9),'#3986D5']
        rld = Paint[watch.show.release_day.ljust(11),'#ED8E31']
        res = Paint[watch.resolution_pref.ljust(20),'#00fff2']
        wdy = Paint[watch.show.last_release,'#44ff95']
        puts "#{ind} || #{tit} || #{rep} || #{lep} || #{rld} || #{res} || #{wdy}"
      end
    end
  end

  def add_menu
    CLI::UI::Frame.open(Paint['Adding a Show: ', :bright, :underline],failure_text: 'Please check your input', color: CLI::UI::Color.lookup(:magenta)) do
      href = CLI::UI.ask('Type in show name as displayed in the link:').to_s
      show_title = nil
      show_found = false
      CLI::UI::Spinner.spin('Fetching & Creating Show...') do |spinner|
        if Show.exists?(href: href)
          show = Show.find_by(href: href)
          show_found = true
        else
          crawler = Crawler.new
          show = crawler.create_show_from_href(href)
          if show.nil?
            spinner.update_title(Paint['Failed to find Show',:red,:bright])
          else
            show.save!
            show_found = true
          end
        end
        if show_found
          Watchlist.create(show: show, resolution_pref: "720p", last_ep: 0) unless Watchlist.exists?(show: show)
          show_title = show.title
        end
      end
      puts Paint["The show [#{show_title}] was added to your Watchlist.", :green, :bright] unless show_title.nil?
    end
  end

  def print_help
    CLI::UI::Frame.open(Paint['Adding a Show: ', :bright, :underline], color: CLI::UI::Color.lookup(:yellow)) do
      puts "1. Go to: #{Paint['horriblesubs.info/shows', :underline]}"
      puts '2. Pick a Show and click on it'
      puts '3. Copy the show name as displayed in the link'
      puts "    Example: http://horriblesubs.info/shows/#{Paint['berserk', :bright]} (the part right after 'shows/')"
      puts '4. In Menu Option >Add to Watchlist< - paste the name and confirm.'
    end
  end

  def credit
    CLI::UI::Frame.open('Horrible Terminal') do |frame|
      puts 'Made possible by:'
      puts Paint['horriblesubs.info', :red, :bright, :underline]
      puts 'please support them.'
    end
  end

end