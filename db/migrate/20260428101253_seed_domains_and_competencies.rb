class SeedDomainsAndCompetencies < ActiveRecord::Migration[8.0]
  DOMAIN_COMPETENCIES = {
    "Health Care Environment and Community" => [
      "Public and Population Health Assessment",
      "Delivery, Organization, and Financing of Health Services and Health Systems",
      "Policy Analysis",
      "Legal & Ethical Bases for Health Services and Health Systems"
    ],
    "Leadership Skills" => [
      "Ethics, Accountability, and Self-Assessment",
      "Organizational Dynamics",
      "Problem Solving, Decision Making, and Critical Thinking",
      "Team Building and Collaboration"
    ],
    "Management Skills" => [
      "Strategic Planning",
      "Business Planning",
      "Communication",
      "Financial Management",
      "Performance Improvement",
      "Project Management"
    ],
    "Analytic and Technical Skills" => [
      "Systems Thinking",
      "Data Analysis and Information Management",
      "Quantitative Methods for Health Services Delivery"
    ]
  }.freeze

  def up
    DOMAIN_COMPETENCIES.each_with_index do |(domain_name, titles), domain_index|
      domain = Domain.find_or_create_by!(name: domain_name)
      domain.update!(position: domain_index + 1)

      titles.each_with_index do |title, competency_index|
        competency = Competency.find_or_initialize_by(title: title)
        competency.domain = domain
        competency.position = competency_index + 1
        competency.save!
      end
    end
  end

  def down
    Competency.where(title: DOMAIN_COMPETENCIES.values.flatten).delete_all
    Domain.where(name: DOMAIN_COMPETENCIES.keys).delete_all
  end
end
