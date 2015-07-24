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
end


SimpleForm::Inputs::Base.send(:include, SimpleForm::Components::Icons)
SimpleForm::Inputs::Base.send(:include, SimpleForm::Components::Tooltips)
SimpleForm::FormBuilder.send(:include, SimpleForm::Components::SubmitButtons)