# frozen_string_literal: true

# ignored: not part of standard testing suite because it has intentional failures
xdescribe 'stepwise spec' do
  before(:all) do
    puts 'before :all'
  end

  before do
    puts 'before :each'
  end

  after do
    puts 'after :each'
  end

  after(:all) do
    puts 'after :all'
  end

  it 'is skipped' do
    skip 'skip'
  end

  it 'is pending' do
    pending 'pending'
  end

  it 'works' do
    1 == 1
  end

  stepwise 'steps sequence' do
    step 'a' do
      puts 'step a '
    end

    step 'b' do
      puts 'step b'
    end

    step 'c' do
      puts 'step c'
    end

    step 'a' do
      puts 'step a '
    end

    step 'b' do
      puts 'step b'
      raise 'error'
    end

    step 'c' do
      puts 'step c'
    end

    step 'c' do
      puts 'step c'
    end

    step 'c' do
      puts 'step c'
    end

    step 'c' do
      puts 'step c'
    end

    step 'c' do
      puts 'step c'
    end

    step 'c' do
      puts 'step c'
    end

    step 'c' do
      puts 'step c'
    end

    step 'c' do
      puts 'step c'
    end
  end
end
