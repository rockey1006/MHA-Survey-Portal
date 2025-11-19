# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    role { "student" }
    sequence(:uid) { |n| "uid#{n}" }
    avatar_url { "https://example.com/avatar.png" }

    trait :administrator do
      role { "admin" }
    end

    trait :advisor do
      role { "advisor" }
    end

    trait :student do
      role { "student" }
    end
  end
end
