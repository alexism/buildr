require File.join(File.dirname(__FILE__), 'sandbox')


module BuildChecks
  def should_pass()
    lambda { check }.should_not raise_error
  end

  def should_fail()
    lambda { check }.should raise_error(RuntimeError, /Checks failed/)
  end

  def check()
    project("foo").task("package").invoke
  end
end


describe Project, " check task" do
  include BuildChecks

  it "should execute last thing from package task" do
    task "action"
    define "foo", :version=>"1.0" do
      package :jar
      task("package").enhance { task("action").invoke }
    end
    lambda { check }.should run_tasks(["foo:package", "action", "foo:check"])
  end

  it "should execute all project's expectations" do
    task "expectation"
    define "foo", :version=>"1.0" do
      check  { task("expectation").invoke } 
    end
    lambda { check }.should run_task("expectation")
  end

  it "should succeed if there are no expectations" do
    define "foo", :version=>"1.0"
    should_pass
  end

  it "should succeed if all expectations passed" do
    define "foo", :version=>"1.0" do
      check { true }
      check { false }
    end
    should_pass
  end

  it "should fail if any expectation failed" do
    define "foo", :version=>"1.0" do
      check
      check { fail "sorry" } 
      check
    end
    should_fail
  end
end


describe Project, "#check" do
  include BuildChecks

  it "should add expectation" do
    define "foo" do
      expectations.should be_empty
      check
      expectations.size.should be(1)
    end
  end

  it "should treat no arguments as expectation against project" do
    define "foo" do
      subject = self
      check do
        it.should be(subject)
        description.should eql(subject.to_s)
      end
    end
    should_pass
  end

  it "should treat single string argument as description, expectation against project" do
    define "foo" do
      subject = self
      check "should be project" do
        it.should be(subject)
        description.should eql("#{subject} should be project")
      end
    end
    should_pass
  end

  it "should treat single object argument as subject" do
    define "foo" do
      subject = Object.new
      check subject do
        it.should be(subject)
        description.should eql(subject.to_s)
      end
    end
    should_pass
  end

  it "should treat first object as subject, second object as description" do
    define "foo" do
      subject = Object.new
      check subject, "should exist" do
        it.should be(subject)
        description.should eql("#{subject} should exist")
      end
    end
    should_pass
  end

  it "should work without block" do
    define "foo" do
      check "implement later"
    end
    should_pass
  end
end


describe BuildChecks::Expectation, " matchers" do
  include BuildChecks

  it "should include Buildr matchers exist and contain" do
    define "foo" do
      check do
        self.should respond_to(:exist)
        self.should respond_to(:contain)
      end
    end
    should_pass
  end

  it "should include RSpec matchers like be and eql" do
    define "foo" do
      check do
        self.should respond_to(:be)
        self.should respond_to(:eql)
      end
    end
    should_pass
  end

  it "should include RSpec predicates like be_nil and be_empty" do
    define "foo" do
      check do
        nil.should be_nil
        [].should be_empty
      end
    end
    should_pass
  end
end


describe BuildChecks::Expectation, " exist" do
  include BuildChecks

  it "should pass if file exists" do
    define "foo" do
      build file("test") { |task| write task.name }
      check(file("test")) { it.should exist }
    end
    should_pass
  end

  it "should fail if file does not exist" do
    define "foo" do
      check(file("test")) { it.should exist }
    end
    should_fail
  end

  it "should not attempt to invoke task" do
    define "foo" do
      file("test") { |task| write task.name }
      check(file("test")) { it.should exist }
    end
    should_fail
  end

  it "should pass if ZIP path exists" do
    write "resources/test"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).path("resources")) { it.should exist }
    end
    should_pass
  end

  it "should fail if ZIP path does not exist" do
    mkpath "resources"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar)) { it.path("not-resources").should exist }
    end
    should_fail
  end

  it "should pass if ZIP entry exists" do
    write "resources/test"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should exist }
      check(package(:jar).path("resources").entry("test")) { it.should exist }
    end
    should_pass
  end

  it "should fail if ZIP path does not exist" do
    mkpath "resources"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should exist }
    end
    should_fail
  end
end


describe BuildChecks::Expectation, " exist" do
  include BuildChecks

  it "should pass if file has no content" do
    define "foo" do
      build file("test") { write "test" }
      check(file("test")) { it.should be_empty }
    end
    should_pass
  end

  it "should fail if file has content" do
    define "foo" do
      build file("test") { write "test", "something" }
      check(file("test")) { it.should be_empty }
    end
    should_fail
  end

  it "should fail if file does not exist" do
    define "foo" do
      check(file("test")) { it.should be_empty }
    end
    should_fail
  end

  it "should pass if directory is empty" do
    define "foo" do
      build file("test") { mkpath "test" }
      check(file("test")) { it.should be_empty }
    end
    should_pass
  end

  it "should fail if directory has any files" do
    define "foo" do
      build file("test") { write "test/file" }
      check(file("test")) { it.should be_empty }
    end
    should_fail
  end

  it "should pass if ZIP path is empty" do
    mkpath "resources"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).path("resources")) { it.should be_empty }
    end
    should_pass
  end

  it "should fail if ZIP path has any entries" do
    write "resources/test"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).path("resources")) { it.should be_empty }
    end
    should_fail
  end

  it "should pass if ZIP entry has no content" do
    write "resources/test"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should be_empty }
      check(package(:jar).path("resources").entry("test")) { it.should be_empty }
    end
    should_pass
  end

  it "should fail if ZIP entry has content" do
    write "resources/test", "something"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should be_empty }
    end
    should_fail
  end

  it "should fail if ZIP entry does not exist" do
    mkpath "resources"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should be_empty }
    end
    should_fail
  end
