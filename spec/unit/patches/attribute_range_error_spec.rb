# frozen_string_literal: true

describe BawWeb::ActiveModel::Attribute do
  it 'includes the attribute name when throwing a range error' do
    Temping.create(:model) do
      with_columns do |t|
        t.integer :a_well_named_attribute
      end
    end

    m = Model.new
    m.a_well_named_attribute = 999_999_999_999_999

    expect {
      m.save!
    }.to raise_error(ActiveModel::RangeError, /a_well_named_attribute/)
  end
end
