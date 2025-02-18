# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Normalizes recognized boolean values
    # https://github.com/dry-rb/dry-types/blob/c155df33db1cf67185c873ad82a97e7491e31aec/lib/dry/types/coercions/params.rb#L13-L17
    class BoolTransformer < KeyTransformer
      def transform(_key, value)
        BawApp::Types::Params::Bool.try(value).to_monad.to_maybe
      end
    end
  end
end
