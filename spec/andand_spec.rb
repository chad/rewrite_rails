require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper.rb'))

describe RewriteRails::Andand do
  
  before(:each) do
    
    RewriteRails::Rewrite.define_gensym do
      :__TEMP__
    end
    
    @it = RewriteRails::Andand.new
      
  end
  
  it "should not change normal method invocations" do
    @it.process(RewriteRails.clean { foo.bar }).to_a.should == RewriteRails.clean { foo.bar }.to_a
    @it.process(RewriteRails.clean { foo.bar(5) }).to_a.should == RewriteRails.clean { foo.bar(5) }.to_a
    @it.process(RewriteRails.clean { 5.bar(5) }).to_a.should == RewriteRails.clean { 5.bar(5) }.to_a
    @it.process(RewriteRails.clean { 5.bar(5) do; end }).to_a.should == RewriteRails.clean { 5.bar(5) do; end }.to_a
  end
  
  describe "current functionality" do
  
    it "should rewrite an empty method invocation" do
      @it.process(RewriteRails.clean { foo.andand.bar }).to_a.should == RewriteRails.clean do
        (__TEMP__ = foo and __TEMP__.bar)
      end.to_a
    end

    it "should rewrite a method invocation with a parameter" do
      @it.process(RewriteRails.clean { foo.andand.bar(5) }).to_a.should == RewriteRails.clean do
        (__TEMP__ = foo and __TEMP__.bar(5))
      end.to_a
    end

    it "should rewrite a method invocation with a block" do
      @it.process(RewriteRails.clean { foo.andand.bar { |x| x } }).to_a.should == RewriteRails.clean do
        (__TEMP__ = foo and __TEMP__.bar { |x| x } )
      end.to_a
    end

    it "should rewrite a method invocation with a block passed" do
      @it.process(RewriteRails.clean { foo.andand.bar(&:x) }).to_a.should == RewriteRails.clean do
        (__TEMP__ = foo and __TEMP__.bar(&:x) )
      end.to_a
    end

    it "should rewrite a method invocation with a parameter and a block passed" do
      @it.process(RewriteRails.clean { foo.andand.bar(5, &:x) }).to_a.should == RewriteRails.clean do
        (__TEMP__ = foo and __TEMP__.bar(5, &:x) )
      end.to_a
    end
  
  end
  
  describe "future optimizations" do
    
    it "should not create a temporary for a variable lookup" do
      pending "unimplemented"
      foo = nil
      @it.process(RewriteRails.clean { foo.andand.bar }).to_a.should == RewriteRails.clean do
        (foo and foo.bar)
      end.to_a
    end
    
    it "should NOOP for a truthy literal" do
      pending "unimplemented"
      @it.process(RewriteRails.clean { 42.andand.bar }).to_a.should == RewriteRails.clean do
        42.bar
      end.to_a
    end
    
    it "should NOOP for a falsy literal" do
      pending "unimplemented"
      @it.process(RewriteRails.clean { nil.andand.bar }).to_a.should == RewriteRails.clean do
        nil
      end.to_a
    end
    
  end
  
end