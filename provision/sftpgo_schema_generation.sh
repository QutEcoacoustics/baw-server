#!/usr/bin/env bash

if [[ ! -d "$PWD/provision" ]]
then
    echo "Working directory must be app root!"
    exit 1
fi

# Run this script on docker host!
# Use the following to get a list of available additional properties (used with the -p flag)
# > docker run openapitools/openapi-generator-cli cli-help -g ruby
# CONFIG OPTIONS
#   allowUnicodeIdentifiers
#       boolean, toggles whether unicode identifiers are allowed in names or not, default is false (Default: false)
#   disallowAdditionalPropertiesIfNotPresent
#       Specify the behavior when the 'additionalProperties' keyword is not present in the OAS document. If false: the 'additionalProperties' implementation is compliant with the OAS and JSON schema specifications. If true: when the 'additionalProperties' keyword is not present in a schema, the value of 'additionalProperties' is set to false, i.e. no additional properties are allowed. Note: this mode is not compliant with the JSON schema specification. This is the original openapi-generator behavior.This setting is currently ignored for OAS 2.0 documents:  1) When the 'additionalProperties' keyword is not present in a 2.0 schema, additional properties are NOT allowed.  2) Boolean values of the 'additionalProperties' keyword are ignored. It's as if additional properties are NOT allowed.Note: the root cause are issues #1369 and #1371, which must be resolved in the swagger-parser project. (Default: true)
#           false - The 'additionalProperties' implementation is compliant with the OAS and JSON schema specifications.
#           true - when the 'additionalProperties' keyword is not present in a schema, the value of 'additionalProperties' is automatically set to false, i.e. no additional properties are allowed. Note: this mode is not compliant with the JSON schema specification. This is the original openapi-generator behavior.
#   ensureUniqueParams
#       Whether to ensure parameter names are unique in an operation (rename parameters that are not). (Default: true)
#   gemAuthor
#       gem author (only one is supported).
#   gemAuthorEmail
#       gem author email (only one is supported).
#   gemDescription
#       gem description.  (Default: This gem maps to a REST API)
#   gemHomepage
#       gem homepage.  (Default: http://org.openapitools)
#   gemLicense
#       gem license.  (Default: unlicense)
#   gemName
#       gem name (convention: underscore_case). (Default: openapi_client)
#   gemRequiredRubyVersion
#       gem required Ruby version.  (Default: >= 1.9)
#   gemSummary
#       gem summary.  (Default: A ruby wrapper for the REST APIs)
#   gemVersion
#       gem version. (Default: 1.0.0)
#   hideGenerationTimestamp
#       Hides the generation timestamp when files are generated. (Default: true)
#   legacyDiscriminatorBehavior
#       This flag is used by OpenAPITools codegen to influence the processing of the discriminator attribute in OpenAPI documents. This flag has no impact if the OAS document does not use the discriminator attribute. The default value of this flag is set in each language-specific code generator (e.g. Python, Java, go...)using the method toModelName. Note to developers supporting a language generator in OpenAPITools; to fully support the discriminator attribute as defined in the OAS specification 3.x, language generators should set this flag to true by default; however this requires updating the mustache templates to generate a language-specific discriminator lookup function that iterates over {{#mappedModels}} and does not iterate over {{children}}, {{#anyOf}}, or {{#oneOf}}. (Default: true)
#           true - The mapping in the discriminator includes descendent schemas that allOf inherit from self and the discriminator mapping schemas in the OAS document.
#           false - The mapping in the discriminator includes any descendent schemas that allOf inherit from self, any oneOf schemas, any anyOf schemas, any x-discriminator-values, and the discriminator mapping schemas in the OAS document AND Codegen validates that oneOf and anyOf schemas contain the required discriminator and throws an error if the discriminator is missing.
#   library
#       HTTP library template (sub-template) to use (Default: typhoeus)
#           faraday - Faraday (https://github.com/lostisland/faraday) (Beta support)
#           typhoeus - Typhoeus >= 1.0.1 (https://github.com/typhoeus/typhoeus)
#   moduleName
#       top module name (convention: CamelCase, usually corresponding to gem name). (Default: OpenAPIClient)
#   prependFormOrBodyParameters
#       Add form or body parameters to the beginning of the parameter list. (Default: false)
#   sortModelPropertiesByRequiredFlag
#       Sort model properties to place required parameters before optional parameters. (Default: true)
#   sortParamsByRequiredFlag
#       Sort method arguments to place required parameters before optional parameters. (Default: true)

docker run --rm -v "${PWD}:/local" -u "$(id -u):$(id -u)" \
    -e RUBY_POST_PROCESS_FILE=/local/provision/sftpgo_openapi_postprocess.sh \
    openapitools/openapi-generator-cli generate \
    -i https://raw.githubusercontent.com/drakkan/sftpgo/master/httpd/schema/openapi.yaml \
    -g ruby \
    -o /local/lib/gems/sftpgo_generated_client \
    -p gemName=sftpgo_generated_client \
    --enable-post-process-file
