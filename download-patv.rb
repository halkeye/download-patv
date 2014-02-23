#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'open3'
require 'optparse'
require 'youtube_it'

showname = "checkpoint"
url = "http://www.penny-arcade.com/patv/show/" + showname
outputdir = "/net/hungryhippo/mnt/storage/Videos/Webseries/"
season_num = 3

client = YouTubeIt::Client.new

shows = {
  "checkpoint" => {
    :name => "CheckPoint (2011)",
    :tvdbid => 262743
  }
}

episodes = []
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: download-patv.rb [options]"
  opts.on("-g","--go-ahead", "Go Ahead") do |v|
    options[:go] = true
  end
  opts.on("-d","--debug", "use local files for debugging purposes") do |v|
    options[:debug] = true
  end
end.parse!

options[:debug] = true if ENV['PATV_DEBUG']

if options[:debug]
  doc = Nokogiri::HTML(File::open('./checkpoint.html', 'r').read)
else
  doc = Nokogiri::HTML(open(url).read)
end
doc.search('#tabs .subTitle a').each do |tab|
  season_num = /tabSeason(\d+)/.match(tab['id'])[1]

  doc.search('#season-%d' % season_num).each do |season|
    season.search('li').each do |episode| 
      ep_info = {
        :show => shows[showname]
      }
      ep_info[:title] = episode.search('strong')[0].content.to_s
      ep_info[:url] = episode.search('a')[0]['href'].to_s
      ep_info[:episode] = /CheckPoint Ep. (\d+)/.match(ep_info[:title])[1].to_i
      ep_info[:season] = season_num
      ep_info[:filename] = File::join(
        outputdir,
        ep_info[:show][:name],
        "Season %02d" % ep_info[:season],
        "CheckPoint (2011) - S%02dE%02d.flv" % [ep_info[:season],ep_info[:episode]] 
      )
      ep_info[:nfofile] = File::join(
        outputdir,
        ep_info[:show][:name],
        "Season %02d" % ep_info[:season],
        "CheckPoint (2011) - S%02dE%02d.nfo" % [ep_info[:season],ep_info[:episode]] 
      )
      ep_info[:exists] = File::exists?(ep_info[:filename]) && File::exists?(ep_info[:nfofile])
      episodes.push(ep_info)
    end
  end
end

episodes.each do |ep_info|
  if not ep_info[:exists] then
    if options[:debug]
      doc = Nokogiri::HTML(File::open('./episode.html', 'r').read)
    else
      doc = Nokogiri::HTML(open(ep_info[:url]).read)
    end
    episode_url = doc.search('iframe')[0]['src']
    video = client.video_by(episode_url)

    ep_info[:year] = video.published_at.year 
    ep_info[:uniqueid] = video.unique_id
    ep_info[:plot] = video.description
    match = video.description.match(/^CheckPoint, Season \d+, Episode \d+ -\s*(.*)$/)
    ep_info[:title] = match[1] if match

    ep_info[:premiered] = video.published_at
    ep_info[:aired] = video.published_at
    ep_info[:studio] = "YouTube"

    cmd = ["youtube-dl","-co", ep_info[:filename], episode_url]
    cmd.unshift("echo") unless options[:go]
    unless File.exists?(ep_info[:filename]) || options[:debug]
      puts "Running: " + cmd.join(' ');
      Open3.popen3(*cmd) { |stdin, stdout, stderr, wait_thr| 
        stdin.close
        exit_status = wait_thr.value # Process::Status object returned.
        if exit_status != 0 then
          File::unlink ep_info[:filename]
          throw "Unable to download episode"
        end
      }
    end

    ep_info[:nfofile] = '/dev/stdout' if options[:debug]
    if !File.exists?(ep_info[:nfofile]) || options[:debug]
      File.open(ep_info[:nfofile], 'w') do |f|
        f.puts '<?xml version="1.0" encoding="utf-8" standalone="yes" ?>'
        f.puts "<tvshow>"
        f.puts "  <title>#{ep_info[:title]}</title>"
        f.puts "  <season>#{ep_info[:season]}</season>"
        f.puts "  <episode>#{ep_info[:episode]}</episode>"
        f.puts "  <uniqueid>#{ep_info[:uniqueid]}</uniqueid>"
        f.puts "  <plot><![CDATA[#{ep_info[:plot]}]]></plot>"
        f.puts "  <premiered>#{ep_info[:premiered].strftime('%04Y-%02m-%02d')}</premiered>"
        f.puts "  <aired>#{ep_info[:aired].strftime('%04Y-%02m-%02d')}</aired>"
        f.puts "  <studio>#{ep_info[:studio]}</studio>"
        f.puts "  <tvdbid>#{ep_info[:show][:tvdbid]}</tvdbid>"
        f.puts "  <year>#{ep_info[:year]}</year>"
        f.puts "</tvshow>"
      end
    end

    puts "Done fetching %s" % ep_info[:filename]
    sleep 30
  end
end
# No episodes left, so exit uncleanly
exit 1
