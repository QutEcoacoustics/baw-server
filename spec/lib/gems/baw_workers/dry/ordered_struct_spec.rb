describe BawWorkers::Dry::OrderedStruct do
  let(:struct_class) do
    Class.new(described_class) do
      attribute :shape, BawWorkers::Dry::Types::String
      attribute? :color, BawWorkers::Dry::Types::String
      attribute :count, BawWorkers::Dry::Types::Integer
    end
  end

  it 'returns values in schema order including nils for optional attributes' do
    instance = struct_class.new(count: 3, shape: 'circle')

    expect(instance.ordered_values).to eq(['circle', nil, 3])
  end
end
