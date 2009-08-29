Returning using Rewriting
===

One of the most useful tools provided by Ruby on Rails' ActiveSupport is the #returning method, a simple but very useful implementation of the K Combinator or [Kestrel](http://github.com/raganwald/homoiconic/blob/master/2008-10-29/kestrel.markdown#readme). For example, this:

    def registered_person(params = {})
      person = Person.new(params.merge(:registered => true))
      Registry.register(person)
      person.send_email_notification
      person
    end

Can and should be expressed using #returning as this:

    def registered_person(params = {})
      returning Person.new(params.merge(:registered => true)) do |person|
        Registry.register(person)
        person.send_email_notification
      end
    end

Why? Firstly, you avoid the common bug of forgetting to return the object you are creating:

    def broken_registered_person(params = {})
      person = Person.new(params.merge(:registered => true))
      Registry.register(person)
      person.send_email_notification
    end
    
This creates the person object and does the initialization you want, but doesn't actually return it from the method, it returns whatever #send\_email\_notification happens to return. If you've worked hard to create fluent interfaces you might be correct by accident, but #send\_email\_notification could just as easily return the email it creates. Who knows?

Second, in methods like this as you read from top to bottom you are declaring what the method returns right up front:

    def registered_person(params = {})
      returning Person.new(params.merge(:registered => true)) do # ...
        # ...
      end
    end
      
It takes some optional params and returns a new person. Very clear. And the third reason I like #returning is that it logically clusters the related statements together:

    returning Person.new(params.merge(:registered => true)) do |person|
      Registry.register(person)
      person.send_email_notification
    end

It is very clear that these statements are all part of one logical block. As a bonus, my IDE respects that and it's easy to fold them or drag them around as a single unit. All in all, I think #returning is a big win and I even look for opportunities to refactor existing code to use it whenever I'm making changes.

**DWIM**

All that being said, I have observed a certain bug or misapplication of #returning from time to time. It's usually pretty subtle in production code, but I'll make it obvious with a trivial example. What does this snippet evaluate to?

    returning 1 do |num|
      num = num + 1
    end

This is the kind of thing that sadistic interviewers use in coding quizzes. The answer, of course, is 1, just as the statement says. The fact that you assign 1 to a variable and then overwrite that variable with something else is irrelevant. #returning remembers the *value* assigned to num and returns it. If you have some side-effects on that value, those count. But assignment does nothing to the value.

This may seem obvious, but in my experience it is a subtle point that causes difficulty. Languages with referential transparency escape the confusion entirely, but OO languages like Ruby have this weird thing where we have to keep track of references and labels on references in our head.

Here's something contrived to look a lot more like production code. Here's a contrived example without #returning:

    def working_registered_person(params = {})
      person = Person.new(params.merge(:registered => true))
      if Registry.register(person)
        person.send_email_notification
      else
        person = Person.new(:default => true)
      end
      person
    end
    
And here we've refactored it to use #returning:

    def broken_registered_person(params = {})
      returning Person.new(params.merge(:registered => true)) do |person|
        if Registry.register(person)
          person.send_email_notification
        else
          person = Person.new(:default => true)
        end
      end
    end

Oops! This no longer works as we intended. Overwriting the `person` variable is irrelevant, #returning returns the unregistered new person no matter what. So what's going on here?

One answer is to "blame the victim." Ruby has a certain well-documented behaviour around variables and references. #returning has a certain well-documented behaviour. Any programmer who makes the above mistake is--well--mistaken. Fix the code and set the bug ticket status to Problem Between Keyboard And Chair ("PBKAC").

Another answer is to suggest that the implementation of #returning is at fault. If you write:

    returning ... do |var|
      # ...
      var = something_else
      # ...
    end

You intended to change what you are returning from #returning. So #returning should be changed to do what you meant. I'm on the fence about this. When folks argue that designs should cater to programmers who do not understand the ramifactions of the programming language or of the framework, I usually retort that you cannot have progress and innovation while clinging to familiarity, [an argument I first heard from Jef Raskin](http://weblog.raganwald.com/2008/01/programming-language-cannot-be-better.html "A programming language cannot be better without being unintuitive"). The real meaning of "The Principle of Least Surprise" is that a design should be *internally consistent*, which is not the same thing as *familiar*.

Ruby's existing use of variables and references is certainly consistent. And once you know what #returning does, it remains consistent. However, this design decision isn't really about being consistent with Ruby's implementation, we are debating how an idiom should be designed. I think we have a blank canvas and it's reasonable to at least *consider* a version of #returning that handles assignment to the parameter.

So I did.

**Rewriting #returning**

The [RewriteRails](http://github.com/raganwald/rewrite_rails/tree/master) plug-in adds syntactic abstractions like [Andand](http://github.com/raganwald/rewrite_rails/tree/master/doc/andand.textile "") and [String to Block](http://github.com/raganwald/rewrite_rails/tree/master/doc/string_to_block.md#readme "") to Rails projects [without monkey-patching](http://avdi.org/devblog/2008/02/23/why-monkeypatching-is-destroying-ruby/ "Monkeypatching is Destroying Ruby"). All of the power and convenience, none of the compatibility woes and head-aches.

RewriteRails now includes its own version of #returning that overrides the #returning shipping with ActiveSupport :-o

When RewriteRails is processing source code, it turns code like this:

    def registered_person(params = {})
      returning Person.new(params.merge(:registered => true)) do |person|
        if Registry.register(person)
          person.send_email_notification
        else
          person = Person.new(:default => true)
        end
      end
    end
    
Into this:

    def registered_person(params = {})
      lambda do |person|
        if Registry.register(person)
          person.send_email_notification
        else
          person = Person.new(:default => true)
        end
        person
      end.call(Person.new(params.merge(:registered => true)))
    end

Note that in addition to turning the #returning "call" into a lambda that is invoked immediately, it also makes sure the new lambda returns the `person` variable's contents. So assignment to the variable does change what #returning appears to return.

Like all processors in RewriteRails, #returning is only rewritten in `.rr` files. Existing `.rb` files are not affected, including all code in the Rails framework, so it will never monkey with other people's expectations. #returning can also be disabled for a project if you don't care for it. 

**More**

* [RewriteRails](http://github.com/raganwald/rewrite_rails/tree/master/README.md)
* [returning.rb](http://github.com/raganwald/rewrite_rails/tree/master/lib/rewrite_rails/returning.rb "")