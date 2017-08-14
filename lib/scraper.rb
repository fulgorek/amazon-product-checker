require 'mechanize'
require 'uri'
require 'pry'
require 'pry-byebug'

module Scraper
  class Amazon
    attr_accessor :url, :asin, :domain, :cache_dir, :cache_file, :html

    DOMAINS = {
      :global => 'amazon.com',
      :mexico => 'amazon.com.mx',
      :japan  => 'amazon.jp'
    }

    AMAZON_REGEX = /https?:\/\/(?:www\.|)#{DOMAINS.map(&:last).join('|')}\/(?:gp\/product|[^\/]+\/dp|dp)\/([^\/]+)/

    BASE_URL     = "https://www.%s/product/dp/%s"

    CACHE_DIR    = 'cache'

    TTL          = 5 * 60

    REFRESH      = 24 * 60 * 60

    USER_AGENTS  = ['Linux Firefox',
                   'Linux Konqueror',
                   'Linux Mozilla',
                   'Mac Firefox',
                   'Mac Mozilla',
                   'Mac Safari 4',
                   'Mac Safari',
                   'Windows Chrome',
                   'Windows IE 6',
                   'Windows IE 7',
                   'Windows IE 8',
                   'Windows IE 9',
                   'Windows IE 10',
                   'Windows IE 11',
                   'Windows Edge',
                   'Windows Mozilla',
                   'Windows Firefox',
                   'iPhone',
                   'iPad',
                   'Android']

    def initialize(string=nil, market='global')
      @asin, @domain = parse_asin(string), DOMAINS[market.to_sym]
      @url = prepare_url(string)
      check_requirements
      check_cache_dir
    end

    # parse content
    def parse
      parsed_content
    end

    # puts product details to console
    def display_product
      print_stdout
    end

    private

    def prepare_url(string)
      valid_amazon_url?(string) ? string : sprintf(BASE_URL, domain, asin)
    end

    def valid_amazon_url?(url)
      !!url.match(AMAZON_REGEX)
    end

    def save_cache(data)
      if !::File.exist?(cache_file)
        ::File.open(cache_file, 'w') { |f| f.write(Marshal.dump(data)) }
      end
    end

    def cache_file
      @cache_file ||= ::File.join(cache_dir, Digest::MD5.hexdigest(url))
    end

    def load_cached
      Marshal.load(::File.read(cache_file)) if ::File.exist?(cache_file)
    end

    def delete_cached
      ::File.delete(cache_file) if ::File.exist?(cache_file)
    end

    def check_requirements
      if asin.nil?
        puts "Invalid url or ASIN code... Aborting."
        exit
      end
      if domain.nil?
        puts "Invalid country... Aborting."
        exit
      end
    end

    def check_cache_dir
      @cache_dir ||= ::File.join(Dir.pwd, CACHE_DIR)
      if !::File.directory?(cache_dir)
        Dir.mkdir(cache_dir)
      end
    end

    def parse_asin(string=nil)
      string.scan(/[0-9A-Z]{10}/).first
    end

    # prepares Mechanize
    def agent
      @agent ||= Mechanize.new do |m|
        m.user_agent_alias = USER_AGENTS.sample #Randomize to avoid detection!
      end
    end

    def html
      @html ||= !detected_as_robot? ? Nokogiri::HTML(raw.content): nil
    end

    def raw
      @raw ||= agent.get(url)
    end

    def detected_as_robot?
      !raw.at("title").text.match(/Robot Check/).nil?
    end

    # Parsing options
    def title
      html.search("//*[@id='productTitle']").first.text.strip
    end

    def list_price
      list_price = html.search("//span[@id='priceblock_ourprice']").first
      list_price.text.strip.split('-').map{ |x| x.strip }
    end

    def current_price
      price = html.search("//span[@id='priceblock_saleprice']").first || html.search("//span[@id='priceblock_ourprice']")
     price.text.match(/\$/).nil? ? list_price.first : price.text
    end

    def features
      html.search("//*[@id='feature-bullets']/ul/li/span").map{|x| x.text.strip}
    end

    def images
      html.search("//*[@id='altImages']/ul/li/span/span/span/span/span/img").map do |i|
        i.attr('src').gsub('_SS40_', '_SX500_') unless i.attr('src').include?('pixel')
      end.compact
    end

    def reviews
      html.search("//*[@id='acrCustomerReviewText']").text.split(' ')[0].to_i
    end

    def best_seller_rank
      html.search("//*[@id='SalesRank']//text()[2]").text.gsub!(/[^0-9A-Za-z,#]/, ' ').squeeze(' ').strip rescue nil
    end

    def stars
      stars = html.search('//*[@id="reviewSummary"]/div[2]/span/a/span').text.gsub(/[a-zA-Z]/, '').squeeze.split(' ')
      stars.empty? ? 'not rated' : stars
    end

    def add_to_cart
      form   = raw.form_with(:id => 'addToCart')
      button = form.button_with(:id => 'add-to-cart-button')
      @cart  = agent.submit(form, button)
    end

    def go_to_cart
      next_page = @cart.at("#hlb-view-cart-announce")
      @cart = agent.click(next_page)
    end

    def comfirm_add_to_cart
      next_page = @cart.at("input[name='submit.addToCart']")
      @cart = agent.click(next_page)
    end

    def update_cart
      @cart.search('.sc-quantity-textfield').first['value'] = 9999
      form   = @cart.form_with(:id => 'activeCartViewForm')
      button = @cart.search('.sc-update-link').first
      @cart  = agent.submit(form, button)
    end

    # check inventory
    def inventory
      # sleep(0.5) #Half a second
      # add_to_cart
      # sleep(0.5) #Half a second

      # go_to_cart
      # sleep(0.5) #Half a second

      # comfirm_add_to_cart
      # sleep(0.5) #Half a second

      # update_cart
      nil
    end


    def timestamp
      Time.now.to_i
    end

    def wait_for
      if !::File.exist?(cache_file)
        save_cache({:detected => timestamp})
      end
      diff = (timestamp - load_cached[:detected])
      wait = TTL - diff
      if wait > 0
        puts "Detected as robot!, please wait #{wait} seconds to try again."
      else
        delete_cached
      end
      exit
    end

    def must_wait?
      load_cached && load_cached.include?(:detected)
    end

    def parsed_content
      return wait_for if must_wait?
      save_cache(content)
      content
    end

    def content
      @content = load_cached || {
          :url              => url,
          :title            => title,
          :list_price       => list_price,
          :current_price    => current_price,
          :stars            => stars,
          :features         => features,
          :images           => images,
          :reviews          => reviews,
          :best_seller_rank => best_seller_rank,
          :inventory        => inventory,
          :parsed           => timestamp
        }
    end

    def print_stdout
      STDOUT.puts '--' * 50
      STDOUT.puts "title: \t\t#{content[:title]}"
      STDOUT.puts "price: \t\t#{content[:list_price]}"
      STDOUT.puts "stars: \t\t#{content[:stars]}"
      STDOUT.puts "reviews: \t#{content[:reviews]}"
      STDOUT.puts "image url: \t#{content[:images].first}"
      STDOUT.puts "product url: \t#{content[:url]}"
    end
  end
end
