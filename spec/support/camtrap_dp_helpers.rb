# frozen_string_literal: true

module CamtrapDpHelpers
  module Example
    # Container for package validation result with a custom to_s for easier debugging in tests.
    ValidationResult = Struct.new(:valid?, :errors, keyword_init: true) do
      def to_s
        valid? ? 'Package is valid' : "Package validation failed:\n#{errors.map { "  - #{_1}" }.join("\n")}"
      end
    end

    # Helper to validate the descriptor and resource schemas and csv data, collecting errors,
    # since DataPackage gem's validation methods only check the schemas
    def validate_package(package)
      errors = []

      descriptor_errors = package.iter_errors { _1 }
      errors.concat(descriptor_errors.map { "Descriptor: #{_1}" })

      if errors.empty?
        package.resources.each do |resource|
          resource.iter { |_| }
        rescue TableSchema::Exception => e
          errors << "Resource '#{resource.name}': #{e.message}"
        end
      end

      ValidationResult.new(valid?: errors.empty?, errors:)
    end

    # If the csv field order doesn't match the schema, validation can fail with cast errors, which takes longer to debug.
    def expect_fieldnames_match_headers(resource)
      expect(resource.schema.field_names).to eq(resource.headers)
    end

    # Read a package's datapackage.json file and replace it's 'profile' field with a path to the local validation profile.
    # The default 'profile' value is a URI that points to the real Camtrap DP extension profile, which isn't accessible during tests.
    # Our local validation profile uses inlined $refs to allow schema validation without network access.
    def use_local_profile(manifest_package_path)
      package_json = JSON.parse(
        File.read(manifest_package_path.join(BawWorkers::Export::CamtrapDp::DATAPACKAGE_FILENAME)), symbolize_names: false
      )
      package_json['profile'] = BawWorkers::Export::CamtrapDp::Profile::LOCAL_VALIDATION_PROFILE_PATH
      package_json
    end
  end
end
