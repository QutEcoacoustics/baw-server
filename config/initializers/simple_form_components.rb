# @see https://github.com/plataformatec/simple_form/wiki/Bootstrap-component-helpers
# @see https://gist.github.com/maxivak/57a2fb71afeb9efcf771
module SimpleForm
  module Components

    module Icons
      def icon(wrapper_options = nil)
        return icon_class unless options[:icon].nil?
      end

      def icon_class
        icon_tag = template.content_tag(:i, '', class: options[:icon])
      end
    end

    # You will still need to initialize your controls with javascript:
    # $('body').tooltip({ selector: "[data-toggle~='tooltip']"})
    module Tooltips
      def tooltip(wrapper_options = nil)
        unless tooltip_text.nil?
          input_html_options[:rel] ||= 'tooltip'
          input_html_options['data-toggle'] ||= 'tooltip'
          input_html_options['data-placement'] ||= tooltip_position
          input_html_options['data-trigger'] ||= 'focus'
          input_html_options['data-original-title'] ||= tooltip_text
          nil
        end
      end

      def tooltip_text
        tooltip = options[:tooltip]
        if tooltip.is_a?(String)
          tooltip
        elsif tooltip.is_a?(Array)
          tooltip[1]
        else
          nil
        end
      end

      def tooltip_position
        tooltip = options[:tooltip]
        tooltip.is_a?(Array) ? tooltip[0] : 'right'
      end
    end

    module SubmitButtons
      def submit_cancel(*args, &block)
        template.content_tag :div, class: 'form-group' do
          template.content_tag :div, class: 'col-sm-offset-3 col-sm-9' do
            options = args.extract_options!

            # class
            options[:class] = [options[:class]].compact

            #
            args << options


            # with cancel link
            cancel = options.delete(:cancel)
            if cancel
              submit(*args, &block) + '&nbsp;&nbsp;'.html_safe + template.link_to(I18n.t('helpers.links.cancel'), cancel)
            else
              submit(*args, &block)
            end

          end
        end
      end

    end

  end

  # @see https://github.com/plataformatec/simple_form/wiki/Bootstrap-component-helpers
  # module Inputs
  #   class FileInput < Base
  #     def input
  #       idf = "#{lookup_model_names.join("_")}_#{reflection_or_attribute_name}"
  #       input_html_options[:style] ||= 'display:none;'
  #
  #       button = template.content_tag(:div, class: 'input-append') do
  #         template.tag(:input, id: "pbox_#{idf}", class: 'string input-medium', type: 'text') +
  #             template.content_tag(:a, "Browse", class: 'btn', onclick: "$('input[id=#{idf}]').click();")
  #       end
  #
  #       script = template.content_tag(:script, type: 'text/javascript') do
  #         "$('input[id=#{idf}]').change(function() { s = $(this).val(); $('#pbox_#{idf}').val(s.slice(s.lastIndexOf('\\\\\\\\')+1)); });".html_safe
  #       end
  #
  #       @builder.file_field(attribute_name, input_html_options) + button + script
  #     end
  #   end
  # end

end


SimpleForm::Inputs::Base.send(:include, SimpleForm::Components::Icons)
SimpleForm::Inputs::Base.send(:include, SimpleForm::Components::Tooltips)
SimpleForm::FormBuilder.send(:include, SimpleForm::Components::SubmitButtons)