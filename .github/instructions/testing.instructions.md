---
description: "Use when creating or updating RSpec specs"
applyTo: "spec/**"
---

# Testing

See [spec/README.md](../../spec/README.md) for details. Follow the conventional RSpec directory structure.

## Spec placement

- Put tests of which users can invoke which actions in `spec/permissions` as permissions specs, modelled as request specs. The permissions helpers fail unless every user/action combination is covered.
- Put capability tests in `spec/capabilities` as capabilities specs, modelled as request specs.
- Put request/response shape tests in `spec/api` (rswag). They validate bodies against schemas and generate Swagger docs.
- Put specific endpoint functionality not covered by permissions or API specs, such as complex behaviour, in `spec/requests` as request specs.
- Use the helpers in `spec/support` for each spec type.
- Do not add tests to `spec/acceptance`; it is deprecated. Replace its tests when working on that behavior.

## API specs

- API specs run as `admin_user`.
- Use the OpenAPI schemas in `app/modules/api/schema.rb` and the model-specific schemas in model classes.
- On an unpermitted parameter error, check the request `Content-Type` (default `application/json`). For requests without a body, set `consumes nil`.

## Test data

- Define factories in `spec/factories`. Lint with `rake factory_bot:lint`.
- Do not rely on implicit factory associations unless intended; each one creates new records. Pass existing records instead:

	```ruby
	create(:audio_recording, site: an_existing_site, creator: an_existing_user)
	```

- Use the smallest helper in [creation_helper.rb](../../spec/support/creation_helper.rb) that provides the parent records the spec needs:
  - `create_audio_recordings_hierarchy`: users, project, permissions, region, site, audio recording.
  - `create_anon_hierarchy`: a public project with site, audio recording, and dataset item.
- Create any extra records with factories, passing the records the helper already created:

	```ruby
	create_audio_recordings_hierarchy

	let(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }
	```

- Use `create_entire_hierarchy` only when the spec needs most of the hierarchy. It creates every model, which adds many database writes. Needing one record that a smaller helper does not create is not a reason to use it.

## Fixtures

- If tests fail because a fixture is a Git LFS pointer file, run `git lfs pull`.
