# run using rake baw:media_types:list
namespace :baw do
  namespace :media_types do

    desc 'List supported media types.'
    task :list => :environment do

      available_text_formats = Settings.available_formats.text
      available_audio_formats = Settings.available_formats.audio
      available_image_formats = Settings.available_formats.image


      print_media_types('Text', available_text_formats)
      print_media_types('Audio', available_audio_formats)
      print_media_types('Audio (decode only)', BawWorkers::Settings.available_formats.audio_decode_only)
      print_media_types('Image', available_image_formats)

      # list all
      puts list_all
    end

    # Get a sorted array of supported mime types
    # @param [Array<String>] extensions
    # @return [Array<Mime::Type>]
    def list_supported(extensions)
      media_types = []
      extensions.each do |m|
        ext = NameyWamey.trim(m.downcase, '.', '')
        mime_type = Mime::Type.lookup_by_extension(ext)
        media_types.push mime_type unless mime_type.blank?
      end
      media_types.sort { |a, b| a.to_s <=> b.to_s }
    end

    def list_all
      msg = 'All Registered Media Types'
      puts "\n#{msg}\n#{'-' * (msg.length)}\n"
      Mime::SET
          .sort { |a, b| a.to_s <=> b.to_s }
          .map { |item| item.inspect }.join("\n")
    end

    def print_media_types(media_type_category, extensions)
      msg = "Supported #{media_type_category} Media Types"
      puts "\n#{msg}\n#{'-' * (msg.length)}\n"
      puts list_supported(extensions).map { |item| item.inspect }.join("\n")
    end
  end
end

