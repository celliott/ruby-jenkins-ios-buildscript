#!/usr/bin/ruby

# requirements
require 'rubygems'
require 'tlsmail'
require 'net/imap'
require "time"
require "tmail"
require File.join(File.dirname(__FILE__),  'tmail_mail_extension.rb')

class GMailHandler
  def initialize
    @CONFIG = {
      :address      => 'build@example.com',
      :smtpServer   => 'smtp.gmail.com',
      :server       => 'gmail.com',
      :password     => 'password',
      :smptPort     => 587,
      :ssl          => true
    }
  end
  
  def sendMail(toAddress, subject, messageBody)
    content = <<EOM
From: #{@CONFIG[:address]}
To: #{toAddress}
Subject: #{subject}  
Date: #{Time.now.rfc2822}  

#{messageBody}

EOM

    Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)  
    Net::SMTP.start(@CONFIG[:smtpServer], @CONFIG[:smtpPort], @CONFIG[:server], @CONFIG[:address], @CONFIG[:password], :login) do |smtp|  
      smtp.send_message(content, @CONFIG[:address], toAddress)
      
    end

end
end