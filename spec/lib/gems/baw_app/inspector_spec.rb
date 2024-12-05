# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName
HIDDEN = "(\u{1F575}\u{FE0F} HIDDEN)"

describe BawApp::Inspector do
  def expect_inspect_string(rest)
    expect(test_instance.inspect).to eq "#<#{test_class}:#{test_instance.object_address} #{rest}>"
  end

  before do
    stub_const(
      'BaseClass',
      Class.new do
        attr_accessor :a, :b, :c

        include BawApp::Inspector

        def initialize(a, b, c)
          @a = a
          @b = b
          @c = c
        end
      end
    )
  end

  describe 'when included' do
    let(:test_class) do
      BaseClass
    end

    let(:test_instance) { test_class.new(1, 2, 3) }

    it 'does not change output' do
      expect_inspect_string '@a=1, @b=2, @c=3'
    end
  end

  describe 'can be included in a module' do
    before do
      stub_const(
        'SomeModule',
        Module.new do
          include BawApp::Inspector

          attr_accessor :a, :c

          inspector includes: [:a, :b]
        end
      )

      stub_const(
        'TestClass',
        Class.new do
          include SomeModule

          attr_accessor :b
        end
      )
    end

    it 'works' do
      test_instance = TestClass.new
      test_instance.a = 1
      test_instance.b = 2
      test_instance.c = 3

      expect(test_instance.inspect).to eq(
        "#<TestClass:#{test_instance.object_address} @a=1, @b=2>"
      )
    end
  end

  describe 'includes list' do
    let(:test_class) do
      Class.new(BaseClass) do
        inspector(includes: [:a, :b])
      end
    end

    let(:test_instance) { test_class.new(1, 2, 3) }

    it 'filters output' do
      expect_inspect_string '@a=1, @b=2'
    end
  end

  describe 'includes list with exposition' do
    let(:test_class) do
      Class.new(BaseClass) do
        inspector(includes: [:a, :b], expository: true)
      end
    end

    let(:test_instance) { test_class.new(1, 2, 3) }

    it 'filters output' do
      expect_inspect_string "@a=1, @b=2, @c=#{HIDDEN}"
    end
  end

  describe 'excludes list' do
    let(:test_class) do
      Class.new(BaseClass) do
        inspector(excludes: [:a, :c])
      end
    end

    let(:test_instance) { test_class.new(1, 2, 3) }

    it 'filters output' do
      expect_inspect_string '@b=2'
    end
  end

  describe 'excludes list with exposition' do
    let(:test_class) do
      Class.new(BaseClass) do
        inspector(excludes: [:a, :c], expository: true)
      end
    end

    let(:test_instance) { test_class.new(1, 2, 3) }

    it 'filters output' do
      expect_inspect_string "@a=#{HIDDEN}, @b=2, @c=#{HIDDEN}"
    end
  end

  describe 'predicate list' do
    let(:test_class) do
      Class.new(BaseClass) do
        inspector do |key|
          key == :@a
        end
      end
    end

    let(:test_instance) { test_class.new(1, 2, 3) }

    it 'filters output' do
      expect_inspect_string '@a=1'
    end
  end

  describe 'predicate list with exposition' do
    let(:test_class) do
      Class.new(BaseClass) do
        inspector(expository: true) do |key|
          key == :@a
        end
      end
    end

    let(:test_instance) { test_class.new(1, 2, 3) }

    it 'filters output' do
      expect_inspect_string "@a=1, @b=#{HIDDEN}, @c=#{HIDDEN}"
    end
  end

  describe 'it recursively inspects' do
    let(:test_class) do
      Class.new(BaseClass) do
        inspector do |key|
          [:@b, :@c].include?(key)
        end
      end
    end

    let(:another_class) do
      Class.new(BaseClass) do
        inspector do |key|
          key == :@a
        end
      end
    end

    let(:test_instance) { test_class.new(1, another_class.new(4, 5, 6), 3) }

    it 'and prints correctly' do
      another_instance = test_instance.b
      expect(test_instance.inspect).to eq(
        "#<#{test_class}:#{test_instance.object_address} @b=#<#{another_class}:#{another_instance.object_address} @a=4>, @c=3>"
      )
    end
  end
end
# rubocop:enable Naming/MethodParameterName
