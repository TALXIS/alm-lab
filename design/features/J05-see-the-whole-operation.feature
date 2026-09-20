# Job J5 — See the shape of the whole operation in one view (warehouse manager)
Feature: Seeing the whole operation at a glance
    As a warehouse manager
    I want one view that totals what we hold and what needs attention
    So that I can judge the state of the operation without opening anything

    Scenario: The dashboard totals what the company holds
        Given I am a warehouse manager
        When I open the dashboard
        Then I see how many items we stock
        And I see how many sites we run
        And I see how many items are low on stock

    Scenario: The dashboard shows the stock behind the totals
        Given I am a warehouse manager
        When I open the dashboard
        Then I see the items listed beneath the totals
        And the items that are low on stock stand out
