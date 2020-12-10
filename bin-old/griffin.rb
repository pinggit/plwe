#!/usr/bin/ruby
#usage ruby monitor.rb <ip_dddress> 

require 'net/smtp'
require 'net/http'
require 'net/https'
require 'ini'

def every_n_seconds(n) 
  loop do 
    before= Time.now 
    yield 
    interval=n-(Time.now-before) 
    sleep(interval) if interval>0 
  end 
end 

#message template 
$msgstr = <<END_OF_MESSAGE
From: liu jun <nj_monitor@163.com>
To: __NAME__ <__TO__>
Subject: __HOST__ lost connection
Date: __TIME__

__MSG__
--
Liu Jun
END_OF_MESSAGE


$ipstr = <<END_OF_MESSAGE
From: liu jun <nj_monitor@163.com>
To: __NAME__ <__TO__>
Subject: you public ip change to __NEWIP__ 
Date: __TIME__

__MSG__
--
Liu Jun
END_OF_MESSAGE

#mail function
def mail_msg(name, to_addr, msg, hostname)
  msgstr = $msgstr.gsub(/__TIME_/, "#{Time.now}").gsub(/__MSG__/, msg).gsub(/__TO__/, to_addr).gsub(/__NAME__/, name).gsub(/__HOST__/,hostname)
  #puts msgstr
  Net::SMTP.start('smtp.163.com', 25, '163.com','nj_monitor', 'lab123', :login) do |smtp| 
    smtp.send_message(msgstr, 'nj_monitor@163.com', to_addr)
  end  
end  

def mail_msg2(name, to_addr, msg, newip)
  msgstr = $ipstr.gsub(/__TIME_/, "#{Time.now}").gsub(/__MSG__/, msg).gsub(/__TO__/, to_addr).gsub(/__NAME__/, name).gsub(/__NEWIP__/,newip)
  #puts msgstr
  Net::SMTP.start('smtp.163.com', 25, '163.com','nj_monitor', 'lab123', :login) do |smtp| 
    smtp.send_message(msgstr, 'nj_monitor@163.com', to_addr)
  end  
end  


$old_ip = ''
def check_ip
  system("curl ifconfig.me/ip > /tmp/my_ip")
  myip = File.open('/tmp/my_ip').read
  
  if myip != $old_ip
    mail_msg2("liujun", "18936891840@189.cn", "ip changed", myip.chomp)
    $old_ip = myip
  end
end  

INI = Ini.new("./config.ini")

#check every 60 seconds
every_n_seconds(900) do 
  time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  INI['ip_list'].each do |host_name,ip_addr|
    puts "#{host_name}, #{ip_addr}"
    if !host_name.include?"#"
      #if !system("ping -c 1 -t 5 #{ip_addr}") 
      if !system("ping -c 1 -W 5 #{ip_addr}")   
        
        count = 1
        #4.times {count = count + 1 if !system("ping -c 1 -t 5 #{ip_addr}") } #for mac osx 
        4.times {count = count + 1 if !system("ping -c 1 -W 5 #{ip_addr}") }  #for ubuntu
        
        
        if count > 3
          msg = "#{time}: lost connection with #{host_name}, ip: #{ip_addr}, #{count} out of 5"
          puts msg
          #send email, every person one line
          INI['mail_list'].each do |name, mail_addr|
            mail_msg(name, mail_addr, msg, host_name) if !name.include?'#'
          end
        end
        
      end
    end  
  end
  puts "=====finish check =====\n\n"
  check_ip
end