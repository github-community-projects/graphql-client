# frozen_string_literal: true
module FooHelper
  def format_person_info(person)
    "#{person.name} works at #{person.company}"
  end

  def format_person_info_via_send(person)
    "#{person.public_send(:name)} works at #{person.public_send(:company)}"
  end

  def person_employed?(person)
    person.company?
  end
end
