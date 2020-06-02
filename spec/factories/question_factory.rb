FactoryGirl.define do
  factory :question do
    sequence(:text) { |n| "test question text #{n}" }
    # some realistic data for a question. Annotation ids
    # are not real (not based on factory-generated audio events)
    data_json = <<~JSON
        {"labels": [
          {
            "id": "1",
            "name": "Eastern Bristlebird click",
            "tags": [
                "ebb",
                "type 1"
            ],
            "examples": [
                {
                    "annotationId": 124730,
                    "image":"eb01.jpg"
                },
                {
                    "annotationId": 124727,
                    "image":"eb01.jpg"
                }
            ]
          },
          {
            "id": "2",
            "name": "Eastern Bristlebird whistle",
            "tags": [
                "ebb",
                "type 2"
            ],
            "examples": [
                {
                    "annotationId": 124622
                }
            ]
          },
          {
            "id": "3",
            "name": "Ground Parrot",
            "tags": [
                "ground parrot",
                "type 1"
            ],
            "examples": [
                {
                    "annotationId": 124623,
                    "image":"eb03.jpg"
                }
            ]
          }
        ]}
    JSON
    data data_json
    creator
  end
end
