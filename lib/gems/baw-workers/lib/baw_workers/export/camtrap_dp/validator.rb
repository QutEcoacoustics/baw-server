# frozen_string_literal: true

require_relative 'errors/camtrap_dp_error'

module BawWorkers
  module Export
    module CamtrapDp
      # Data package validation.
      class Validator
        # Validation wrapper around the DataPackage and TableSchema gem validation methods.
        #
        # @param package [Descriptor::Package] in-memory package descriptor to validate.
        # @param package_path [String] path to the package directory containing CSV resources.
        # @return [Boolean] true if the package is valid, raises an error otherwise.
        def self.validate_package(package, package_path:)
          data_package = load_package(package, package_path:)

          validate_descriptors(data_package)
          validate_csv_headers(data_package)
          validate_csv_data(data_package)

          true
        end

        # Create a DataPackage::Package with the `profile` path set to our local validation profile path.
        # See {CamtrapDp::Profile} for more information on the local validation profile.
        #
        # @raise [Errors::PackageLoadError] if the package cannot be loaded.
        # @return [DataPackage::Package]
        def self.load_package(package, package_path:)
          package_descriptor = package.to_h.deep_stringify_keys
          package_descriptor['profile'] = Profile::LOCAL_VALIDATION_PROFILE_PATH

          DataPackage::Package.new(package_descriptor, opts: { base: package_path.to_s })
        rescue DataPackage::Exception => e
          raise Errors::PackageLoadError, "Could not load data package: #{e.detailed_message}"
        end

        # Validate the package descriptor and each resource descriptor against their profiles.
        # @param package [DataPackage::Package]
        # @raise [Errors::DescriptorValidationError]
        def self.validate_descriptors(package)
          package.validate
        rescue DataPackage::ValidationError => e
          raise Errors::DescriptorValidationError, "Package descriptor validation error: #{e.detailed_message}"
        end

        # Validate the CSV headers are equal to the schema field names for all package resources.
        #
        # The TableSchema gem validation assumes CSV columns are ordered according to the schema. If they aren't,
        # it can lead to confusing validation errors. CSV headers past the length of the expected schema fields are
        # ignored, which allows for our additional columns.
        # @param package [DataPackage::Package]
        # @raise [Errors::CsvValidationError] if the CSV headers are invalid.
        def self.validate_csv_headers(package)
          package.resources.each do |resource|
            next if resource.schema.field_names == resource.headers.take(resource.schema.field_names.length)

            raise Errors::CsvValidationError,
              "CSV header validation error in resource '#{resource.name}': " \
              "expected #{resource.schema.field_names}, got #{resource.headers}"
          end
        end

        # Wrapper around the TableSchema gem to validate the CSV data against their schemas. Calling `resource.read`
        # will validate the data row by row and raise an exception if it is invalid.
        # @param package [DataPackage::Package]
        # @raise [Errors::CsvValidationError] if the CSV data is invalid.
        def self.validate_csv_data(package)
          package.resources.each do |resource|
            resource.read
          rescue DataPackage::ResourceException, TableSchema::Exception => e
            raise Errors::CsvValidationError,
              "CSV data validation error in resource '#{resource.name}': #{e.detailed_message}"
          end
        end
      end
    end
  end
end
