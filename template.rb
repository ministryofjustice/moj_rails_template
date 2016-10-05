gem 'govuk_elements_rails'
gem 'govuk_frontend_toolkit'
gem 'govuk_template'
gem 'high_voltage'
gem 'lograge'
gem 'pry-rails'

gem_group :production do
  gem 'rails_12factor'
end

gem_group :development, :test do
  gem 'launchy'
  gem 'mutant-rspec'
  gem 'pry-byebug'
  gem 'rspec-rails'
end

gem_group :test do
  gem 'brakeman'
  gem 'capybara'
  gem 'database_cleaner'
  gem 'factory_girl_rails'
  gem 'fuubar'
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'shoulda'
  gem 'simplecov', require: false
  gem 'simplecov-rcov'
end

rakefile('quite.rake') do
  <<-TASK.strip_heredoc
    if defined? RSpec
      require 'rspec/core/rake_task'

      task(:spec).clear
      RSpec::Core::RakeTask.new(:spec) do |t|
        t.verbose = false
      end
    end
  TASK
end

rakefile('brakeman.rake') do
  <<-TASK.strip_heredoc
    task :brakeman do
      sh <<end
    mkdir -p tmp && \
    (brakeman --no-progress --quiet --output tmp/brakeman.out --exit-on-warn && \
    echo "no warnings or errors") || \
    (cat tmp/brakeman.out; exit 1)
    end
    end

    if %w(development test).include? Rails.env
      task(:default).prerequisites << task(:brakeman)
    end
  TASK
end

rakefile('mutant.rake') do
  <<-'TASK'.strip_heredoc
    task :mutant => :environment do
      classes_to_mutate.each do |klass|
        vars = 'NOCOVERAGE=true'
        flags = '--use rspec'
        unless system("#{vars} mutant #{flags} #{klass}")
          raise 'Mutation testing failed'
        end
      end
    end

    task(:default).prerequisites << task(:mutant)

    private

    def classes_to_mutate
      Rails.application.eager_load!
      ApplicationRecord.descendants.map(&:name)
    end
  TASK
end

rakefile('rubocop.rake') do
  <<-TASK.strip_heredoc
    if Gem.loaded_specs.key?('rubocop')
      require 'rubocop/rake_task'
      RuboCop::RakeTask.new

      task(:default).prerequisites << task(:rubocop)
    end
  TASK
end

version = ask('Ruby version to use? (this gets used in the Dockerfile, so make sure there is a corresponding MoJ image)')

file('circle.yml') do
  <<-CIRCLE.strip_heredoc
  machine:
    ruby:
      version: #{version}

  test:
    override:
      - bundle exec rake
  CIRCLE
end

file('.ruby_version') do
  version
end

file('Dockerfile') do
  <<-DOCKER.strip_heredoc
    FROM ministryofjustice/ruby:#{version}-webapp-onbuild

    ENV PUMA_PORT 3000

    RUN touch /etc/inittab

    RUN apt-get update && apt-get install -y

    EXPOSE $PUMA_PORT

    RUN bundle exec rake assets:precompile RAILS_ENV=production \
      SECRET_KEY_BASE=required_but_does_not_matter_for_assets

    ENTRYPOINT ["./run.sh"]
  DOCKER
end

file('run.sh') do
  <<-'RUN'
    #!/bin/bash
    cd /usr/src/app
    case ${DOCKER_STATE} in
    migrate)
        echo "Running migrate"
        bundle exec rake db:migrate
        ;;
    create)
        echo "Running create"
        bundle exec rake db:create
        bundle exec rake db:migrate
        bundle exec rake db:seed
        ;;
    esac

    echo "Running app"
    bundle exec puma -p $PUMA_PORT
  RUN
end

run 'chmod 755 run.sh'

year = ask('Enter the year for copyright in the license file')
file('LICENSE') do
  <<-LICENSE.strip_heredoc
    The MIT License (MIT)

    Copyright (c) #{year} Ministry of Justice

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
  LICENSE
end

