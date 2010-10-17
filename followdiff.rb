require 'rubygems'
require 'twitter'
require 'pp'
require 'json'
require 'getoptlong'
require 'fileutils'
require 'dm-core'


#DataMapper::Logger.new($stdout, :debug)

DataMapper.setup(:default,"sqlite3://#{Dir.pwd}/twitterdata.sqlite3")

class FollowerLink
  include DataMapper::Resource
  
  property :id,         Serial
  property :ownerid,    Integer, :required => true
  property :userid,     Integer, :required => true
  property :firstseen,  DateTime, :required => true
  property :lastseen,   DateTime
end

class UsernameCache 
  include DataMapper::Resource
  
  property :userid,     Integer, :key => true
  property :username,   String,  :required => true
  property :saved,      DateTime, :required => true
end

#DataMapper.auto_migrate!


def save_followers(followers)
  FileUtils.mkdir_p('followers')
  local_filename = File.join('followers',String(Time.now.utc.to_i) + '.txt')
  File.open(local_filename, 'w') do |f|
    followers.each do |userid|
      f.puts userid
    end
  end
end

def save_friends(friends)
  FileUtils.mkdir_p('friends')
  local_filename = File.join('friends',String(Time.now.utc.to_i) + '.txt')
  File.open(local_filename, 'w') do |f|
    friends.each do |userid|
      f.puts userid
    end
  end
end

def fetchusername(id)
  userobj = UsernameCache.get(id)
  username = ''
  begin
      if userobj 
      username = userobj.username
    else
      begin
        username = $client.user(id)["screen_name"]
      rescue Twitter::NotFound  
        username = "unkownuser" + id.to_s
      end
      userobj = UsernameCache.new(
        :userid=>id,
        :username=>username,
        :saved=>Time.now.utc
      )
      userobj.save()
    end
  rescue
    username = ''
  end
  username
end


opts = GetoptLong.new(
      [ '--consumer-token','-c', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--consumer-secret','-s', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--access-token','-a', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--access-secret','-S', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--help', GetoptLong::NO_ARGUMENT ],
      [ '-i', GetoptLong::NO_ARGUMENT ],
      [ '-d', GetoptLong::OPTIONAL_ARGUMENT ],
      [ '-f', GetoptLong::REQUIRED_ARGUMENT ]
    )

#replace this with your settings.

$consumer_token = ''
$consumer_secret = ''
$ac_token = ''
$ac_secret = ''
if File::exists?("settings.rb")
  load 'settings.rb'
end
$debug = false  
$infile = false

opts.each do |opt, arg|
  case opt
  when '--help'
    usage
    exit 0
  when '-d'
    $debug = true
  when '-f'
    $infile = arg
  when '-i'
    $infile = 'stdin'
  when '--consumer-token'
    $consumer_token = arg
  when '--consumer-secret'
    $consumer_secret = arg
  when '--access-token'
    $ac_token = arg
  when '--access-secret'
    $ac_secret = arg
  end
end

oauth = Twitter::OAuth.new($consumer_token, $consumer_secret)
oauth.authorize_from_access($ac_token, $ac_secret)

$client = Twitter::Base.new(oauth)
$me = $client.verify_credentials

followers = $client.follower_ids(:user_id=>$me["user_id"])
friends = $client.friend_ids(:user_id=>$me["user_id"])
save_followers(followers)
save_friends(friends)


puts "I'm following not following me back: #{(friends-followers).count}"
puts "Following me I'm not following back: #{(followers-friends).count}"

if $infile
  oldfollowers = Array.new
  if $infile == 'stdin'
    $stdin.each_line do |line|
      oldfollowers << Integer(line.chomp)
    end
  else
    File.open($infile, 'r') {|f| f.each_line{|line| oldfollowers << Integer(line.chomp) }}
  end
  
  common = followers & oldfollowers
  puts "old count: #{oldfollowers.count}"
  puts "new count: #{followers.count}"
  
  puts "common: #{common.count}"
  
  newfollowers = followers - common
  lostfollowers = oldfollowers - common
  puts " "
  puts "new:"
  newfollowers.each do |f|
    puts fetchusername(f)
  end
  puts " "
  puts "lost:"
  lostfollowers.each do |f|
    puts fetchusername(f)
  end 
  

end 



