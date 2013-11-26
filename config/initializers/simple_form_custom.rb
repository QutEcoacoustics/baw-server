# Use this setup block to configure all options available in SimpleForm.
SimpleForm.setup do |config|
  config.wrappers :bootstrap_timepicker, :tag => 'div', :class => 'control-group', :error_class => 'error' do |b|
    b.use :html5
    b.use :placeholder
    b.use :label
    b.wrapper :tag => 'div', :class => 'controls' do |c|
      c.wrapper :tag => 'div', :class => 'bootstrap-timepicker' do |ba|
        ba.use :input
        ba.wrapper :tag => 'i', :class => 'icon-time', :style => 'margin: -2px 0 0 -22.5px; pointer-events: none; position: relative;' do |baa|

        end
        ba.use :error, :wrap_with => { :tag => 'span', :class => 'help-inline' }
        ba.use :hint,  :wrap_with => { :tag => 'p', :class => 'help-block' }
      end
    end
  end
end
