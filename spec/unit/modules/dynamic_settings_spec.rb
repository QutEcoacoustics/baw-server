# frozen_string_literal: true

describe DynamicSettings do
  before do
    # Set up a temporary table and model for testing
    # # Any name will do, but I need more fiber in my diet!
    #
    # https://discuss.rubyonrails.org/t/insert-all-with-temporary-table/85830/1
    # Rails excludes indices from temporary tables for some reason??
    # This means `upsert` doesn't work because it  can't find a unique index
    # needed for the statement.
    # So we create a non-temporary table and then drop it after the test.
    Temping.create(:fruit, temporary: false) do
      with_columns do |t|
        t.string :name, null: false
        t.index :name, unique: true
        t.string :value, null: false

        t.timestamps
      end

      include DynamicSettings

      define_setting(
        :banana,
        BawApp::Types::String,
        'A banana setting',
        'yellow fruit'
      )

      define_setting(
        :apple,
        BawApp::Types::Params::Integer.optional.constrained(gt: 0),
        'An apple setting',
        nil
      )
    end
  end

  describe 'class methods' do
    it 'can get a setting that has a default' do
      expect(Fruit.banana).to eq('yellow fruit')
    end

    it 'can set a setting' do
      Fruit.banana = 'green fruit'
      expect(Fruit.banana).to eq('green fruit')

      # Check that the setting is saved in the database
      expect(Fruit.find_by(name: :banana).value).to eq('green fruit')
    end

    it 'can reset a setting which has a default' do
      Fruit.banana = 'green fruit'
      expect(Fruit.banana).to eq('green fruit')

      # Reset the setting to its default value
      Fruit.banana = nil
      expect(Fruit.banana).to eq('yellow fruit')

      # Check that the setting is removed from the database
      expect(Fruit.find_by(name: :banana)).to be_nil
    end

    it 'can reset a setting to nil' do
      Fruit.apple = 5
      expect(Fruit.apple).to eq(5)

      Fruit.apple = nil
      expect(Fruit.apple).to be_nil

      # Check that the setting is removed from the database
      expect(Fruit.find_by(name: :apple)).to be_nil
    end

    it 'automatically converts a loaded setting to the correct type' do
      # Set the setting to a string
      expect(Fruit.apple).to be_nil
      Fruit.apple = '5'
      expect(Fruit.apple).to eq(5)

      # query the database to get the setting, without going through the model's type conversion
      database_value = ActiveRecord::Base.connection.execute(
        "SELECT value FROM fruits WHERE name = 'apple'"
      ).first['value']

      expect(database_value).to eq('5')
    end

    it 'raises an error if the type is not correct' do
      expect {
        Fruit.apple = 'not a number'
      }.to raise_error(
        ArgumentError,
        'Invalid setting: Value must be of type NilClass | Integer'
      )
    end

    it 'cannot define a setting with the same name twice' do
      expect {
        Fruit.define_setting(
          :banana,
          BawApp::Types::String,
          'A banana setting2',
          'yellow fruit'
        )
      }.to raise_error(ArgumentError, 'Cannot define a known setting twice')
    end

    it 'has a load all settings method' do
      # only set one setting so we can test a mix of loaded and not loaded
      Fruit.apple = 5

      settings = Fruit.load_all_settings.map(&:as_json)

      expect(settings).to match(a_collection_including(
        a_hash_including(
          'id' => nil,
          'name' => 'banana',
          'value' => 'yellow fruit'
        ),
        a_hash_including(
          'id' => an_instance_of(Integer),
          'name' => 'apple',
          'value' => 5
        )
      ))
      expect(settings.size).to eq(2)
    end
  end

  describe 'normal active record methods' do
    it 'cannot create a setting that is not defined' do
      expect {
        Fruit.create!(name: :lemon, value: 'yellow fruit')
      }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Name is not a known setting')
    end

    it 'validates the setting value' do
      expect {
        Fruit.create!(name: :apple, value: 'not a number')
      }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Value must be of type NilClass | Integer')
    end

    it 'automatically converts a loaded setting to the correct type' do
      # Set the setting to a string
      Fruit.apple = '5'

      # tests the type conversion works on the instance accessor as well
      expect(Fruit.find_by(name: :apple).value).to eq(5)

      # query the database to get the setting, without going through the model's type conversion
      database_value = ActiveRecord::Base.connection.execute(
        "SELECT value FROM fruits WHERE name = 'apple'"
      ).first['value']

      expect(database_value).to eq('5')
    end

    it 'automatically converts name to a symbol' do
      Fruit.banana = 'FRUIT!'
      expect(Fruit.find_by(name: :banana).name).to eq(:banana)

      Fruit.apple = 5
      expect(Fruit.find_by(name: :apple).name).to eq(:apple)
    end

    it 'has descriptions, defaults, and type specifications' do
      setting = Fruit.load_setting(:banana)

      expect(setting.as_json).to match(a_hash_including(
        'name' => 'banana',
        'value' => 'yellow fruit',
        'description' => 'A banana setting',
        'type_specification' => 'String',
        'default' => 'yellow fruit'
      ))
    end

    it 'has descriptions, defaults, and type specifications for saved values' do
      Fruit.apple = 100
      setting = Fruit.load_setting(:apple)

      expect(setting.as_json).to match(a_hash_including(
        'name' => 'apple',
        'value' => 100,
        'description' => 'An apple setting',
        'type_specification' => 'NilClass | Integer',
        'default' => nil
      ))
    end

    it 'does not mutate the value on assignment' do
      instance = Fruit.new(name: :apple)

      instance.value = 5
      expect(instance.value).to eq(5)

      # it will convert on read, if it is valid
      instance.value = '5'
      expect(instance.value).to eq(5)
      expect(instance[:value]).to eq('5')

      # but not if it is invalid
      instance.value = 'not a number'
      expect(instance.value).to eq('not a number')
      expect(instance[:value]).to eq('not a number')
    end
  end

  it 'adds instances to the cache when they are loaded' do
    Fruit.apple = 5

    Fruit.clear_cache
    expect(Fruit.settings_cache).to be_empty

    instance = Fruit.find_by(name: :apple)

    # the active record hook should have added the instance to the cache
    expect(Fruit.settings_cache).to include(:apple)

    class_instance = Fruit.load_setting(:apple)

    expect(instance).to eq(class_instance)
  end

  it 'clears the cache when a setting is deleted' do
    Fruit.apple = 5

    Fruit.clear_cache
    expect(Fruit.settings_cache).to be_empty

    expect(Fruit.load_setting(:apple)).to be_an_instance_of(Fruit).and be_persisted

    # the active record hook should have added the instance to the cache
    expect(Fruit.settings_cache).to include(:apple)

    instance = Fruit.find_by(name: :apple)
    instance.destroy!

    # the cache should be empty again
    expect(Fruit.settings_cache).to be_empty
  end

  it 'updates the cache when a setting is loaded' do
    Fruit.apple = 5

    instance = Fruit.find_by(name: :apple)
    instance.value = 10

    expect(Fruit.apple).to eq(10)

    instance.save!

    expect(Fruit.apple).to eq(10)

    expect(Fruit.load_setting(:apple)).to eq instance
  end
end
