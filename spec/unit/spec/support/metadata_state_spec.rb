# frozen_string_literal: true

describe 'MetadataState Tests' do
  define_metadata_state(:my_flag)

  # check we can access the variable
  logger.warn('describe block (0)', self: self, my_flag: get_my_flag)

  it 'can access the metadata' do
    expect(self).to respond_to(:get_my_flag)
  end

  it 'sees the metadata is nil by default' do
    expect(get_my_flag).to be_nil
  end

  context 'when metadata flows into children (1)' do
    it 'sees the unchanged value' do
      expect(get_my_flag).to be_nil
    end

    it 'can show us a trace of metadata' do
      result = trace_metadata(:my_flag)
      logger.info(result)

      actual = result.split("\n").drop(1)
      expect(actual).to match([
        a_string_matching('Metadata my_flag value in each context:'),
        a_string_matching('my_flag=nil ➡️'),
        a_string_matching('my_flag=nil ⬆️'),
        a_string_matching('my_flag=nil ⬆️')
      ])
    end

    context 'when metadata flows into children (2)' do
      it 'sees the unchanged value' do
        expect(get_my_flag).to be_nil
      end

      it 'can show us a trace of metadata' do
        result = trace_metadata(:my_flag)
        logger.info(result)

        actual = result.split("\n").drop(1)
        expect(actual).to match([
          a_string_matching('Metadata my_flag value in each context:'),
          a_string_matching('my_flag=nil ➡️'),
          a_string_matching('my_flag=nil ⬆️'),
          a_string_matching('my_flag=nil ⬆️'),
          a_string_matching('my_flag=nil ⬆️')
        ])
      end
    end
  end

  context 'when nested metadata can be changed in example group' do
    set_my_flag(true)

    let(:captured) { get_my_flag }

    it 'sees the updated value' do
      expect(get_my_flag).to be true
    end

    it 'gets the updated value from let bindings' do
      expect(captured).to be true
    end

    it 'can show us a trace of metadata' do
      result = trace_metadata(:my_flag)
      logger.info(result)

      actual = result.split("\n").drop(1)
      expect(actual).to match([
        a_string_matching('Metadata my_flag value in each context:'),
        a_string_matching('my_flag=nil  ➡️'),
        a_string_matching('my_flag=true ➡️'),
        a_string_matching('my_flag=true ⬆️')
      ])
    end
  end
end

context 'changing state in an example' do
  define_metadata_state(:my_flag)
  it 'checks we can mutate state in an example' do
    set_my_flag(333)
    expect(get_my_flag).to eq 333
  end
end

describe 'MetadataState Tests (mutate root)' do
  define_metadata_state(:my_flag)

  # check we can access the variable
  logger.warn('describe block (0)', self: self, my_flag: get_my_flag)

  set_my_flag(123_456)

  it 'has access to the updated value' do
    expect(get_my_flag).to eq 123_456
  end
end

describe 'MetadataState Tests (mutate root, and in contexts)' do
  define_metadata_state(:my_flag, default: 1)

  set_my_flag(get_my_flag + 1)

  it 'has access to the updated value' do
    expect(get_my_flag).to eq 2
  end

  # repeating these blocks so i can be sure that run order of blocks does not affect values

  context 'with nested (1a)' do
    it 'has access to the updated value' do
      expect(get_my_flag).to eq 2
    end

    context 'with nested (2a)' do
      it 'has access to the updated value' do
        expect(get_my_flag).to eq 2
      end

      it 'can show us a trace of metadata' do
        result = trace_metadata(:my_flag)
        logger.info(result)

        actual = result.split("\n").drop(1)
        expect(actual).to match([
          a_string_matching('Metadata my_flag value in each context:'),
          a_string_matching('my_flag=2 ➡️'),
          a_string_matching('my_flag=2 ⬆️'),
          a_string_matching('my_flag=2 ⬆️'),
          a_string_matching('my_flag=2 ⬆️')
        ])
      end
    end
  end

  context 'with nested and mutation (1)' do
    set_my_flag(get_my_flag + 1)
    it 'has access to the updated value' do
      expect(get_my_flag).to eq 3
    end

    context 'with nested and mutation (2)' do
      set_my_flag(get_my_flag + 1)
      it 'has access to the updated value' do
        expect(get_my_flag).to eq 4
      end

      it 'can show us a trace of metadata' do
        result = trace_metadata(:my_flag)
        logger.info(result)

        actual = result.split("\n").drop(1)
        expect(actual).to match([
          a_string_matching('Metadata my_flag value in each context:'),
          a_string_matching('my_flag=2 ➡️'),
          a_string_matching('my_flag=3 ➡️'),
          a_string_matching('my_flag=4 ➡️'),
          a_string_matching('my_flag=4 ⬆️')
        ])
      end
    end
  end

  context 'with nested (1b)' do
    it 'has access to the updated value' do
      expect(get_my_flag).to eq 2
    end

    context 'with nested (2b)' do
      it 'has access to the updated value' do
        expect(get_my_flag).to eq 2
      end

      it 'can show us a trace of metadata' do
        result = trace_metadata(:my_flag)
        logger.info(result)

        actual = result.split("\n").drop(1)
        expect(actual).to match([
          a_string_matching('Metadata my_flag value in each context:'),
          a_string_matching('my_flag=2 ➡️'),
          a_string_matching('my_flag=2 ⬆️'),
          a_string_matching('my_flag=2 ⬆️'),
          a_string_matching('my_flag=2 ⬆️')
        ])
      end
    end
  end
end
