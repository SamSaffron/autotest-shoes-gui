unless defined? Shoes

module Autotest::Shoes 
  require 'drb'
  require 'fileutils'

  class Test
    include DRbUndumped 

    def initialize(file, test, stacktrace) 
      @file = file
      @test = test 
      @stacktrace = stacktrace
    end

    attr_accessor :file
    attr_accessor :test 
    attr_accessor :stacktrace

  end 
  
  class Notifier    

    def rails_root
      FileUtils.pwd
    end

    # array of failed tests ... 
    def failed_tests
      @failed_tests
    end 

    def last_change 
      @last_change
    end 

    def bad_tests(at) 
      @last_change = Time.now
      @failed_tests = []
      
      i = 0
      stacks = at.results.split(/^\s+(\d+)\)/m) 
      stacks.reject! {|item| !(item =~ /^\s+(Error|Failure):/)} 

      at.files_to_test.each do |file,tests| 
        tests.each do |test| 
          @failed_tests << Test.new(file, test, stacks[i])
          i += 1
        end
      end
    
    end

    def all_good
      @last_change = Time.now
      @failed_tests = nil 
    end

  end

  notifier = Notifier.new
  
  Thread.new do 
    DRb.start_service 'druby://127.0.0.1:98371', notifier
    DRb.join_thread
  end 

  Autotest.add_hook :red do |at|
    notifier.bad_tests(at) 
  end 

  Autotest.add_hook :green do |at| 
    notifier.all_good 
  end 

  system 'pwd' 

  Thread.new do 
    system "shoes #{__FILE__}" 
  end 
end 

else 
# Here is the shoes app ... 
require 'drb'

Shoes.app do 

  def update_stats(tests)

    unless tests     
      return stack do 
        tagline strong("Peace on earth - all tests passed!"), :stroke => green
      end
    end

    stack do 
      tests_have = (tests.count==1 ? "test has":"tests have") 
      tagline strong("#{tests.count} #{tests_have} failed!"), :stroke => "#ae4116"
      prev_file = nil 
      tests.each do |test|

        if prev_file != test.file 
          para test.file, 
            " ", 
            link(">>", :click => Proc.new { system "gvim #{@@rails_root}/#{test.file}" })  
        end 
        prev_file = test.file

        p1 = para 
        p2 = para test.stacktrace
        p2.hide if tests.count > 10 
        p1.text = 
          link( 
            test.test, :click => 
            Proc.new { p2.hidden ? p2.show : p2.hide }
          )
      end
    end
  end 

  drb = DRbObject.new(nil, 'druby://127.0.0.1:98371')
  prev_date = nil 
  s = nil 
  every(1) do 
    if prev_date != drb.last_change
      @@rails_root ||= drb.rails_root.to_s
      prev_date = drb.last_change
      tests = nil 
      tests = Array.new(drb.failed_tests) if drb.failed_tests
      s.clear if s 
      s = update_stats(tests)
    end
  end
end



end