end


describe BuildChecks::Expectation, " contain(file)" do
  include BuildChecks

  it "should pass if file content matches string" do
    define "foo" do
      build file("test") { write "test", "something" }
      check(file("test")) { it.should contain("thing") }
    end
    should_pass
  end

  it "should pass if file content matches pattern" do
    define "foo" do
      build file("test") { write "test", "something\nor\nanother" }
      check(file("test")) { it.should contain(/or/) }
    end
    should_pass
  end

  it "should pass if file content matches all arguments" do
    define "foo" do
      build file("test") { write "test", "something\nor\nanother" }
      check(file("test")) { it.should contain(/or/, /other/) }
    end
    should_pass
  end

  it "should fail unless file content matchs all arguments" do
    define "foo" do
      build file("test") { write "test", "something" }
      check(file("test")) { it.should contain(/some/, /other/) }
    end
    should_fail
  end

  it "should fail if file content does not match" do
    define "foo" do
      build file("test") { write "test", "something" }
      check(file("test")) { it.should contain(/other/) }
    end
    should_fail
  end

  it "should fail if file does not exist" do
    define "foo" do
      check(file("test")) { it.should contain(/anything/) }
    end
    should_fail
  end
end


describe BuildChecks::Expectation, " contain(directory)" do
  include BuildChecks

  it "should pass if directory contains file" do
    write "resources/test"
    define "foo" do
      check(file("resources")) { it.should contain("test") }
    end
    should_pass
  end

  it "should pass if directory contains glob pattern" do
    write "resources/with/test"
    define "foo" do
      check(file("resources")) { it.should contain("**/t*st") }
    end
    should_pass
  end

  it "should pass if directory contains all arguments" do
    write "resources/with/test"
    define "foo" do
      check(file("resources")) { it.should contain("**/test", "**/*") }
    end
    should_pass
  end

  it "should fail unless directory contains all arguments" do
    write "resources/test"
    define "foo" do
      check(file("resources")) { it.should contain("test", "or-not") }
    end
    should_fail
  end

  it "should fail if directory is empty" do
    mkpath "resources"
    define "foo" do
      check(file("resources")) { it.should contain("test") }
    end
    should_fail
  end

  it "should fail if directory does not exist" do
    define "foo" do
      check(file("resources")) { it.should contain }
    end
    should_fail
  end
end


describe BuildChecks::Expectation, " contain(zip.entry)" do
  include BuildChecks

  it "should pass if ZIP entry content matches string" do
    write "resources/test", "something"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should contain("thing") }
      #check(package(:jar)) { it.entry("resources/test").should contain("thing") }
    end
    should_pass
  end

  it "should pass if ZIP entry content matches pattern" do
    write "resources/test", "something\nor\another"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should contain(/or/) }
      #check(package(:jar)) { it.entry("resources/test").should contain(/or/) }
    end
    should_pass
  end

  it "should pass if ZIP entry content matches all arguments" do
    write "resources/test", "something\nor\nanother"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should contain(/or/, /other/) }
      #check(package(:jar)) { it.entry("resources/test").should contain(/or/, /other/) }
    end
    should_pass
  end

  it "should fail unless ZIP path contains all arguments" do
    write "resources/test", "something"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should contain(/some/, /other/) }
      #check(package(:jar)) { it.entry("resources/test").should contain(/some/, /other/) }
    end
    should_fail
  end

  it "should fail if ZIP entry content does not match" do
    write "resources/test", "something"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should contain(/other/) }
      #check(package(:jar)) { it.entry("resources/test").should contain(/other/) }
    end
    should_fail
  end

  it "should fail if ZIP entry does not exist" do
    mkpath "resources"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).entry("resources/test")) { it.should contain(/anything/) }
      #check(package(:jar)) { it.entry("resources/test").should contain(/anything/) }
    end
    should_fail
  end
end


describe BuildChecks::Expectation, " contain(zip.path)" do
  include BuildChecks

  it "should pass if ZIP path contains file" do
    write "resources/test"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).path("resources")) { it.should contain("test") }
    end
    should_pass
  end

  it "should handle deep nesting" do
    write "resources/test/test2.efx"
    define "foo", :version=>"1.0" do
      package(:jar).include("*")
      check(package(:jar)) { it.should contain("resources/test/test2.efx") }
      check(package(:jar).path("resources")) { it.should contain("test/test2.efx") }
      check(package(:jar).path("resources/test")) { it.should contain("test2.efx") }
    end
    should_pass
  end


  it "should pass if ZIP path contains pattern" do
    write "resources/with/test"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).path("resources")) { it.should contain("**/t*st") }
    end
    should_pass
  end

  it "should pass if ZIP path contains all arguments" do
    write "resources/with/test"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).path("resources")) { it.should contain("**/test", "**/*") }
    end
    should_pass
  end

  it "should fail unless ZIP path contains all arguments" do
    write "resources/test"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).path("resources")) { it.should contain("test", "or-not") }
    end
    should_fail
  end

  it "should fail if ZIP path is empty" do
    mkpath "resources"
    define "foo", :version=>"1.0" do
      package(:jar).include("resources")
      check(package(:jar).path("resources")) { it.should contain("test") }
    end
    should_fail
  end
end