#!/usr/bin/env ruby

require 'json'
require 'zlib'
require 'open-uri'
require 'net/smtp'
require_relative 'lib/scraper'


module Product
  class Checker

    PRODUCTS = [
      ['https://www.amazon.com/EASTON-BB16S400-BBCOR-ADULT-BASEBALL/dp/B00ZLJ1QGC/ref=sr_1_5?ie=UTF8&qid=1501170697&sr=8-5&keywords=baseball+bats'],
      ['https://www.amazon.com/product/dp/B00ZLJ1QGC'],
      ['https://www.amazon.com/Portable-Wireless-Bluetooth-Speaker-CO2CREA/dp/B071JRLCXT/ref=sr_1_2?s=sporting-goods&ie=UTF8&qid=1502676959&sr=1-2-spons&keywords=sony&psc=1'],
      ['B071JRLCXT']
    ]

    def initialize
      bootstrap
    end

    private

    def bootstrap
      PRODUCTS.each do |product|
        Scraper::Amazon.new(product.first).display_product
      end
    end
  end
end

# run baby
Product::Checker.new
