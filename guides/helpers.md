# Helpers

There is nothing special about ERB templates that can declare data dependencies. ERB templates are just Ruby functions and view helpers are just Ruby functions so they may also declare data dependencies.

Helpers accessing many or nested object fields may declare a fragment for those requirements.

``` ruby
module MilestoneHelper
  # Define static query fragment for fetching data for helper.
  MilestoneProgressFragment = FooApp::Client.parse <<-'GRAPHQL'
    fragment on Milestone {
      closedIssueCount
      totalIssueCount
    }
  GRAPHQL

  def milestone_progress(milestone)
    milestone = MilestoneProgressFragment.new(milestone)
    percent = (milestone.closed_issue_count / milestone.total_issue_count) * 100
    content_tag(:span, "#{percent}%", class: "progress", style: "width: #{percent}%")
  end

  # A simpler version may use keyword arguments to define the functions
  # requirements. This avoids any dependency on the shape of data result
  # classes. This maybe a fine alternative if theres only a handful of
  # arguments.
  def milestone_progress(closed:, total:)
    percent = (closed / total) * 100
    content_tag(:span, "#{percent}%", class: "progress", style: "width: #{percent}%")
  end
end
```