# I thought about reading it in from a supporting file. However, I didn't want
# users to *need* to check out the repo to use it, so it seemed simpler to put
# it all in one (much longer) file.
file('.rubocop.yml') do
  <<-'RUBOCOP'.strip_heredoc
    AllCops:
      DisabledByDefault: true

    #################### Lint ################################

    Lint/AmbiguousOperator:
      Description: >-
                     Checks for ambiguous operators in the first argument of a
                     method invocation without parentheses.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#parens-as-args'
      Enabled: true

    Lint/AmbiguousRegexpLiteral:
      Description: >-
                     Checks for ambiguous regexp literals in the first argument of
                     a method invocation without parenthesis.
      Enabled: true

    Lint/AssignmentInCondition:
      Description: "Don't use assignment in conditions."
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#safe-assignment-in-condition'
      Enabled: true

    Lint/BlockAlignment:
      Description: 'Align block ends correctly.'
      Enabled: true

    Lint/CircularArgumentReference:
      Description: "Don't refer to the keyword argument in the default value."
      Enabled: true

    Lint/ConditionPosition:
      Description: >-
                     Checks for condition placed in a confusing position relative to
                     the keyword.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#same-line-condition'
      Enabled: true

    Lint/Debugger:
      Description: 'Check for debugger calls.'
      Enabled: true

    Lint/DefEndAlignment:
      Description: 'Align ends corresponding to defs correctly.'
      Enabled: true

    Lint/DeprecatedClassMethods:
      Description: 'Check for deprecated class method calls.'
      Enabled: true

    Lint/DuplicateMethods:
      Description: 'Check for duplicate methods calls.'
      Enabled: true

    Lint/EachWithObjectArgument:
      Description: 'Check for immutable argument given to each_with_object.'
      Enabled: true

    Lint/ElseLayout:
      Description: 'Check for odd code arrangement in an else block.'
      Enabled: true

    Lint/EmptyEnsure:
      Description: 'Checks for empty ensure block.'
      Enabled: true

    Lint/EmptyInterpolation:
      Description: 'Checks for empty string interpolation.'
      Enabled: true

    Lint/EndAlignment:
      Description: 'Align ends correctly.'
      Enabled: true

    Lint/EndInMethod:
      Description: 'END blocks should not be placed inside method definitions.'
      Enabled: true

    Lint/EnsureReturn:
      Description: 'Do not use return in an ensure block.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-return-ensure'
      Enabled: true

    Lint/Eval:
      Description: 'The use of eval represents a serious security risk.'
      Enabled: true

    Lint/FormatParameterMismatch:
      Description: 'The number of parameters to format/sprint must match the fields.'
      Enabled: true

    Lint/HandleExceptions:
      Description: "Don't suppress exception."
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#dont-hide-exceptions'
      Enabled: true

    Lint/InvalidCharacterLiteral:
      Description: >-
                     Checks for invalid character literals with a non-escaped
                     whitespace character.
      Enabled: true

    Lint/LiteralInCondition:
      Description: 'Checks of literals used in conditions.'
      Enabled: true

    Lint/LiteralInInterpolation:
      Description: 'Checks for literals used in interpolation.'
      Enabled: true

    Lint/Loop:
      Description: >-
                     Use Kernel#loop with break rather than begin/end/until or
                     begin/end/while for post-loop tests.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#loop-with-break'
      Enabled: true

    Lint/NestedMethodDefinition:
      Description: 'Do not use nested method definitions.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-nested-methods'
      Enabled: true

    Lint/NonLocalExitFromIterator:
      Description: 'Do not use return in iterator to cause non-local exit.'
      Enabled: true

    Lint/ParenthesesAsGroupedExpression:
      Description: >-
                     Checks for method calls with a space before the opening
                     parenthesis.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#parens-no-spaces'
      Enabled: true

    Lint/RequireParentheses:
      Description: >-
                     Use parentheses in the method call to avoid confusion
                     about precedence.
      Enabled: true

    Lint/RescueException:
      Description: 'Avoid rescuing the Exception class.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-blind-rescues'
      Enabled: true

    Lint/ShadowingOuterLocalVariable:
      Description: >-
                     Do not use the same name as outer local variable
                     for block arguments or block local variables.
      Enabled: true

    Lint/StringConversionInInterpolation:
      Description: 'Checks for Object#to_s usage in string interpolation.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-to-s'
      Enabled: true

    Lint/UnderscorePrefixedVariableName:
      Description: 'Do not use prefix `_` for a variable that is used.'
      Enabled: true

    Lint/UnneededDisable:
      Description: >-
                     Checks for rubocop:disable comments that can be removed.
                     Note: this cop is not disabled when disabling all cops.
                     It must be explicitly disabled.
      Enabled: true

    Lint/UnusedBlockArgument:
      Description: 'Checks for unused block arguments.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#underscore-unused-vars'
      Enabled: true

    Lint/UnusedMethodArgument:
      Description: 'Checks for unused method arguments.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#underscore-unused-vars'
      Enabled: true

    Lint/UnreachableCode:
      Description: 'Unreachable code.'
      Enabled: true

    Lint/UselessAccessModifier:
      Description: 'Checks for useless access modifiers.'
      Enabled: true

    Lint/UselessAssignment:
      Description: 'Checks for useless assignment to a local variable.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#underscore-unused-vars'
      Enabled: true

    Lint/UselessComparison:
      Description: 'Checks for comparison of something with itself.'
      Enabled: true

    Lint/UselessElseWithoutRescue:
      Description: 'Checks for useless `else` in `begin..end` without `rescue`.'
      Enabled: true

    Lint/UselessSetterCall:
      Description: 'Checks for useless setter call to a local variable.'
      Enabled: true

    Lint/Void:
      Description: 'Possible use of operator/literal/variable in void context.'
      Enabled: true

    ###################### Metrics ####################################

    Metrics/AbcSize:
      Description: >-
                     A calculated magnitude based on number of assignments,
                     branches, and conditions.
      Reference: 'http://c2.com/cgi/wiki?AbcMetric'
      Enabled: false
      Max: 20

    Metrics/BlockNesting:
      Description: 'Avoid excessive block nesting'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#three-is-the-number-thou-shalt-count'
      Enabled: true
      Max: 4

    Metrics/ClassLength:
      Description: 'Avoid classes longer than 250 lines of code.'
      Enabled: true
      Max: 250

    Metrics/CyclomaticComplexity:
      Description: >-
                     A complexity metric that is strongly correlated to the number
                     of test cases needed to validate a method.
      Enabled: true

    Metrics/LineLength:
      Description: 'Limit lines to 80 characters.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#80-character-limits'
      Enabled: false

    Metrics/MethodLength:
      Description: 'Avoid methods longer than 30 lines of code.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#short-methods'
      Enabled: true
      Max: 30

    Metrics/ModuleLength:
      Description: 'Avoid modules longer than 250 lines of code.'
      Enabled: true
      Max: 250

    Metrics/ParameterLists:
      Description: 'Avoid parameter lists longer than three or four parameters.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#too-many-params'
      Enabled: true

    Metrics/PerceivedComplexity:
      Description: >-
                     A complexity metric geared towards measuring complexity for a
                     human reader.
      Enabled: false

    ##################### Performance #############################

    Performance/Count:
      Description: >-
                      Use `count` instead of `select...size`, `reject...size`,
                      `select...count`, `reject...count`, `select...length`,
                      and `reject...length`.
      Enabled: true

    Performance/Detect:
      Description: >-
                      Use `detect` instead of `select.first`, `find_all.first`,
                      `select.last`, and `find_all.last`.
      Reference: 'https://github.com/JuanitoFatas/fast-ruby#enumerabledetect-vs-enumerableselectfirst-code'
      Enabled: true

    Performance/FlatMap:
      Description: >-
                      Use `Enumerable#flat_map`
                      instead of `Enumerable#map...Array#flatten(1)`
                      or `Enumberable#collect..Array#flatten(1)`
      Reference: 'https://github.com/JuanitoFatas/fast-ruby#enumerablemaparrayflatten-vs-enumerableflat_map-code'
      Enabled: true
      EnabledForFlattenWithoutParams: false
      # If enabled, this cop will warn about usages of
      # `flatten` being called without any parameters.
      # This can be dangerous since `flat_map` will only flatten 1 level, and
      # `flatten` without any parameters can flatten multiple levels.

    Performance/ReverseEach:
      Description: 'Use `reverse_each` instead of `reverse.each`.'
      Reference: 'https://github.com/JuanitoFatas/fast-ruby#enumerablereverseeach-vs-enumerablereverse_each-code'
      Enabled: true

    Performance/Sample:
      Description: >-
                      Use `sample` instead of `shuffle.first`,
                      `shuffle.last`, and `shuffle[Fixnum]`.
      Reference: 'https://github.com/JuanitoFatas/fast-ruby#arrayshufflefirst-vs-arraysample-code'
      Enabled: true

    Performance/Size:
      Description: >-
                      Use `size` instead of `count` for counting
                      the number of elements in `Array` and `Hash`.
      Reference: 'https://github.com/JuanitoFatas/fast-ruby#arraycount-vs-arraysize-code'
      Enabled: true

    Performance/StringReplacement:
      Description: >-
                      Use `tr` instead of `gsub` when you are replacing the same
                      number of characters. Use `delete` instead of `gsub` when
                      you are deleting characters.
      Reference: 'https://github.com/JuanitoFatas/fast-ruby#stringgsub-vs-stringtr-code'
      Enabled: true

    ##################### Rails ##################################

    Rails/ActionFilter:
      Description: 'Enforces consistent use of action filter methods.'
      Enabled: false

    Rails/Date:
      Description: >-
                      Checks the correct usage of date aware methods,
                      such as Date.today, Date.current etc.
      Enabled: false

    Rails/Delegate:
      Description: 'Prefer delegate method for delegations.'
      Enabled: false

    Rails/FindBy:
      Description: 'Prefer find_by over where.first.'
      Enabled: false

    Rails/FindEach:
      Description: 'Prefer all.find_each over all.find.'
      Enabled: false

    Rails/HasAndBelongsToMany:
      Description: 'Prefer has_many :through to has_and_belongs_to_many.'
      Enabled: false

    Rails/Output:
      Description: 'Checks for calls to puts, print, etc.'
      Enabled: false

    Rails/ReadWriteAttribute:
      Description: >-
                     Checks for read_attribute(:attr) and
                     write_attribute(:attr, val).
      Enabled: false

    Rails/ScopeArgs:
      Description: 'Checks the arguments of ActiveRecord scopes.'
      Enabled: false

    Rails/TimeZone:
      Description: 'Checks the correct usage of time zone aware methods.'
      StyleGuide: 'https://github.com/bbatsov/rails-style-guide#time'
      Reference: 'http://danilenko.org/2012/7/6/rails_timezones'
      Enabled: false

    Rails/Validation:
      Description: 'Use validates :attribute, hash of validations.'
      Enabled: false

    ################## Style #################################

    Style/AccessModifierIndentation:
      Description: Check indentation of private/protected visibility modifiers.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#indent-public-private-protected'
      Enabled: false

    Style/AccessorMethodName:
      Description: Check the naming of accessor methods for get_/set_.
      Enabled: false

    Style/Alias:
      Description: 'Use alias_method instead of alias.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#alias-method'
      Enabled: false

    Style/AlignArray:
      Description: >-
                     Align the elements of an array literal if they span more than
                     one line.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#align-multiline-arrays'
      Enabled: false

    Style/AlignHash:
      Description: >-
                     Align the elements of a hash literal if they span more than
                     one line.
      Enabled: false

    Style/AlignParameters:
      Description: >-
                     Align the parameters of a method call if they span more
                     than one line.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-double-indent'
      Enabled: false

    Style/AndOr:
      Description: 'Use &&/|| instead of and/or.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-and-or-or'
      Enabled: false

    Style/ArrayJoin:
      Description: 'Use Array#join instead of Array#*.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#array-join'
      Enabled: false

    Style/AsciiComments:
      Description: 'Use only ascii symbols in comments.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#english-comments'
      Enabled: false

    Style/AsciiIdentifiers:
      Description: 'Use only ascii symbols in identifiers.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#english-identifiers'
      Enabled: false

    Style/Attr:
      Description: 'Checks for uses of Module#attr.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#attr'
      Enabled: false

    Style/BeginBlock:
      Description: 'Avoid the use of BEGIN blocks.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-BEGIN-blocks'
      Enabled: false

    Style/BarePercentLiterals:
      Description: 'Checks if usage of %() or %Q() matches configuration.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#percent-q-shorthand'
      Enabled: false

    Style/BlockComments:
      Description: 'Do not use block comments.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-block-comments'
      Enabled: false

    Style/BlockEndNewline:
      Description: 'Put end statement of multiline block on its own line.'
      Enabled: false

    Style/BlockDelimiters:
      Description: >-
                    Avoid using {...} for multi-line blocks (multiline chaining is
                    always ugly).
                    Prefer {...} over do...end for single-line blocks.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#single-line-blocks'
      Enabled: false

    Style/BracesAroundHashParameters:
      Description: 'Enforce braces style around hash parameters.'
      Enabled: false

    Style/CaseEquality:
      Description: 'Avoid explicit use of the case equality operator(===).'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-case-equality'
      Enabled: false

    Style/CaseIndentation:
      Description: 'Indentation of when in a case/when/[else/]end.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#indent-when-to-case'
      Enabled: false

    Style/CharacterLiteral:
      Description: 'Checks for uses of character literals.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-character-literals'
      Enabled: false

    Style/ClassAndModuleCamelCase:
      Description: 'Use CamelCase for classes and modules.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#camelcase-classes'
      Enabled: false

    Style/ClassAndModuleChildren:
      Description: 'Checks style of children classes and modules.'
      Enabled: false

    Style/ClassCheck:
      Description: 'Enforces consistent use of `Object#is_a?` or `Object#kind_of?`.'
      Enabled: false

    Style/ClassMethods:
      Description: 'Use self when defining module/class methods.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#def-self-class-methods'
      Enabled: false

    Style/ClassVars:
      Description: 'Avoid the use of class variables.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-class-vars'
      Enabled: false

    Style/ClosingParenthesisIndentation:
      Description: 'Checks the indentation of hanging closing parentheses.'
      Enabled: false

    Style/ColonMethodCall:
      Description: 'Do not use :: for method call.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#double-colons'
      Enabled: false

    Style/CommandLiteral:
      Description: 'Use `` or %x around command literals.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#percent-x'
      Enabled: false

    Style/CommentAnnotation:
      Description: 'Checks formatting of annotation comments.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#annotate-keywords'
      Enabled: false

    Style/CommentIndentation:
      Description: 'Indentation of comments.'
      Enabled: false

    Style/ConstantName:
      Description: 'Constants should use SCREAMING_SNAKE_CASE.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#screaming-snake-case'
      Enabled: false

    Style/DefWithParentheses:
      Description: 'Use def with parentheses when there are arguments.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#method-parens'
      Enabled: false

    Style/Documentation:
      Description: 'Document classes and non-namespace modules.'
      Enabled: false

    Style/DotPosition:
      Description: 'Checks the position of the dot in multi-line method calls.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#consistent-multi-line-chains'
      Enabled: false

    Style/DoubleNegation:
      Description: 'Checks for uses of double negation (!!).'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-bang-bang'
      Enabled: false

    Style/EachWithObject:
      Description: 'Prefer `each_with_object` over `inject` or `reduce`.'
      Enabled: false

    Style/ElseAlignment:
      Description: 'Align elses and elsifs correctly.'
      Enabled: false

    Style/EmptyElse:
      Description: 'Avoid empty else-clauses.'
      Enabled: false

    Style/EmptyLineBetweenDefs:
      Description: 'Use empty lines between defs.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#empty-lines-between-methods'
      Enabled: false

    Style/EmptyLines:
      Description: "Don't use several empty lines in a row."
      Enabled: false

    Style/EmptyLinesAroundAccessModifier:
      Description: "Keep blank lines around access modifiers."
      Enabled: false

    Style/EmptyLinesAroundBlockBody:
      Description: "Keeps track of empty lines around block bodies."
      Enabled: false

    Style/EmptyLinesAroundClassBody:
      Description: "Keeps track of empty lines around class bodies."
      Enabled: false

    Style/EmptyLinesAroundModuleBody:
      Description: "Keeps track of empty lines around module bodies."
      Enabled: false

    Style/EmptyLinesAroundMethodBody:
      Description: "Keeps track of empty lines around method bodies."
      Enabled: false

    Style/EmptyLiteral:
      Description: 'Prefer literals to Array.new/Hash.new/String.new.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#literal-array-hash'
      Enabled: false

    Style/EndBlock:
      Description: 'Avoid the use of END blocks.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-END-blocks'
      Enabled: false

    Style/EndOfLine:
      Description: 'Use Unix-style line endings.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#crlf'
      Enabled: false

    Style/EvenOdd:
      Description: 'Favor the use of Fixnum#even? && Fixnum#odd?'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#predicate-methods'
      Enabled: false

    Style/ExtraSpacing:
      Description: 'Do not use unnecessary spacing.'
      Enabled: false

    Style/FileName:
      Description: 'Use snake_case for source file names.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#snake-case-files'
      Enabled: false

    Style/InitialIndentation:
      Description: >-
        Checks the indentation of the first non-blank non-comment line in a file.
      Enabled: false

    Style/FirstParameterIndentation:
      Description: 'Checks the indentation of the first parameter in a method call.'
      Enabled: false

    Style/FlipFlop:
      Description: 'Checks for flip flops'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-flip-flops'
      Enabled: false

    Style/For:
      Description: 'Checks use of for or each in multiline loops.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-for-loops'
      Enabled: false

    Style/FormatString:
      Description: 'Enforce the use of Kernel#sprintf, Kernel#format or String#%.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#sprintf'
      Enabled: false

    Style/GlobalVars:
      Description: 'Do not introduce global variables.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#instance-vars'
      Reference: 'http://www.zenspider.com/Languages/Ruby/QuickRef.html'
      Enabled: false

    Style/GuardClause:
      Description: 'Check for conditionals that can be replaced with guard clauses'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-nested-conditionals'
      Enabled: false

    Style/HashSyntax:
      Description: >-
                     Prefer Ruby 1.9 hash syntax { a: 1, b: 2 } over 1.8 syntax
                     { :a => 1, :b => 2 }.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#hash-literals'
      Enabled: false

    Style/IfUnlessModifier:
      Description: >-
                     Favor modifier if/unless usage when you have a
                     single-line body.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#if-as-a-modifier'
      Enabled: false

    Style/IfWithSemicolon:
      Description: 'Do not use if x; .... Use the ternary operator instead.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-semicolon-ifs'
      Enabled: false

    Style/IndentationConsistency:
      Description: 'Keep indentation straight.'
      Enabled: false

    Style/IndentationWidth:
      Description: 'Use 2 spaces for indentation.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#spaces-indentation'
      Enabled: false

    Style/IndentArray:
      Description: >-
                     Checks the indentation of the first element in an array
                     literal.
      Enabled: false

    Style/IndentHash:
      Description: 'Checks the indentation of the first key in a hash literal.'
      Enabled: false

    Style/InfiniteLoop:
      Description: 'Use Kernel#loop for infinite loops.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#infinite-loop'
      Enabled: false

    Style/Lambda:
      Description: 'Use the new lambda literal syntax for single-line blocks.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#lambda-multi-line'
      Enabled: false

    Style/LambdaCall:
      Description: 'Use lambda.call(...) instead of lambda.(...).'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#proc-call'
      Enabled: false

    Style/LeadingCommentSpace:
      Description: 'Comments should start with a space.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#hash-space'
      Enabled: false

    Style/LineEndConcatenation:
      Description: >-
                     Use \ instead of + or << to concatenate two string literals at
                     line end.
      Enabled: false

    Style/MethodCallParentheses:
      Description: 'Do not use parentheses for method calls with no arguments.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-args-no-parens'
      Enabled: false

    Style/MethodDefParentheses:
      Description: >-
                     Checks if the method definitions have or don't have
                     parentheses.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#method-parens'
      Enabled: false

    Style/MethodName:
      Description: 'Use the configured style when naming methods.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#snake-case-symbols-methods-vars'
      Enabled: false

    Style/ModuleFunction:
      Description: 'Checks for usage of `extend self` in modules.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#module-function'
      Enabled: false

    Style/MultilineBlockChain:
      Description: 'Avoid multi-line chains of blocks.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#single-line-blocks'
      Enabled: false

    Style/MultilineBlockLayout:
      Description: 'Ensures newlines after multiline block do statements.'
      Enabled: false

    Style/MultilineIfThen:
      Description: 'Do not use then for multi-line if/unless.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-then'
      Enabled: false

    Style/MultilineOperationIndentation:
      Description: >-
                     Checks indentation of binary operations that span more than
                     one line.
      Enabled: false

    Style/MultilineTernaryOperator:
      Description: >-
                     Avoid multi-line ?: (the ternary operator);
                     use if/unless instead.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-multiline-ternary'
      Enabled: false

    Style/NegatedIf:
      Description: >-
                     Favor unless over if for negative conditions
                     (or control flow or).
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#unless-for-negatives'
      Enabled: false

    Style/NegatedWhile:
      Description: 'Favor until over while for negative conditions.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#until-for-negatives'
      Enabled: false

    Style/NestedTernaryOperator:
      Description: 'Use one expression per branch in a ternary operator.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-nested-ternary'
      Enabled: false

    Style/Next:
      Description: 'Use `next` to skip iteration instead of a condition at the end.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-nested-conditionals'
      Enabled: false

    Style/NilComparison:
      Description: 'Prefer x.nil? to x == nil.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#predicate-methods'
      Enabled: false

    Style/NonNilCheck:
      Description: 'Checks for redundant nil checks.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-non-nil-checks'
      Enabled: false

    Style/Not:
      Description: 'Use ! instead of not.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#bang-not-not'
      Enabled: false

    Style/NumericLiterals:
      Description: >-
                     Add underscores to large numeric literals to improve their
                     readability.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#underscores-in-numerics'
      Enabled: false

    Style/OneLineConditional:
      Description: >-
                     Favor the ternary operator(?:) over
                     if/then/else/end constructs.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#ternary-operator'
      Enabled: false

    Style/OpMethod:
      Description: 'When defining binary operators, name the argument other.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#other-arg'
      Enabled: false

    Style/OptionalArguments:
      Description: >-
                     Checks for optional arguments that do not appear at the end
                     of the argument list
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#optional-arguments'
      Enabled: false

    Style/ParallelAssignment:
      Description: >-
                      Check for simple usages of parallel assignment.
                      It will only warn when the number of variables
                      matches on both sides of the assignment.
                      This also provides performance benefits
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#parallel-assignment'
      Enabled: false

    Style/ParenthesesAroundCondition:
      Description: >-
                     Don't use parentheses around the condition of an
                     if/unless/while.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-parens-if'
      Enabled: false

    Style/PercentLiteralDelimiters:
      Description: 'Use `%`-literal delimiters consistently'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#percent-literal-braces'
      Enabled: false

    Style/PercentQLiterals:
      Description: 'Checks if uses of %Q/%q match the configured preference.'
      Enabled: false

    Style/PerlBackrefs:
      Description: 'Avoid Perl-style regex back references.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-perl-regexp-last-matchers'
      Enabled: false

    Style/PredicateName:
      Description: 'Check the names of predicate methods.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#bool-methods-qmark'
      Enabled: false

    Style/Proc:
      Description: 'Use proc instead of Proc.new.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#proc'
      Enabled: false

    Style/RaiseArgs:
      Description: 'Checks the arguments passed to raise/fail.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#exception-class-messages'
      Enabled: false

    Style/RedundantBegin:
      Description: "Don't use begin blocks when they are not needed."
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#begin-implicit'
      Enabled: false

    Style/RedundantException:
      Description: "Checks for an obsolete RuntimeException argument in raise/fail."
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-explicit-runtimeerror'
      Enabled: false

    Style/RedundantReturn:
      Description: "Don't use return where it's not required."
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-explicit-return'
      Enabled: false

    Style/RedundantSelf:
      Description: "Don't use self where it's not needed."
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-self-unless-required'
      Enabled: false

    Style/RegexpLiteral:
      Description: 'Use / or %r around regular expressions.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#percent-r'
      Enabled: false

    Style/RescueEnsureAlignment:
      Description: 'Align rescues and ensures correctly.'
      Enabled: false

    Style/RescueModifier:
      Description: 'Avoid using rescue in its modifier form.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-rescue-modifiers'
      Enabled: false

    Style/SelfAssignment:
      Description: >-
                     Checks for places where self-assignment shorthand should have
                     been used.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#self-assignment'
      Enabled: false

    Style/Semicolon:
      Description: "Don't use semicolons to terminate expressions."
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-semicolon'
      Enabled: false

    Style/SignalException:
      Description: 'Checks for proper usage of fail and raise.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#fail-method'
      Enabled: false

    Style/SingleLineBlockParams:
      Description: 'Enforces the names of some block params.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#reduce-blocks'
      Enabled: false

  Style/SingleLineMethods:
      Description: 'Avoid single-line methods.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-single-line-methods'
      Enabled: false

    Style/SpaceBeforeFirstArg:
      Description: >-
                     Checks that exactly one space is used between a method name
                     and the first argument for method calls without parentheses.
      Enabled: true

    Style/SpaceAfterColon:
      Description: 'Use spaces after colons.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#spaces-operators'
      Enabled: false

  Style/SpaceAfterComma:
      Description: 'Use spaces after commas.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#spaces-operators'
      Enabled: false

    Style/SpaceAroundKeyword:
      Description: 'Use spaces around keywords.'
      Enabled: false

    Style/SpaceAfterMethodName:
      Description: >-
                     Do not put a space between a method name and the opening
                     parenthesis in a method definition.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#parens-no-spaces'
      Enabled: false

  Style/SpaceAfterNot:
      Description: Tracks redundant space after the ! operator.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-space-bang'
      Enabled: false

    Style/SpaceAfterSemicolon:
      Description: 'Use spaces after semicolons.'
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#spaces-operators'
      Enabled: false

    Style/SpaceBeforeBlockBraces:
      Description: >-
                     Checks that the left block brace has or doesn't have space
                     before it.
      Enabled: false

    Style/SpaceBeforeComma:
      Description: 'No spaces before commas.'
      Enabled: false

    Style/SpaceBeforeComment:
      Description: >-
                     Checks for missing space between code and a comment on the
                     same line.
      Enabled: false

    Style/SpaceBeforeSemicolon:
      Description: 'No spaces before semicolons.'
      Enabled: false

    Style/SpaceInsideBlockBraces:
      Description: >-
                     Checks that block braces have or don't have surrounding space.
                       For blocks taking parameters, checks that the left brace has
                     or doesn't have trailing space.
      Enabled: false

    Style/SpaceAroundBlockParameters:
      Description: 'Checks the spacing inside and after block parameters pipes.'
      Enabled: false

    Style/SpaceAroundEqualsInParameterDefault:
      Description: >-
                     Checks that the equals signs in parameter default assignments
                     have or don't have surrounding space depending on
                     configuration.
                       StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#spaces-around-equals'
                     Enabled: false

                     Style/SpaceAroundOperators:
                       Description: 'Use a single space around operators.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#spaces-operators'
                     Enabled: false

                     Style/SpaceInsideBrackets:
                       Description: 'No spaces after [ or before ].'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-spaces-braces'
                     Enabled: false

                     Style/SpaceInsideHashLiteralBraces:
                       Description: "Use spaces inside hash literal braces - or don't."
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#spaces-operators'
                     Enabled: false

                     Style/SpaceInsideParens:
                       Description: 'No spaces after ( or before ).'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-spaces-braces'
                     Enabled: false

                     Style/SpaceInsideRangeLiteral:
                       Description: 'No spaces inside range literals.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-space-inside-range-literals'
                     Enabled: false

                     Style/SpaceInsideStringInterpolation:
                       Description: 'Checks for padding/surrounding spaces inside string interpolation.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#string-interpolation'
                     Enabled: false

                     Style/SpecialGlobalVars:
                       Description: 'Avoid Perl-style global variables.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-cryptic-perlisms'
                     Enabled: false

                     Style/StringLiterals:
                       Description: 'Checks if uses of quotes match the configured preference.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#consistent-string-literals'
                     Enabled: false

                     Style/StringLiteralsInInterpolation:
                       Description: >-
                       Checks if uses of quotes inside expressions in interpolated
                     strings match the configured preference.
                       Enabled: false

                     Style/StructInheritance:
                       Description: 'Checks for inheritance from Struct.new.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-extend-struct-new'
                     Enabled: false

                     Style/SymbolLiteral:
                       Description: 'Use plain symbols instead of string symbols when possible.'
                     Enabled: false

                     Style/SymbolProc:
                       Description: 'Use symbols as procs instead of blocks when possible.'
                     Enabled: false

                     Style/Tab:
                       Description: 'No hard tabs.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#spaces-indentation'
                     Enabled: false

                     Style/TrailingBlankLines:
                       Description: 'Checks trailing blank lines and final newline.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#newline-eof'
                     Enabled: false

                     Style/TrailingCommaInArguments:
                       Description: 'Checks for trailing comma in parameter lists.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-trailing-params-comma'
                     Enabled: false

                     Style/TrailingCommaInLiteral:
                       Description: 'Checks for trailing comma in literals.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-trailing-array-commas'
                     Enabled: false

                     Style/TrailingWhitespace:
                       Description: 'Avoid trailing whitespace.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-trailing-whitespace'
                     Enabled: false

                     Style/TrivialAccessors:
                       Description: 'Prefer attr_* methods to trivial readers/writers.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#attr_family'
                     Enabled: false

                     Style/UnlessElse:
                       Description: >-
                       Do not use unless with else. Rewrite these with the positive
                     case first.
                       StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-else-with-unless'
                       Enabled: false

                       Style/UnneededCapitalW:
                         Description: 'Checks for %W when interpolation is not needed.'
                       Enabled: false

                       Style/UnneededPercentQ:
                         Description: 'Checks for %q/%Q when single quotes or double quotes would do.'
                       StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#percent-q'
                       Enabled: false

                       Style/TrailingUnderscoreVariable:
                         Description: >-
                         Checks for the usage of unneeded trailing underscores at the
                     end of parallel variable assignment.
                     Enabled: false

                     Style/VariableInterpolation:
                       Description: >-
                       Don't interpolate global, instance and class variables
                     directly in strings.
      StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#curlies-interpolate'
                       Enabled: false

                     Style/VariableName:
                       Description: 'Use the configured style when naming variables.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#snake-case-symbols-methods-vars'
                     Enabled: false

                     Style/WhenThen:
                       Description: 'Use when x then ... for one-line cases.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#one-line-cases'
                     Enabled: false

                     Style/WhileUntilDo:
                       Description: 'Checks for redundant do after while or until.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#no-multiline-while-do'
                     Enabled: false

                     Style/WhileUntilModifier:
                       Description: >-
                       Favor modifier while/until usage when you have a
                     single-line body.
                       StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#while-as-a-modifier'
                       Enabled: false

                     Style/WordArray:
                       Description: 'Use %w or %W for arrays of words.'
                     StyleGuide: 'https://github.com/bbatsov/ruby-style-guide#percent-w'
                     Enabled: false
                     RUBOCOP
                     end

