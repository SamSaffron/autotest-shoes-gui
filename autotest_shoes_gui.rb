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

Shoes.app :height => 450, :width => 500, :resizable => true, :title => "autotest" do 

  def update_stats(stack, tests)
    

    unless tests     
        stack.clear do 
          tagline strong("Peace on earth\nAll tests passed!"), 
            :stroke => green, :left => 150, :top => 120
        end 
        return
    end

    stack.clear do 
      tests_have = (tests.count==1 ? "test has":"tests have") 
      stack do
        background linen 
        tagline strong("#{tests.count} #{tests_have} failed!"), :stroke => "#ae4116", :left => 120
      end
      prev_file = nil 
      tests.each do |test|

        if prev_file != test.file 
          para test.file, 
            " ", 
            link(">>", :click => Proc.new { system "gvim #{@rails_root}/#{test.file}" })  
        end 
        prev_file = test.file

        p1 = para 
        p2 = para test.stacktrace
        p2.hide
        p1.text = 
          link( 
            test.test, :click => 
            Proc.new { p2.hidden ? p2.show : p2.hide }
          )
        p2.show if tests.count < 10 
      end
    end
  end 
   
  @top_stack = stack :height => 400, :scroll => true, :margin_top => 5

  drb = DRbObject.new(nil, 'druby://127.0.0.1:98371')
  prev_date = nil 
  s = nil 
  every(1) do 
    if prev_date != drb.last_change
      @rails_root ||= drb.rails_root.to_s
      prev_date = drb.last_change
      tests = nil 
      tests = Array.new(drb.failed_tests) if drb.failed_tests
      update_stats(@top_stack, tests)
    end
  end
  
  @bottom_stack = stack :height => 45, :attach => Window do
    background "#DDD"
    flow do 
      button "Restart Site", :margin => 10 do 
        system "touch #{@rails_root}/tmp/restart.txt"
      end
      button "Refresh Schema", :margin => 10 do 
        system "cd #{@rails_root} && rake db:backup:redo"
      end
    end 
  end

  @height = 0
  every(1) do
    unless app.height == @height
      @top_stack.append do 
        style(:height => app.height - 45)
      end 
      @bottom_stack.append do
        style(:top => app.height-45)
      end
      @height = app.height
    end
  end


end



end
