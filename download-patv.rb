#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'open3'
require 'optparse'


showname = "checkpoint"
url = "http://www.penny-arcade.com/patv/show/" + showname
outputdir = "/net/hungryhippo/mnt/storage/Videos/Webseries/"
season_num = 3

shownames = {
  "checkpoint" => "CheckPoint (2011)",
}

shows = []
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: download-patv.rb [options]"
  opts.on("-g","--go-ahead", "Go Ahead") do |v|
    options[:go] = true
  end
end.parse!

doc = Nokogiri::HTML(open(url).read)
#doc = Nokogiri::HTML(File::open('./checkpoint.html', 'r').read)
doc.search('#tabs .subTitle a').each do |tab|
  season_num = /tabSeason(\d+)/.match(tab['id'])[1]

  doc.search('#season-%d' % season_num).each do |season|
    season.search('li').each do |episode| 
      ep_info = {}
      ep_info["title"] = episode.search('strong')[0].content.to_s
      ep_info["url"] = episode.search('a')[0]['href'].to_s
      ep_info["number"] = /CheckPoint Ep. (\d+)/.match(ep_info["title"])[1].to_i
      ep_info["season"] = season_num
      ep_info["filename"] = File::join(
        outputdir,
        shownames[showname],
        "Season %02d" % ep_info["season"],
        "CheckPoint (2011) - S%02dE%02d.flv" % [ep_info["season"],ep_info["number"]] 
      )
      ep_info["exists"] = File::exists?(ep_info["filename"])
      shows.push(ep_info)
    end
  end
end

shows.each do |ep_info|
  if not ep_info["exists"] then
    #doc = Nokogiri::HTML(File::open('./episode.html', 'r').read)
    doc = Nokogiri::HTML(open(ep_info["url"]).read)
    episode_url = doc.search('iframe')[0]['src']

    cmd = ["youtube-dl","-co", ep_info["filename"], episode_url]
    cmd.unshift("echo") unless options[:go]
    puts "Running: " + cmd.join(' ');
    Open3.popen3(*cmd) { |stdin, stdout, stderr, wait_thr| 
      stdin.close
      exit_status = wait_thr.value # Process::Status object returned.
      if exit_status != 0 then
        File::unlink ep_info["filename"]
        throw "Unable to download episode"
      end
    }
    puts "Done fetching %s" % ep_info["filename"]
    exit 0
    break
  end
end
# No episodes left, so exit uncleanly
exit 1