run 'ctags -R .' if yes?('Should I generate ctags?')

run "echo '/coverage/*' >> .gitignore"
run "echo 'tags' >> .gitignore"
run 'rm -rf test'

# Remove placeholder files. Put them back in after commissioning if you need
# them.  Right now, they are just docu-comment sumps.
run 'rm db/seeds.rb'
run 'rm config/initializers/application_controller_renderer.rb'
run 'rm config/initializers/backtrace_silencers.rb'
run 'rm config/initializers/inflections.rb'
run 'rm config/mime_types.rb'

after_bundle do
  rails_command 'g rspec:install'
  run "echo '--order rand' >> .rspec"

  # These are tolerable-useful if you're new to Rails.  They are little more
  # than line noise and a complete pain if you're experienced.
  if yes?('Kill documentary comments?')
    # Perl is still better at these sort of throw away one-liners...
    # ...in the general codebase
    run 'find . -name "*.rb" -exec perl -pi -e "s/^\s*#.*\n//g" {} \;'
    # Kill multiple newlines
    run 'find . -name "*.rb" -exec perl -pi -0 -e "s/\n{3,}/\n/g" {} \;'
    # ...in the yaml files
    run 'find . -name "*.yml" -exec perl -pi -e "s/^\s*#.*\n//g" {} \;'
    run 'find . -name "*.yml" -exec perl -pi -0 -e "s/\n{3,}/\n/g" {} \;'
    # ...in the Gemfile
    run 'perl -pi -e "s/^\s*#.*\n//g" Gemfile'
    run 'perl -pi -0 -e "s/\n{3,}/\n/g" Gemfile'
    run 'perl -pi -0 -e "s/^\=begin.+\=end//" spec/spec_helper.rb'
  end

  run %Q{echo "#{simplecov}" | cat - spec/spec_helper.rb > /tmp/spec_out && mv /tmp/spec_out spec/spec_helper.rb}
  # End Enable simplecov

  git :init
  git add: '.'
  git commit: %Q{ -m 'Initial commit' }
end

# Enable simplecov
def simplecov
  return <<-END.strip_heredoc
      require 'simplecov'
      SimpleCov.minimum_coverage 100
      # SimpleCov conflicts with mutant. This lets us turn it off, when necessary.
      SimpleCov.start unless ENV['NOCOVERAGE']
  END
end
