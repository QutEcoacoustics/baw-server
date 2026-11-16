# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Table::Deployment do
  create_audio_recordings_hierarchy

  subject(:row) do
    row = table.mapping(deployment, user: nil, should_obfuscate:).ordered_values
    table.attribute_names.zip(row).to_h
  end

  let(:table) { BawWorkers::Export::CamtrapDp::Table::Deployment }

  let(:should_obfuscate) { false }
  let(:deployment) do
    BawWorkers::Export::CamtrapDp::DeploymentAccumulator::Deployment.new(
      site:,
      start: audio_recording.recorded_date,
      end: audio_recording.recorded_end_date,
      file_public: false,
      timezone: ActiveSupport::TimeZone['UTC']
    )
  end

  describe '.mapping' do
    it 'maps the location and assumed measurement uncertainty' do
      expect(row).to include(
        deploymentID: site.global_identifier,
        locationID: site.global_identifier,
        locationName: site.name,
        latitude: site.latitude,
        longitude: site.longitude,
        coordinateUncertainty: 30,
        deploymentTags: 'coordinatesObfuscated:false | ' \
                        'dataGeneralizations:coordinates have an assumed measurement uncertainty of 30 meters'
      )
    end

    context 'with coordinate obfuscation' do
      let(:should_obfuscate) { true }

      it 'reports both measurement and obfuscation uncertainty' do
        uncertainty = site.total_coordinate_uncertainty_meters(should_obfuscate: true)
        obfuscation_uncertainty = uncertainty - site.effective_measurement_uncertainty_meters

        expect(row).to include(
          latitude: site.obfuscated_latitude,
          longitude: site.obfuscated_longitude,
          coordinateUncertainty: uncertainty.to_i,
          deploymentTags: 'coordinatesObfuscated:true | ' \
                          'dataGeneralizations:coordinates have an assumed measurement uncertainty of 30 meters; ' \
                          "coordinates have an obfuscation uncertainty of #{obfuscation_uncertainty} meters"
        )
      end

      context 'with custom obfuscated coordinates' do
        before { site.update!(custom_obfuscated_location: true) }

        it 'leaves numeric uncertainty blank and reports unknown obfuscation uncertainty' do
          expect(row.fetch(:coordinateUncertainty)).to be_nil
          expect(row.fetch(:deploymentTags)).to eq(
            'coordinatesObfuscated:true | ' \
            'dataGeneralizations:coordinates have an assumed measurement uncertainty of 30 meters; ' \
            'coordinates have an unknown obfuscation uncertainty'
          )
        end
      end
    end
  end
end
