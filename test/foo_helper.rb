# frozen_string_literal: true
module FooHelper
  def format_person_info(person)
    "#{person.name} works at #{person.company}"
  end

  def person_employed?(person)
    person.company?
  end
end
